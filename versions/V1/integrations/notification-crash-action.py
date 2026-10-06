#!/usr/bin/env python3
"""Open only an allowlisted crash diagnosis, resolved from systemd's journal.

Notification text is a lookup reference, never an executable command. No sender
argv/callback is read or replayed. Legacy entries lacking a timestamp work only
when exactly one matching, trusted crash exists in the current boot.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
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
    if entry.get('crashReference') is not None and entry['crashReference'] != expected:
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
            executor = lambda argv: subprocess.Popen(argv, start_new_session=True,
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL, env=safe_environment())
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--entry', required=True)
    parser.add_argument('--check', action='store_true', help='Verify only; never open diagnosis')
    args = parser.parse_args()
    try:
        if len(args.entry) > 8192:
            raise ActionUnavailable('Notification request is too large.')
        entry = json.loads(args.entry)
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
