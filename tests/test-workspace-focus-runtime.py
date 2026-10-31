#!/usr/bin/env python3
"""Production workspace delegates with fake Hyprland state and inert navigation."""
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-workspace-focus-', dir='/tmp') as directory:
    temp = Path(directory)
    runtime = temp / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant, path in [('V1', 'versions/V1'), ('V2', 'versions/V1/variants/V2')]:
        folder = temp / variant
        folder.mkdir()
        for name in ['WorkspaceWidget', 'PillShadow']:
            source = (repo / path / 'modules' / f'{name}.qml').read_text()
            source = source.replace('import Quickshell.Hyprland', 'import "."')
            source = source.replace('id: wsCell\n', 'id: wsCell; objectName: "workspace-" + wsId\n')
            (folder / f'{name}.qml').write_text(source)
        (folder / 'qmldir').write_text('singleton Hyprland 1.0 Hyprland.qml\n')
        (folder / 'Hyprland.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    property var focusedWorkspace: ({id: 1})
    property var workspaces: ({values: [{id: 1}, {id: 3}, {id: -99}]})
}
''')
        qml = '''import QtQuick
import QtTest
import "VARIANT" as Widgets
Item {
    width: 600; height: 400
    QtObject {
        id: theme
        property bool barVertical: false
        property string workspaceMode: "5"
        property string workspaceStyle: "numbers"
        property bool workspaceVisible: false
        property int selected: 0
        property int wsPillPad: 2
        property int pillH: 28
        property int pillRadius: 6
        property int panelButtonRadius: 6
        property int pillBorderW: 1
        property color pill: "black"
        property color pillBorder: "gray"
        property color ink: "white"
        property color seal: "red"
        property string mono: "monospace"
        property bool styleShadow: false
        property string barPosition: "top"
        property color pillShadow: "black"
        function gotoWorkspace(id) { selected = id }
        function widgetHasBorder(gid) { return false }
        function widgetContentColor(gid, fallback) { return fallback }
    }
    Widgets.WorkspaceWidget { id: widget; root: theme; y: 10 }
    function mouse(item) {
        for (var child of item.children)
            if (typeof child.clicked === "function") return child
        return null
    }
    TestCase {
        name: "WorkspaceFocusVARIANT"; when: windowShown
        function test_focus_models_and_navigation() {
            compare(widget.workspaceList, [1, 2, 3, 4, 5])
            var first = findChild(widget, "workspace-1")
            verify(first !== null); verify(first.isFocused)
            Widgets.Hyprland.focusedWorkspace = {id: 3}
            compare(findChild(widget, "workspace-1"), first, "in-range focus preserves delegates")
            compare(first.isFocused, false)
            var third = findChild(widget, "workspace-3")
            verify(third.isFocused)
            mouseClick(mouse(third), 5, 5)
            compare(theme.selected, 3)
            Widgets.Hyprland.focusedWorkspace = {id: 12}
            compare(widget.workspaceList, [1, 2, 3, 4, 5, 12])
            Widgets.Hyprland.focusedWorkspace = {id: -5}
            compare(widget.workspaceList, [1, 2, 3, 4, 5])
            theme.workspaceMode = "10"
            compare(widget.workspaceList.length, 10)
            theme.workspaceMode = "active"
            compare(widget.workspaceList, [1, 3])
            Widgets.Hyprland.focusedWorkspace = {id: 17}
            compare(widget.workspaceList, [1, 3, 17])
            theme.barVertical = true
            for (var style of ["default", "numbers", "magic", "kanji"]) {
                theme.workspaceStyle = style
                verify(widget.implicitHeight > 28)
            }
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
