#!/usr/bin/env python3
"""Read notification state from Omarchy, with Mako compatibility fallback."""

import json
import os
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
            entries.append({
                "id": row.get("originalId") or row.get("id") or 0,
                "app_name": row.get("app") or "",
                "summary": row.get("summary") or "",
                "body": row.get("body") or "",
                "active": active,
                "timestamp": row.get("timestamp") or 0,
            })
    except OSError:
        pass
    return entries


def process_token(name: str) -> str:
    try:
        pid = subprocess.run(["pidof", name], capture_output=True, text=True, timeout=1, check=True).stdout.split()[0]
        fields = Path(f"/proc/{pid}/stat").read_text(encoding="utf-8").split()
        boot_id = Path("/proc/sys/kernel/random/boot_id").read_text(encoding="ascii").strip()
        return f"{boot_id}-{pid}-{fields[21]}"
    except (OSError, ValueError, IndexError, subprocess.SubprocessError):
        return ""


def omarchy_snapshot(state: Path):
    notifications = state / "notifications"
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
        } for row in rows]

    return {
        "token": process_token("mako"),
        "list": normalize(query("list"), True),
        "history": normalize(query("history"), False),
    }


home = Path(os.environ.get("HOME", str(Path.home())))
state_home = Path(os.environ.get("XDG_STATE_HOME", str(home / ".local/state")))
snapshot = omarchy_snapshot(state_home / "omarchy") or mako_snapshot()
json.dump(snapshot, sys.stdout, separators=(",", ":"))
