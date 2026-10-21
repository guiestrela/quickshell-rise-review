#!/usr/bin/env python3
"""Compile the actual V2 NetworkPanel QML without instantiating it."""
import json
import os
from pathlib import Path
import subprocess
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

with tempfile.TemporaryDirectory(prefix='qsr-v2-compile-', dir=os.environ['TMPDIR']) as temp:
    probe = Path(temp) / 'shell.qml'
    probe.write_text(qml)
    env = os.environ.copy()
    env.pop('DISPLAY', None)
    env['QT_QPA_PLATFORM'] = 'wayland'
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
