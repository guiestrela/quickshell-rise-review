#!/usr/bin/env python3
"""Exercise the production V2 SSID label with inert state and real Qt text layout."""
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
source = (repo / 'versions/V1/variants/V2/modules/NetworkWidget.qml').read_text()


def block(type_name, identity):
    position = source.index('id: ' + identity)
    start = source.rfind(type_name + ' {', 0, position)
    end = source.index('{', start) + 1
    depth = 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


with tempfile.TemporaryDirectory(prefix='rise-ssid-width-', dir='/tmp') as directory:
    temp = Path(directory)
    runtime = temp / 'runtime'
    runtime.mkdir(mode=0o700)
    qml = '''import QtQuick
import QtTest
Item {
    width: 160; height: 40
    QtObject {
        id: theme
        property string mono: "monospace"
        property bool iconMode: false
        function iconOnly(gid) { return iconMode }
    }
    QtObject {
        id: rootMod
        property var root: theme
        property string mode: "none"
        property string ssid: ""
        property color contentColor: "white"
    }
    component UiText: Text { renderType: Text.NativeRendering }
    METRICS
    LABEL
    TestCase {
        name: "NetworkSsidWidth"; when: windowShown
        function test_mode_text_and_font_changes() {
            compare(wifiSsidLabel.width, 0)
            rootMod.mode = "wifi"
            compare(wifiSsidLabel.text, "Wi-Fi")
            verify(wifiSsidLabel.width > 0 && wifiSsidLabel.width <= 88)
            rootMod.ssid = "A very long fixture network name that must be elided"
            compare(wifiSsidLabel.width, 88)
            theme.mono = "sans-serif"
            compare(wifiSsidLabel.width, 88)
            rootMod.ssid = "x"
            compare(wifiSsidLabel.width, Math.ceil(wifiSsidMetrics.advanceWidth))
            theme.iconMode = true
            compare(wifiSsidLabel.width, 0)
            theme.iconMode = false
            rootMod.mode = "ethernet"
            compare(wifiSsidLabel.width, 0)
        }
    }
}
'''.replace('METRICS', block('TextMetrics', 'wifiSsidMetrics')).replace(
        'LABEL', block('UiText', 'wifiSsidLabel'))
    probe = temp / 'tst_ssid.qml'
    probe.write_text(qml)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               QT_QPA_PLATFORMTHEME='', XDG_RUNTIME_DIR=str(runtime))
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(probe)],
                            env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode:
        raise SystemExit(result.returncode)
    assert not any(error in output for error in (
        'Binding loop', 'ReferenceError', 'TypeError', 'Unable to assign'))
