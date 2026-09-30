#!/usr/bin/env python3
"""Run real Rise wallpaper-widget QML with inert action doubles, V1/V2."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import Quickshell
Scope {
    QtObject {
        id: stub
        property bool modWallpapers: true
        property string wallpaperManagerFolder: ""
        property int pillH: 24
        property int pillRadius: 8
        property int pillBorderW: 1
        property color pill: "#333333"
        property color pillBorder: "#666666"
        property color seal: "white"
        property color ink: "white"
        property color widgetIconColor: "white"
        property bool styleShadow: false
        property string barPosition: "top"
        property color pillShadow: "black"
        property string mono: "monospace"
        property var tooltipOwner: null
        property int pickerCalls: 0
        property int shuffleCalls: 0
        function widgetContentColor(group, fallback) { return fallback }
        function toggleImagePicker(mode, screen) { if (mode === "wallpaper") pickerCalls++ }
        function shuffleWallpapers() { shuffleCalls++ }
        function hideTooltip(owner) {}
        function showTooltip(text, x, y, bottom, owner) {}
    }
    Component.onCompleted: {
        var component = Qt.createComponent(%s)
        if (component.status !== Component.Ready) {
            console.warn("QR04W_COMPILE_ERROR", component.errorString())
            Qt.quit(); return
        }
        var widget = component.createObject(null, {"root": stub})
        if (widget === null) {
            console.warn("QR04W_INSTANCE_ERROR", component.errorString())
            Qt.quit(); return
        }
        widget.nextWallpaper()
        if (stub.pickerCalls !== 1 || stub.shuffleCalls !== 0)
            console.warn("QR04W_NO_FOLDER_FAILED", stub.pickerCalls, stub.shuffleCalls)
        stub.wallpaperManagerFolder = "/fake"
        widget.nextWallpaper()
        widget.openPicker()
        stub.modWallpapers = false
        if (stub.pickerCalls !== 2 || stub.shuffleCalls !== 1 || widget.implicitWidth !== 0)
            console.warn("QR04W_ENABLED_FAILED", stub.pickerCalls, stub.shuffleCalls, widget.implicitWidth)
        else console.log("QR04W_WIDGET_BEHAVIOR_PASS")
        Qt.callLater(Qt.quit)
    }
}
'''

for variant in ('', 'variants/V2/'):
    target = PROJECT / 'versions/V1' / variant / 'modules/WallpaperWidget.qml'
    with tempfile.TemporaryDirectory(prefix='qr04w-widget-', dir=os.environ['TMPDIR']) as temp:
        probe = Path(temp) / 'shell.qml'
        probe.write_text(QML % json.dumps(target.as_uri()))
        env = os.environ.copy()
        env.pop('DISPLAY', None)
        env['QT_QPA_PLATFORM'] = 'wayland'
        env['NO_COLOR'] = '1'
        try:
            run = subprocess.run(['qs', '-n', '-p', str(probe)], env=env,
                                 text=True, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, timeout=8)
            output = run.stdout
        except subprocess.TimeoutExpired as exc:
            output = (exc.stdout or b'').decode(errors='replace')
        ok = 'QR04W_WIDGET_BEHAVIOR_PASS' in output and 'QR04W_' not in output.replace('QR04W_WIDGET_BEHAVIOR_PASS', '')
        print(('PASS' if ok else 'FAIL') + ': ' + str(target.relative_to(PROJECT)))
        if not ok:
            print(output[-5000:])
            raise SystemExit(1)
