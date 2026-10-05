#!/usr/bin/env python3
"""Production hover event/timer checks; translated widget, no live actions."""
import os, re, subprocess, tempfile
from pathlib import Path
repo = Path(__file__).resolve().parents[1]
for variant in ['V1', 'V2']:
    source = repo / ('versions/V1/modules' if variant == 'V1' else 'versions/V1/variants/V2/modules')
    with tempfile.TemporaryDirectory(prefix='display-hover-', dir=os.environ['TMPDIR']) as work:
        folder = Path(work)
        for name in ['DisplayManagerWidget.qml', 'TooltipMixin.qml']:
            (folder / name).write_bytes((source / name).read_bytes())
        for name in ['IconText.qml', 'PillShadow.qml']:
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
        property var tooltipOwner: null
        property string tooltipText: ""
        property var received: null
        property bool hidden: false
        property int clicks: 0
        function widgetContentColor(id, fallback) { return fallback }
        function widgetHasFill(id) { return false }
        function showTooltip(text, x, top, bottom, owner) { received = [text, x, top, bottom, owner]; tooltipOwner = owner }
        function hideTooltip(owner) { hidden = owner === widget }
        function toggleDisplayManager(screen, owner) { if (owner === widget) clicks++ }
    }
    Item {
        x: 73; y: 17
        DisplayManagerWidget { id: widget; root: theme; x: 401; y: 29; width: implicitWidth; height: 28 }
    }
    property var area: null
    Timer {
        interval: 30; running: true
        onTriggered: {
            for (var child of widget.children) if (child.hoverEnabled !== undefined) area = child
            if (!area) throw new Error("missing production hover MouseArea")
            area.entered()
        }
    }
    Timer {
        interval: 500; running: true
        onTriggered: {
            var got = theme.received
            var top = widget.mapToItem(null, widget.width / 2, 0)
            var bottom = widget.mapToItem(null, widget.width / 2, widget.height)
            if (!got || got[1] !== top.x || got[2] !== top.y || got[3] !== bottom.y || got[4] !== widget)
                throw new Error("hover must anchor to translated widget, not origin: " + got)
            area.exited()
            if (!theme.hidden) throw new Error("exit must hide own tooltip")
            area.clicked(null)
            if (theme.clicks !== 1) throw new Error("panel click regression")
            console.log("DISPLAY_HOVER_ANCHOR_PASS x=" + got[1] + " top=" + got[2] + " bottom=" + got[3])
            Qt.quit()
        }
    }
}''')
        env = dict(os.environ, QT_QPA_PLATFORM='wayland'); env.pop('DISPLAY', None)
        try:
            result = subprocess.run(['qs', '-n', '-p', str(folder / 'shell.qml')], env=env, capture_output=True, text=True, timeout=3)
            output = result.stdout + result.stderr
            rc = result.returncode
        except subprocess.TimeoutExpired as error:
            output = (error.stdout or b'').decode() + (error.stderr or b'').decode()
            rc = -1
        output = re.sub(r'\x1b\[[0-9;]*m', '', output)
        print(variant, output)
        assert rc == 0 and 'DISPLAY_HOVER_ANCHOR_PASS' in output, variant + ' hover anchoring failed'
        assert not any(t in output for t in ['ReferenceError', 'TypeError', 'Unable to assign', 'ERROR:']), 'binding error'
