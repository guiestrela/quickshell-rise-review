#!/usr/bin/env python3
"""Read notification state from Omarchy, with Mako compatibility fallback."""

import json
import os
import math
import re
import time
from pathlib import Path
import subprocess
import sys


def read_entries(folder: Path, active: bool):
    entries = []
    try:
        paths = sorted(folder.glob("*.json"), key=lambda item: item.name, reverse=True)
        for path in paths:
            try:
                row = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            if not isinstance(row, dict):
                continue
            argv = row.get('execArgv')
            if isinstance(argv, str):
                try:
                    argv = json.loads(argv)
                except (ValueError, TypeError):
                    argv = None
            crash = (isinstance(argv, list) and len(argv) == 5
                     and argv[0] in ('omarchy-agent-crash', '/usr/bin/omarchy-agent-crash')
                     and all(isinstance(arg, str) for arg in argv))
            entries.append({
                "id": row.get("originalId") or row.get("id") or 0,
                "app_name": row.get("app") or "",
                "summary": row.get("summary") or "",
                "body": row.get("body") or "",
                "active": active,
                "timestamp": row.get("timestamp") or 0,
                "backend": "omarchy",
                "actionKind": "omarchy-crash" if crash else "unsupported",
                "crashReference": ({"pid": argv[1], "comm": argv[2], "exe": argv[3], "signal": argv[4]} if crash else None),
            })
    except OSError:
        pass
    return entries


def process_token(name: str) -> str:
    try:
        pid = subprocess.run(["pidof", name], capture_output=True, text=True, timeout=1, check=True).stdout.split()[0]
        # comm is parenthesized and may itself contain spaces or ')'.
        # Fields after its final ')' start at field 3 (state).
        fields = Path(f"/proc/{pid}/stat").read_text(encoding="utf-8").rsplit(')', 1)[1].split()
        boot_id = Path("/proc/sys/kernel/random/boot_id").read_text(encoding="ascii").strip()
        return f"{boot_id}-{pid}-{fields[19]}"
    except (OSError, ValueError, IndexError, subprocess.SubprocessError):
        return ""


def read_store(path: Path, active: bool):
    try:
        with path.open('rb') as stream:
            raw = stream.read(2_097_153)
        if len(raw) > 2_097_152:
            return None
        rows = json.loads(raw)
    except FileNotFoundError:
        return []
    except (OSError, ValueError):
        return None
    if not isinstance(rows, list):
        return None
    entries = []
    now = time.time()
    seen = set()
    for row in rows:
        if len(entries) >= 100:
            break
        if not isinstance(row, dict):
            continue
        key = row.get('key')
        ts = row.get('ts')
        if (not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,120}', key)
                or key in seen or isinstance(ts, bool) or not isinstance(ts, (int, float))
                or not math.isfinite(ts) or ts <= 0 or ts > 1e12):
            continue
        if not active:
            closed = row.get('closed_ts')
            if (isinstance(closed, bool) or not isinstance(closed, (int, float))
                    or not math.isfinite(closed) or closed <= now - 86400):
                continue
        seen.add(key)
        argv = row.get('execArgv')
        if isinstance(argv, str):
            try:
                argv = json.loads(argv)
            except ValueError:
                argv = None
        crash = (isinstance(argv, list) and len(argv) == 5
                 and argv[0] in ('omarchy-agent-crash', '/usr/bin/omarchy-agent-crash')
                 and all(isinstance(arg, str) for arg in argv))
        def text(field, limit):
            value = row.get(field)
            return value[:limit] if isinstance(value, str) else ''
        identity = row.get('originalId', 0)
        entries.append({
            'id': identity if type(identity) is int and 0 < identity < 2147483648 else 0,
            'sourceKey': key, 'app_name': text('app', 512),
            'summary': text('summary', 4096), 'body': text('body', 16384),
            'active': active, 'timestamp': round(ts * 1000), 'backend': 'omarchy',
            'actionKind': 'omarchy-crash' if crash else 'unsupported',
            'crashReference': ({'pid': argv[1], 'comm': argv[2], 'exe': argv[3], 'signal': argv[4]} if crash else None),
        })
    return entries


def omarchy_snapshot(state: Path):
    notifications = state / "notifications"
    live = notifications / 'live.json'
    stored_history = notifications / 'history.json'
    if live.exists() or stored_history.exists() or (notifications / 'quiet.json').exists():
        active = read_store(live, True)
        history = read_store(stored_history, False)
        return {
            'token': 'omarchy-store-v1', 'store': True,
            'valid': active is not None and history is not None,
            'list': active or [], 'history': history or [],
        }
    history = notifications / "history"
    if not history.is_dir():
        return None
    return {
        "token": process_token("omarchy-shell"),
        "list": read_entries(notifications, True),
        "history": read_entries(history, False),
    }


def mako_snapshot():
    def query(*args):
        try:
            result = subprocess.run(["makoctl", *args, "-j"], capture_output=True, text=True, timeout=2)
            if result.returncode == 0 and result.stdout.strip():
                parsed = json.loads(result.stdout)
                return parsed if isinstance(parsed, list) else []
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
        return []

    def normalize(rows, active):
        return [{
            "id": row.get("id") or 0,
            "app_name": row.get("app_name") or "",
            "summary": row.get("summary") or "",
            "body": row.get("body") or "",
            "active": active,
            "backend": "mako",
            "timestamp": 0,
        } for row in rows if isinstance(row, dict)]

    return {
        "token": process_token("mako"),
        "list": normalize(query("list"), True),
        "history": normalize(query("history"), False),
    }


def main():
    home = Path(os.environ.get("HOME", str(Path.home())))
    state_home = Path(os.environ.get("XDG_STATE_HOME", str(home / ".local/state")))
    snapshot = omarchy_snapshot(state_home / "omarchy") or mako_snapshot()
    json.dump(snapshot, sys.stdout, separators=(",", ":"))


if __name__ == "__main__":
    main()
