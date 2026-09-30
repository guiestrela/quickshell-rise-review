#!/usr/bin/env python3
"""Instantiate the real (hidden) Hearthstone panel and catch invalid anchors.

The stub keeps imagePickerVisible=false, so no picker scan, file selection or
wallpaper/theme action is initiated. The Quickshell process is time-bounded.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
CANDIDATES = (
    PROJECT / 'versions/V1/panels/ImageCarouselHearthstone.qml',
    PROJECT / 'versions/V1/variants/V2/panels/ImageCarouselHearthstone.qml',
)
QML = '''import QtQuick
import Quickshell
Scope {
    QtObject {
        id: stub
        property var activePopupScreen: null
        property bool imagePickerVisible: false
        property string pickerStyle: "hearthstone"
        property string imagePickerMode: "wallpaper"
        property string ink: "white"
        property string mono: "monospace"
        property int tileRadius: 6
        property string fillHover: "#222222"
        property string fillIdle: "#111111"
        property string seal: "#777777"
        property string sep: "#333333"
        property string wallpaperManagerFolder: ""
    }
    property var candidate: null
    Component.onCompleted: {
        var component = Qt.createComponent(%s)
        if (component.status !== Component.Ready) {
            console.warn("QSR_HEARTHSTONE_COMPILE_ERROR", component.errorString())
            Qt.quit()
            return
        }
        candidate = component.createObject(null, {"root": stub})
        if (candidate === null)
            console.warn("QSR_HEARTHSTONE_INSTANTIATION_ERROR", component.errorString())
        else
            console.log("QSR_HEARTHSTONE_INSTANCE_CREATED", candidate.visible)
        Qt.callLater(Qt.quit)
    }
}
'''

failures = []
for target in CANDIDATES:
    with tempfile.TemporaryDirectory(prefix='qsr-hs-anchor-', dir=os.environ['TMPDIR']) as temp:
        probe = Path(temp) / 'shell.qml'
        probe.write_text(QML % json.dumps(target.as_uri()))
        env = os.environ.copy()
        env.pop('DISPLAY', None)
        env['QT_QPA_PLATFORM'] = 'wayland'
        env['NO_COLOR'] = '1'
        try:
            result = subprocess.run(['qs', '-n', '-p', str(probe)], env=env, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    timeout=6)
            output = result.stdout
        except subprocess.TimeoutExpired as exc:
            output = (exc.stdout or b'').decode(errors='replace')
        lines = [line for line in output.splitlines() if
                 'QSR_HEARTHSTONE' in line or 'stage is not defined' in line]
        valid = ('QSR_HEARTHSTONE_INSTANCE_CREATED' in output
                 and 'stage is not defined' not in output
                 and 'QSR_HEARTHSTONE_COMPILE_ERROR' not in output
                 and 'QSR_HEARTHSTONE_INSTANTIATION_ERROR' not in output)
        print(('PASS' if valid else 'FAIL') + ': ' + str(target.relative_to(PROJECT)))
        for line in lines:
            print('  ' + line[:500])
        if not valid:
            failures.append(str(target.relative_to(PROJECT)))
if failures:
    raise SystemExit(1)
