#!/usr/bin/env python3
"""Hidden production V1 widget + native primitives; no live actions."""
import os, re, subprocess, tempfile
from pathlib import Path
repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='display-v1-widget-', dir=os.environ['TMPDIR']) as work:
    folder = Path(work)
    for name in ['DisplayManagerWidget.qml', 'PillShadow.qml', 'IconText.qml', 'TooltipMixin.qml']:
        (folder / name).write_bytes((repo / 'versions/V1/modules' / name).read_bytes())
    (folder / 'shell.qml').write_text('''import QtQuick
import Quickshell
ShellRoot {
    QtObject {
        id: theme
        property bool modDisplayManager: true
        property bool displayManagerVisible: false
        property color ink: "#eeeeee"
        property color widgetIconColor: ink
        property string mono: "monospace"
        property color seal: "#bbbb88"
        property int pillH: 22
        property int pillRadius: 7
        property color pill: "#202020"
        property color pillBorder: "#555555"
        property real pillBorderW: 1
        property bool styleShadow: false
        property color pillShadow: "#aa000000"
        property string barPosition: "top"
        function showTooltip() { }
        function hideTooltip() { }
        function toggleDisplayManager() { }
    }
    DisplayManagerWidget { id: widget; root: theme; width: implicitWidth; height: implicitHeight }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children || []) { var hit = find(child, name); if (hit) return hit }
        return null
    }
    Timer {
        interval: 450; running: true
        onTriggered: {
            var pill = find(widget, "display-widget-pill")
            var icon = find(widget, "display-widget-icon")
            if (!pill || !icon || icon.font.pixelSize !== 14 || icon.font.family !== "Material Symbols Rounded") { console.error("missing native pill / standard 14px icon"); Qt.quit(); return }
            if (pill.height !== theme.pillH || pill.radius !== theme.pillRadius || pill.color !== theme.pill || pill.border.color !== theme.pillBorder || pill.border.width !== theme.pillBorderW) throw new Error("pill tokens mismatch")
            var shadow = pill.children[0]
            if (!shadow || shadow.visible) throw new Error("shadow must follow style")
            theme.styleShadow = true
            theme.pillBorderW = 0
            theme.displayManagerVisible = true
            Qt.callLater(function() {
                if (!shadow.visible || pill.border.width !== 0) throw new Error("native style effects do not update")
                if (widget.implicitWidth > 34 || widget.implicitWidth < 30) throw new Error("nonstandard slot size")
                console.log("DISPLAY_V1_WIDGET_STYLE_PASS native pill/shadow/borderless; 14px icon; no monitor actions")
                Qt.quit()
            })
        }
    }
}''')
    env = dict(os.environ, QT_QPA_PLATFORM='wayland'); env.pop('DISPLAY', None)
    result = subprocess.run(['qs', '-n', '-p', str(folder / 'shell.qml')], env=env, capture_output=True, text=True, timeout=8)
    output = re.sub(r'\x1b\[[0-9;]*m', '', result.stdout + result.stderr)
    print(output)
    assert result.returncode == 0 and 'DISPLAY_V1_WIDGET_STYLE_PASS' in output, 'native V1 widget style failed'
    assert not any(token in output for token in ['ReferenceError', 'TypeError', 'Unable to assign', 'ERROR:']), 'binding error'
