#!/usr/bin/env python3
"""Bounded, no-symlink wallpaper discovery for Rise's optional folder manager."""
import json
import os
import stat
import sys

EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif",
              ".mp4", ".webm", ".mkv", ".mov", ".avi"}
MAX_DEPTH = 32
MAX_ENTRIES = 10000


def scan(folder, recursive=True):
    folder = os.path.abspath(folder)
    root_info = os.stat(folder, follow_symlinks=False)
    if not stat.S_ISDIR(root_info.st_mode):
        return []
    root_dev = root_info.st_dev
    found = []
    stack = [(folder, 0)]
    visited = 0
    while stack and visited < MAX_ENTRIES:
        directory, depth = stack.pop()
        try:
            entries = list(os.scandir(directory))
        except OSError:
            continue
        entries.sort(key=lambda entry: entry.name.casefold(), reverse=True)
        for entry in entries:
            visited += 1
            if visited > MAX_ENTRIES:
                break
            try:
                info = entry.stat(follow_symlinks=False)
            except OSError:
                continue
            if recursive and stat.S_ISDIR(info.st_mode) and depth < MAX_DEPTH and info.st_dev == root_dev:
                stack.append((entry.path, depth + 1))
            elif stat.S_ISREG(info.st_mode) and os.path.splitext(entry.name)[1].lower() in EXTENSIONS:
                found.append(entry.path)
                if len(found) >= MAX_ENTRIES:
                    return found
    return found


if __name__ == "__main__":
    try:
        print(json.dumps(scan(sys.argv[1], recursive='--flat' not in sys.argv[2:]), ensure_ascii=True))
    except (IndexError, OSError, ValueError):
        print("[]")
