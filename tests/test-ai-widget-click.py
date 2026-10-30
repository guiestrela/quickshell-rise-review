#!/usr/bin/env python3
"""Real Qt mouse events against production AI handlers; agent commands stay inert."""
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]


def block(source, start):
    end = source.index('{', start) + 1
    depth = 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


with tempfile.TemporaryDirectory(prefix='rise-ai-click-', dir='/tmp') as directory:
    temp = Path(directory)
    runtime = temp / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant, path in [('V1', 'versions/V1'), ('V2', 'versions/V1/variants/V2')]:
        source = (repo / path / 'modules/ClaudeWidget.qml').read_text()
        action = block(source, source.index('    function openSelectedAgent()'))
        mouse = block(source, source.rfind('    MouseArea {'))
        mouse = mouse.replace('MouseArea {', 'MouseArea { id: clickArea', 1)
        qml = '''import QtQuick
import QtTest
Item {
    id: rootMod; width: 80; height: 28
    property bool shown: true
    property var root: QtObject {
        property string aiTool: "claude"
        property bool aiUsageVisible: false
        function refreshAiUsage() {}
    }
    QtObject { id: tip; function show() {}
        function hide() {} }
    QtObject {
        id: launchAgent
        property var command: []
        property bool running: false
    }
    ACTION
    MOUSE
    TestCase {
        name: "AiWidgetClickVARIANT"; when: windowShown
        function test_left_and_right_clicks() {
            mouseClick(clickArea, 5, 5, Qt.LeftButton)
            compare(rootMod.root.aiUsageVisible, true)
            compare(launchAgent.running, false)
            for (var tool of ["claude", "codex", "opencode", "copilot"]) {
                rootMod.root.aiTool = tool
                rootMod.root.aiUsageVisible = true
                launchAgent.running = false
                mouseClick(clickArea, 5, 5, Qt.RightButton)
                compare(rootMod.root.aiUsageVisible, false)
                compare(launchAgent.running, true)
                compare(launchAgent.command, ["bash", "-lc",
                    "omarchy-launch-floating-terminal-with-presentation " + tool])
            }
        }
    }
}
'''.replace('ACTION', action).replace('MOUSE', mouse).replace('VARIANT', variant)
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
        'ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign',
        'is ambiguous', 'injection of parameters'))
