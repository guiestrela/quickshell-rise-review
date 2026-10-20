#!/usr/bin/env python3
"""Compile the actual V2 NetworkPanel QML without instantiating it."""
import json
import os
from pathlib import Path
import subprocess
import socket
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
TARGET = PROJECT / 'versions/V1/variants/V2/panels/NetworkPanel.qml'
qml = '''import QtQuick
import Quickshell
Scope {
    property var candidate: null
    function finish() {
        if (candidate.status === Component.Loading) return
        if (candidate.status === Component.Ready)
            console.log("QSR_NETWORK_PANEL_READY")
        else
            console.warn("QSR_NETWORK_PANEL_ERROR", candidate.errorString())
        Qt.quit()
    }
    Component.onCompleted: {
        candidate = Qt.createComponent(%s)
        candidate.statusChanged.connect(finish)
        finish()
    }
}
''' % json.dumps(TARGET.as_uri())

# PanelWindow requires Wayland; offscreen cannot compile this type. Check the
# socket first so a missing/restricted session cannot abort Qt and dump core.
wayland = Path(os.environ.get('WAYLAND_DISPLAY', 'wayland-0'))
if not wayland.is_absolute():
    wayland = Path(os.environ.get('XDG_RUNTIME_DIR', '/nonexistent')) / wayland
try:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.connect(str(wayland))
except OSError as error:
    print(f'SKIP: V2 NetworkPanel requires an accessible Wayland session: {error}')
    raise SystemExit(0)

with tempfile.TemporaryDirectory(prefix='qsr-v2-compile-', dir=os.environ.get("TMPDIR")) as temp:
    probe = Path(temp) / 'shell.qml'
    probe.write_text(qml)
    env = os.environ.copy()
    env.pop('DISPLAY', None)
    env['QT_QPA_PLATFORM'] = 'wayland'
    env['WAYLAND_DISPLAY'] = str(wayland)
    env['QT_QUICK_BACKEND'] = 'software'
    env['QT_QPA_PLATFORMTHEME'] = ''
    env['XDG_RUNTIME_DIR'] = temp
    try:
        result = subprocess.run(['qs', '-n', '-p', str(probe)], env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                timeout=5)
        output = result.stdout
    except subprocess.TimeoutExpired as exc:
        # Quickshell may retain its no-window Scope after Qt.quit(); subprocess.run
        # terminates only this probe. Its compile sentinel is the assertion.
        output = (exc.stdout or b'').decode(errors='replace')
    if 'QSR_NETWORK_PANEL_READY' not in output:
        print('FAIL: V2 NetworkPanel did not compile')
        for line in output.splitlines():
            if 'QSR_NETWORK_PANEL' in line or 'id is not unique' in line or 'unavailable' in line:
                print(line)
        raise SystemExit(1)
    print('PASS: V2 NetworkPanel compiles in Quickshell (not instantiated)')
