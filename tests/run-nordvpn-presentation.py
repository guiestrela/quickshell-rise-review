#!/usr/bin/env python3
import os
import re
import select
import subprocess
import sys
import time
from pathlib import Path

root = Path('/home/guiestrela/Work/quickshell-rise-review')
out = Path('/home/guiestrela/.hermes/profiles/desktop-dev/cache/scratch/nordvpn-style')
out.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.pop('DISPLAY', None)
env['XDG_RUNTIME_DIR'] = '/run/user/1000'
env['WAYLAND_DISPLAY'] = 'wayland-1'

for variant in ('v1', 'v2'):
    qml = root / f'tests/qml/nordvpn-presentation-{variant}.qml'
    proc = subprocess.Popen(['qs', '--no-duplicate', '--path', str(qml), '--verbose'],
                            cwd=root, env=env, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, bufsize=1)
    ready = None
    deadline = time.monotonic() + 8
    lines = []
    while time.monotonic() < deadline:
        readable, _, _ = select.select([proc.stdout], [], [], 0.2)
        if not readable:
            if proc.poll() is not None:
                break
            continue
        line = proc.stdout.readline()
        if not line:
            if proc.poll() is not None:
                break
            continue
        lines.append(line.rstrip())
        print(f'{variant}: {line.rstrip()}')
        if 'NORDVPN_PRESENTATION_READY' in line:
            ready = re.search(r'width=(\d+) height=(\d+) x=(-?\d+) y=(-?\d+)', line)
            if ready:
                break
    if not ready:
        proc.terminate()
        proc.wait(timeout=3)
        raise SystemExit(f'{variant}: no render geometry; see QML logs above')
    width, height, x, y = map(int, ready.groups())
    image = out / f'nordvpn-panel-{variant}.png'
    capture = subprocess.run(['grim', '-g', f'{x},{y} {width}x{height}', str(image)],
                             env=env, text=True, capture_output=True, timeout=5)
    print(f'{variant}: grim rc={capture.returncode} path={image} geometry={width}x{height}+{x}+{y}')
    if capture.returncode:
        proc.terminate(); proc.wait(timeout=3)
        raise SystemExit(capture.stderr)
    key = subprocess.run(['wtype', '-k', 'Escape'], env=env, text=True,
                         capture_output=True, timeout=5)
    print(f'{variant}: Escape input rc={key.returncode}')
    try:
        remaining, _ = proc.communicate(timeout=4)
    except subprocess.TimeoutExpired:
        proc.terminate()
        remaining, _ = proc.communicate(timeout=3)
        raise SystemExit(f'{variant}: did not close after Escape\n{remaining}')
    if remaining:
        print(remaining, end='')
    if proc.returncode != 0 or 'NORDVPN_PRESENTATION_ESCAPE_PASS' not in remaining:
        raise SystemExit(f'{variant}: Escape/dismiss verification failed, rc={proc.returncode}')
print('NORDVPN V1/V2 Wayland render, screenshot and Escape verification PASS')
