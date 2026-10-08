#!/usr/bin/env python3
"""Allowlisted notification actions: verified crashes, screenshot editing,
and explicitly selected existing Chromium windows.

Notification text is a lookup reference, never a runnable command or URL.
Native browser callbacks are handled in QML, not replayed from persisted data.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import time

MESSAGE_ID = 'fc2e22bc6ee647b6b90729ab34a250b1'
LAUNCHER = '/usr/bin/omarchy-agent-crash'
JOURNAL = '/usr/bin/journalctl'
COREDUMP = '/usr/lib/systemd/systemd-coredump'
FIELDS = ('MESSAGE_ID', '_EXE', '_SYSTEMD_UNIT', '_BOOT_ID', 'COREDUMP_UID',
          'COREDUMP_PID', 'COREDUMP_COMM', 'COREDUMP_EXE', 'COREDUMP_SIGNAL_NAME',
          '__REALTIME_TIMESTAMP', '__CURSOR')


class ActionUnavailable(ValueError):
    pass


def plain(value, maximum=4096):
    return (isinstance(value, str) and 0 < len(value) <= maximum
            and not any(ord(c) < 32 or ord(c) == 127 for c in value))


def trusted_record(row, uid, boot):
    if not isinstance(row, dict):
        return False
    return (row.get('MESSAGE_ID') == MESSAGE_ID
            and row.get('_EXE') == COREDUMP
            and isinstance(row.get('_SYSTEMD_UNIT'), str)
            and row['_SYSTEMD_UNIT'].startswith('systemd-coredump@')
            and row.get('_BOOT_ID') == boot
            and row.get('COREDUMP_UID') == str(uid)
            and isinstance(row.get('COREDUMP_PID'), str)
            and re.fullmatch(r'[1-9][0-9]{0,9}', row['COREDUMP_PID']) is not None
            and int(row['COREDUMP_PID']) < 2147483648
            and plain(row.get('COREDUMP_COMM'), 256)
            and plain(row.get('COREDUMP_EXE'))
            and row['COREDUMP_EXE'].startswith('/')
            and isinstance(row.get('COREDUMP_SIGNAL_NAME'), str)
            and re.fullmatch(r'SIG[A-Z0-9]+', row['COREDUMP_SIGNAL_NAME']) is not None
            and isinstance(row.get('__REALTIME_TIMESTAMP'), str)
            and row['__REALTIME_TIMESTAMP'].isdigit()
            and plain(row.get('__CURSOR'), 2048))


def plan_action(entry, rows, uid, boot):
    if not isinstance(entry, dict) or entry.get('backend', 'omarchy') != 'omarchy':
        raise ActionUnavailable('This notification has no supported crash action.')
    if entry.get('actionKind') not in (None, 'omarchy-crash') or 'execArgv' in entry:
        raise ActionUnavailable('Unknown notification callback is not allowed.')
    summary = entry.get('summary', '')
    prefix = 'Process crashed: '
    if (entry.get('appName') != 'omarchy-action' or not plain(summary, 512)
            or not summary.startswith(prefix)
            or entry.get('body') != 'Click to diagnose with AI'):
        raise ActionUnavailable('Only verified crash diagnosis is allowed.')
    name = summary[len(prefix):]
    timestamp = entry.get('timestamp', 0)
    if (isinstance(timestamp, bool) or not isinstance(timestamp, (int, float))
            or timestamp < 0 or timestamp > 1e15 or timestamp != timestamp):
        raise ActionUnavailable('Invalid notification identity.')
    records = [r for r in rows if trusted_record(r, uid, boot)]
    matches = []
    for row in records:
        if name != Path(row['COREDUMP_EXE']).name:
            continue
        event_ms = int(row['__REALTIME_TIMESTAMP']) / 1000
        if timestamp and not 0 <= timestamp - event_ms <= 120000:
            continue
        matches.append(row)
    # Duplicate journal rows with the same cursor do not add ambiguity.
    unique = {r['__CURSOR']: r for r in matches}
    if len(unique) != 1:
        raise ActionUnavailable('No unique verified crash found. This item cannot be opened safely.')
    row = next(iter(unique.values()))
    expected = {'pid': row['COREDUMP_PID'], 'comm': row['COREDUMP_COMM'],
                'exe': row['COREDUMP_EXE'], 'signal': row['COREDUMP_SIGNAL_NAME']}
    reference = entry.get('crashReference')
    # Omarchy may report the executable basename; Linux COMM is limited to
    # 15 bytes. Accept only that exact, journal-derived truncation alias.
    basename = Path(row['COREDUMP_EXE']).name
    full_name = dict(expected, comm=basename)
    truncated_name = basename.encode('utf-8')[:15].decode('utf-8', errors='ignore')
    if reference is not None and reference != expected:
        if row['COREDUMP_COMM'] != truncated_name or reference != full_name:
            raise ActionUnavailable('Notification crash data does not match the journal.')
    # The vendor launcher accepts only PID. Reject PID reuse even when a
    # notification timestamp disambiguates records within this boot.
    if len({r['__CURSOR'] for r in records
            if r['COREDUMP_PID'] == row['COREDUMP_PID']}) != 1:
        raise ActionUnavailable('Crash PID was reused; diagnosis is unavailable.')
    return {'argv': [LAUNCHER, row['COREDUMP_PID'], row['COREDUMP_COMM'],
                     row['COREDUMP_EXE'], row['COREDUMP_SIGNAL_NAME']],
            'cursor': row['__CURSOR'], 'legacy': not bool(timestamp)}


def read_journal(uid):
    result = subprocess.run([JOURNAL, '--no-pager', '-b', '-o', 'json',
                             '--output-fields=' + ','.join(FIELDS),
                             'MESSAGE_ID=' + MESSAGE_ID, 'COREDUMP_UID=' + str(uid),
                             '-n', '513'], capture_output=True, text=True, timeout=8)
    if result.returncode != 0 or len(result.stdout) > 2097152:
        raise ActionUnavailable('Cannot verify the system crash journal.')
    lines = result.stdout.splitlines()
    # One sentinel beyond the bound proves whether a complete boot history
    # fits. Never infer uniqueness or PID non-reuse from a truncated window.
    if len(lines) > 512:
        raise ActionUnavailable('Crash history exceeds safe verification limit; action unavailable.')
    rows = []
    for line in lines:
        try:
            rows.append(json.loads(line))
        except (ValueError, TypeError):
            continue
    return rows


def verify_launcher():
    path = Path(LAUNCHER).resolve(strict=True)
    info = path.stat()
    if (info.st_uid != 0 or info.st_mode & 0o022
            or not stat.S_ISREG(info.st_mode) or not os.access(path, os.X_OK)):
        raise ActionUnavailable('The crash diagnosis launcher is not trusted.')


def safe_environment():
    env = {k: v for k, v in os.environ.items()
           if k not in ('BASH_ENV', 'ENV', 'LD_PRELOAD', 'LD_LIBRARY_PATH')
           and not k.startswith('BASH_FUNC_')}
    env['PATH'] = '/usr/share/omarchy/bin:/usr/bin'
    env['OMARCHY_PATH'] = '/usr/share/omarchy'
    return env


def crash_environment():
    env = safe_environment()
    selected = subprocess.run(['/usr/bin/omarchy-default-agent'], capture_output=True,
        text=True, timeout=3, env=env)
    agent = selected.stdout.strip()
    if selected.returncode != 0 or not agent or not plain(agent, 64):
        raise ActionUnavailable('Choose an installed default coding agent first.')
    if shutil.which(agent, path=env['PATH']):
        return env
    if agent != 'opencode':
        raise ActionUnavailable('The default agent is unavailable in the restricted launcher environment.')
    # Resolve an already installed binary, never execute an auto-install shim.
    home = Path.home()
    result = subprocess.run(['/usr/bin/mise', 'which', 'opencode'], capture_output=True,
        text=True, timeout=3, env=env, cwd=home / 'Work' if (home / 'Work').is_dir() else home)
    raw = result.stdout.strip()
    if result.returncode != 0 or not plain(raw) or ':' in raw:
        raise ActionUnavailable('OpenCode is not installed or cannot be resolved safely.')
    binary = Path(raw).resolve(strict=True)
    root = home / '.local/share/mise/installs/opencode'
    if not binary.is_relative_to(root) or binary.name != 'opencode':
        raise ActionUnavailable('OpenCode resolved outside its installed package.')
    for path in (binary, *binary.parents):
        info = path.stat()
        if info.st_uid not in (0, os.getuid()) or info.st_mode & 0o022:
            raise ActionUnavailable('OpenCode installation is writable by other users.')
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise ActionUnavailable('OpenCode executable is unavailable.')
    env['PATH'] += ':' + str(binary.parent)
    return env


def launch_action(plan, state_dir, executor=None):
    """Serialize duplicate clicks; caller supplies only a journal-derived plan."""
    state_dir = Path(state_dir)
    state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    lockpath = state_dir / 'crash-action.lock'
    fd = os.open(lockpath, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'r+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        raw = lock.read(524288)
        try:
            last = json.loads(raw) if raw else {}
        except ValueError:
            raise ActionUnavailable('Crash action replay state is invalid.')
        if not isinstance(last, dict):
            raise ActionUnavailable('Crash action replay state is invalid.')
        key = hashlib.sha256(plan['cursor'].encode()).hexdigest()
        consumed = last.get('consumed', [])
        if not isinstance(consumed, list):
            consumed = []
        if key in consumed:
            raise ActionUnavailable('This crash diagnosis was already opened.')
        if executor is None:
            verify_launcher()
            env = crash_environment()
            executor = lambda argv: subprocess.Popen(argv, start_new_session=True,
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL, env=env)
        def save(keys):
            lock.seek(0)
            lock.truncate()
            json.dump({'consumed': keys}, lock)
            lock.flush()
            os.fsync(lock.fileno())
        # Persist the claim before spawning. A helper crash after spawn must
        # not make the same event replayable in another process.
        save((consumed + [key])[-4096:])
        try:
            executor(plan['argv'])
        except OSError:
            save(consumed)
            raise


SCREENSHOT_TITLE = 'Screenshot saved to clipboard and file'
SCREENSHOT_BODY = 'Edit with Super + Alt + , (or click this)'
SCREENSHOT_EDITOR = '/usr/bin/tensaku-edit'


def read_owned_json(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'r') as source:
        info = os.fstat(source.fileno())
        if (info.st_uid != os.getuid() or info.st_mode & 0o022
                or not stat.S_ISREG(info.st_mode) or info.st_size > 65536):
            raise ActionUnavailable('Notification record is not safe to read.')
        return json.load(source)


def plan_screenshot_action(entry, state_dir, pictures):
    # The notification/cache never supplies a runnable program. Re-read the
    # selected native record, then permit exactly the packaged screenshot editor.
    if (not isinstance(entry, dict) or entry.get('backend') != 'omarchy'
            or 'execArgv' in entry or entry.get('appName') != 'omarchy-action'
            or entry.get('summary') != SCREENSHOT_TITLE or entry.get('body') != SCREENSHOT_BODY
            or entry.get('actionKind') not in (None, 'unsupported', 'screenshot-edit')):
        raise ActionUnavailable('This notification has no supported screenshot action.')
    identity = entry.get('id')
    timestamp = entry.get('timestamp')
    if (type(identity) is not int or not 0 < identity < 2147483648
            or not isinstance(timestamp, (int, float)) or isinstance(timestamp, bool)):
        raise ActionUnavailable('Screenshot notification identity is missing.')
    if not 0 < timestamp < 1e15 or timestamp != int(timestamp):
        raise ActionUnavailable('Screenshot notification identity is missing.')
    filename = str(int(timestamp)) + '-' + str(identity) + '.json'
    records = []
    for directory in (Path(state_dir), Path(state_dir) / 'history'):
        path = directory / filename
        if path.exists() or path.is_symlink():
            records.append(read_owned_json(path))
    if len(records) != 1:
        raise ActionUnavailable('The selected screenshot notification is unavailable or ambiguous.')
    row = records[0]
    if (not isinstance(row, dict) or (row.get('originalId') or row.get('id')) != identity
            or row.get('timestamp') != timestamp or row.get('app') != entry['appName']
            or row.get('summary') != entry['summary'] or row.get('body') != entry['body']):
        raise ActionUnavailable('Screenshot notification identity does not match.')
    raw = row.get('execArgv')
    argv = json.loads(raw) if isinstance(raw, str) else raw
    if (not isinstance(argv, list) or len(argv) != 2
            or argv[0] not in ('tensaku-edit', SCREENSHOT_EDITOR) or not plain(argv[1])):
        raise ActionUnavailable('Unknown screenshot callback is not allowed.')
    picture_dir = Path(pictures).resolve(strict=True)
    image = Path(argv[1])
    if (not image.is_absolute() or image.parent != picture_dir
            or re.fullmatch(r'screenshot-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\.png', image.name) is None):
        raise ActionUnavailable('Screenshot path is outside the allowed capture directory.')
    fd = os.open(image, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as source:
        info = os.fstat(source.fileno())
        if (info.st_uid != os.getuid() or info.st_mode & 0o022
                or not stat.S_ISREG(info.st_mode) or not 8 <= info.st_size <= 67108864
                or source.read(8) != b'\x89PNG\r\n\x1a\n'):
            raise ActionUnavailable('The selected capture is not a safe PNG file.')
    return {'argv': [SCREENSHOT_EDITOR, str(image)]}


def launch_screenshot_action(plan):
    for program in (SCREENSHOT_EDITOR, '/usr/bin/tensaku'):
        info = Path(program).resolve(strict=True).stat()
        if (info.st_uid != 0 or info.st_mode & 0o022
                or not stat.S_ISREG(info.st_mode) or not os.access(program, os.X_OK)):
            raise ActionUnavailable('The screenshot editor is not trusted.')
    process = subprocess.Popen(plan['argv'], start_new_session=True,
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL, env=safe_environment())
    try:
        code = process.wait(timeout=0.5)
    except subprocess.TimeoutExpired:
        return  # Started; visual/window verification remains a separate gate.
    if code != 0:
        raise ActionUnavailable('The screenshot editor failed to start.')


def browser_windows(entry, state_dir, clients):
    if (not isinstance(entry, dict) or entry.get('backend') != 'omarchy'
            or entry.get('appName') != 'Chromium' or 'execArgv' in entry
            or type(entry.get('id')) is not int or not 0 < entry['id'] < 2147483648
            or not isinstance(entry.get('timestamp'), (int, float))
            or isinstance(entry['timestamp'], bool) or not 0 < entry['timestamp'] < 1e15
            or entry['timestamp'] != int(entry['timestamp'])):
        raise ActionUnavailable('This notification has no supported browser fallback.')
    filename = str(int(entry['timestamp'])) + '-' + str(entry['id']) + '.json'
    rows = []
    for directory in (Path(state_dir), Path(state_dir) / 'history'):
        path = directory / filename
        if path.exists() or path.is_symlink():
            rows.append(read_owned_json(path))
    if len(rows) != 1:
        raise ActionUnavailable('The selected browser notification is unavailable or ambiguous.')
    row = rows[0]
    if (not isinstance(row, dict) or (row.get('originalId') or row.get('id')) != entry['id']
            or row.get('timestamp') != entry['timestamp'] or row.get('app') != 'Chromium'
            or row.get('summary') != entry.get('summary') or row.get('body') != entry.get('body')
            or row.get('execArgv')):
        raise ActionUnavailable('Browser notification identity or callback does not match.')
    if not isinstance(clients, list) or len(clients) > 512:
        raise ActionUnavailable('Cannot read browser windows safely.')
    choices = []
    for client in clients:
        if not isinstance(client, dict) or client.get('class') != 'chromium' or client.get('mapped') is not True:
            continue
        address, pid = client.get('address'), client.get('pid')
        if (not isinstance(address, str) or re.fullmatch(r'0x[0-9a-fA-F]{1,16}', address) is None
                or type(pid) is not int or not 0 < pid < 2147483648):
            continue
        choices.append({'address': address, 'pid': pid,
                        'title': str(client.get('title') or 'Chromium')[:240]})
    if not choices:
        raise ActionUnavailable('There is no open Chromium window. This historical alert cannot restore its original tab.')
    if len({c['address'] for c in choices}) != len(choices) or len(choices) > 32:
        raise ActionUnavailable('Browser window list is ambiguous or too large.')
    return choices


def browser_focus_target(entry, state_dir, clients, selection):
    if (not isinstance(selection, dict) or set(selection) != {'address', 'pid'}
            or type(selection.get('pid')) is not int):
        raise ActionUnavailable('Choose a browser window first.')
    matches = [c for c in browser_windows(entry, state_dir, clients)
               if c['address'] == selection.get('address') and c['pid'] == selection['pid']]
    if len(matches) != 1:
        raise ActionUnavailable('The selected browser window changed or closed. Choose again.')
    return matches[0]


def hypr_query(command):
    response = subprocess.run(['/usr/bin/hyprctl', '-j', command], capture_output=True,
                              text=True, timeout=3, env=safe_environment())
    if response.returncode != 0 or len(response.stdout) > 1048576:
        raise ActionUnavailable('Cannot query this graphical session.')
    return json.loads(response.stdout)


def focus_browser_window(entry, state_dir, selection):
    target = browser_focus_target(entry, state_dir, hypr_query('clients'), selection)
    response = subprocess.run(['/usr/bin/hyprctl', 'dispatch', 'focuswindow', 'address:' + target['address']],
                              capture_output=True, text=True, timeout=3, env=safe_environment())
    if response.returncode != 0:
        raise ActionUnavailable('Cannot focus the selected browser window.')
    # The compositor is authoritative, not the dispatch return code.
    deadline = time.monotonic() + 1
    while True:
        active = hypr_query('activewindow')
        if (active.get('address') == target['address'] and active.get('pid') == target['pid']
                and active.get('class') == 'chromium'):
            return
        if time.monotonic() >= deadline:
            raise ActionUnavailable('The selected browser window did not receive focus.')
        time.sleep(0.05)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--entry', required=True)
    parser.add_argument('--check', action='store_true', help='Verify only; never execute an action')
    parser.add_argument('--window', help='Explicit browser window selection as address/PID JSON')
    args = parser.parse_args()
    try:
        if len(args.entry) > 8192:
            raise ActionUnavailable('Notification request is too large.')
        entry = json.loads(args.entry)
        if isinstance(entry, dict) and entry.get('appName') == 'Chromium':
            state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'omarchy/notifications'
            if args.window:
                if len(args.window) > 256:
                    raise ActionUnavailable('Browser selection is too large.')
                selection = json.loads(args.window)
                browser_focus_target(entry, state, hypr_query('clients'), selection)
                if not args.check:
                    focus_browser_window(entry, state, selection)
                print(json.dumps({'ok': True, 'checkedOnly': args.check, 'action': 'browser-focus'}))
            else:
                windows = browser_windows(entry, state, hypr_query('clients'))
                print(json.dumps({'ok': True, 'checkedOnly': args.check, 'chooseWindow': True, 'windows': windows}))
            return 0
        if args.window:
            raise ActionUnavailable('Window selection is supported only for Chromium.')
        if isinstance(entry, dict) and entry.get('summary') == SCREENSHOT_TITLE:
            home = Path.home()
            state = Path(os.environ.get('XDG_STATE_HOME', str(home / '.local/state')))
            plan = plan_screenshot_action(entry, state / 'omarchy/notifications', home / 'Pictures')
            if not args.check:
                launch_screenshot_action(plan)
            print(json.dumps({'ok': True, 'checkedOnly': args.check, 'action': 'screenshot-edit'}))
            return 0
        uid = os.getuid()
        boot = Path('/proc/sys/kernel/random/boot_id').read_text().strip().replace('-', '')
        plan = plan_action(entry, read_journal(uid), uid, boot)
        if not args.check:
            state = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache')))
            launch_action(plan, state / 'quickshell-rise')
        print(json.dumps({'ok': True, 'checkedOnly': args.check, 'legacyResolved': plan['legacy']}))
        return 0
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(json.dumps({'ok': False, 'message': str(error)}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
