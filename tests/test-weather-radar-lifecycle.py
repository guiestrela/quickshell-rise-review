#!/usr/bin/env python3
"""Radar lifecycle with inert image URLs and Process; never access map services."""
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-radar-lifecycle-', dir='/tmp') as directory:
    temp = Path(directory)
    runtime = temp / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant, path in [('V1', 'versions/V1'), ('V2', 'versions/V1/variants/V2')]:
        folder = temp / variant
        folder.mkdir()
        source = (repo / path / 'modules/WeatherRadar.qml').read_text()
        source = source.replace('import Quickshell\n', '').replace('import Quickshell.Io', 'import "."')
        source = source.replace('id: metadata\n', 'id: metadata; objectName: "metadata"\n')
        source = source.replace('Image {', 'InertImage {')
        (folder / 'WeatherRadar.qml').write_text(source)
        (folder / 'UiText.qml').write_bytes((repo / path / 'modules/UiText.qml').read_bytes())
        (folder / 'InertImage.qml').write_text('''import QtQuick
Item { property string source: ""; property bool asynchronous; property bool cache; property int fillMode }
''')
        (folder / 'Process.qml').write_text('''import QtQuick
QtObject {
    property var command: []
    property var stdout
    property bool running: false
    property int starts: 0
    onRunningChanged: if (running) starts++
}
''')
        (folder / 'StdioCollector.qml').write_text('''import QtQuick
QtObject { property string text: ""; signal streamFinished() }
''')
        qml = '''import QtQuick
import QtTest
import "VARIANT" as Widgets
Item {
    width: 320; height: 240
    QtObject {
        id: theme
        property bool weatherVisible: false
        property color sumiHi: "gray"
        property color sumi: "gray"
        property string mono: "monospace"
        property int tileRadius: 4
        property color fillHover: "gray"
        property color fillIdle: "black"
        property color sep: "gray"
        property color ink: "white"
        property color seal: "red"
        property color paper: "black"
    }
    Widgets.WeatherRadar { id: radar; root: theme; latitude: 0; longitude: 0 }
    TestCase {
        name: "RadarLifecycleVARIANT"; when: windowShown
        function test_closed_open_and_zoom() {
            var metadata = findChild(radar, "metadata")
            wait(30)
            compare(metadata.starts, 0, "closed weather panel must not query metadata")
            theme.weatherVisible = true
            tryCompare(metadata, "starts", 1)
            metadata.running = false
            metadata.stdout.text = JSON.stringify({host: "https://tilecache.rainviewer.com",
                radar: {past: [{path: "/v2/radar/fixture"}]}})
            metadata.stdout.streamFinished()
            compare(radar.radarPath, "/v2/radar/fixture")
            radar.setZoom(100); compare(radar.zoom, radar.maxZoom)
            radar.setZoom(-10); compare(radar.zoom, radar.minZoom)
            theme.weatherVisible = false
            compare(radar.tilesActive, false)
        }
    }
}
'''.replace('VARIANT', variant)
        (temp / f'tst_{variant}.qml').write_text(qml)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               QT_QPA_PLATFORMTHEME='', XDG_RUNTIME_DIR=str(runtime))
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(temp)],
                            env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode:
        raise SystemExit(result.returncode)
    assert not any(error in output for error in (
        'ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign'))
