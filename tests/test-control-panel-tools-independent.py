#!/usr/bin/env python3
"""Complementary real-event ControlPanelTools checks for both variant names.

This tests the production shared component, not complete native adapters.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RUNNER = shutil.which('qmltestrunner') or '/usr/lib/qt6/bin/qmltestrunner'
assert Path(RUNNER).is_file(), 'QtTest runner required'
fixture = ROOT / 'tests/qml/tst_IndependentControlTools.qml'
with tempfile.TemporaryDirectory(prefix='rise-tools-independent-', dir=os.environ.get('TMPDIR')) as folder:
    runtime = Path(folder) / 'runtime'
    runtime.mkdir(mode=0o700)
    env = os.environ.copy()
    for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'DBUS_SESSION_BUS_ADDRESS'):
        env.pop(key, None)
    env.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               QT_QPA_PLATFORMTHEME='', XDG_RUNTIME_DIR=str(runtime))
    result = subprocess.run([RUNNER, '-input', str(fixture)], cwd=ROOT,
                            env=env, capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode:
        raise SystemExit(result.returncode)
    if any(text in output for text in ('ReferenceError', 'TypeError', 'Binding loop', 'Cannot assign', 'Unable to assign')):
        raise SystemExit('Unexpected QML runtime diagnostics')
