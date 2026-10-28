#!/usr/bin/env python3
"""Render style cards with inert colors, without loading the installed bar."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-style-preview-', dir='/tmp') as directory:
    root = Path(directory)
    shutil.copy2(repo / 'versions/V1/modules/BarStylePreview.qml', root)
    (root / 'runtime').mkdir(mode=0o700)
    (root / 'shell.qml').write_text('''import QtQuick
import QtQuick.Window
import Quickshell
ShellRoot {
    id: harness
    property QtObject colors: QtObject {
        property color paper: "#222222"
        property color ink: "#eeeeee"
        property color seal: "#fa8072"
        property color fillIdle: "#333333"
        property color fillHover: "#444444"
        property string mono: "monospace"
    }
    Window {
        id: previewWindow
        visible: true; width: 600; height: 75
        color: "#181818"
        Row {
            x: 5; y: 5; spacing: 5
            Repeater {
                model: ["full", "fit", "dock", "notch", "islands"]
                BarStylePreview {
                    required property string modelData
                    theme: harness.colors; width: 114
                    mode: modelData; label: modelData
                    frost: true; shadow: true
                }
            }
        }
    }
    Timer {
        interval: 300; running: true
        onTriggered: {
            previewWindow.contentItem.grabToImage(function(result) {
                if (!result.saveToFile("CAPTURE_PATH")) { Qt.exit(1); return }
                console.log("BAR_STYLE_PREVIEW_PASS")
                Qt.quit()
            })
        }
    }
}
'''.replace('CAPTURE_PATH', str(root / 'preview.png')))
    env = dict(os.environ, XDG_RUNTIME_DIR=str(root / 'runtime'),
               QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               QT_QPA_PLATFORMTHEME='')
    env.pop('WAYLAND_DISPLAY', None)
    result = subprocess.run(['qs', '-n', '-p', str(root / 'shell.qml')],
                            env=env, capture_output=True, text=True, timeout=10)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode or 'BAR_STYLE_PREVIEW_PASS' not in output or 'WARN scene:' in output:
        raise SystemExit(result.returncode or 1)
    if (root / 'preview.png').read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
        raise SystemExit('Preview capture is not a PNG')
    capture = os.environ.get('RISE_STYLE_PREVIEW_CAPTURE')
    if capture:
        shutil.copy2(root / 'preview.png', capture)
