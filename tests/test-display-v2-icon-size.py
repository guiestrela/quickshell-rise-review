#!/usr/bin/env python3
"""Instantiate V2 widget hidden; assert its icon uses V1's 14px size."""
import os, re, subprocess, tempfile
from pathlib import Path
repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='display-v2-icon-', dir=os.environ['TMPDIR']) as work:
    folder = Path(work)
    (folder/'DisplayManagerWidget.qml').write_bytes((repo/'versions/V1/variants/V2/modules/DisplayManagerWidget.qml').read_bytes())
    (folder/'TooltipMixin.qml').write_bytes((repo/'versions/V1/variants/V2/modules/TooltipMixin.qml').read_bytes())
    (folder/'shell.qml').write_text('''import QtQuick
import Quickshell
ShellRoot {
    QtObject {
        id: theme
        property bool modDisplayManager: true
        property bool displayManagerVisible: false
        property color widgetIconColor: "#eeeeee"
        property color seal: "#aaaa88"
        property string mono: "monospace"
        function widgetContentColor(id, fallback) { return fallback }
        function widgetHasFill(id) { return false }
        function showTooltip() { }
        function hideTooltip() { }
        function toggleDisplayManager() { }
    }
    DisplayManagerWidget { id: widget; root: theme; width: implicitWidth; height: implicitHeight }
    Timer {
        interval: 300; running: true
        onTriggered: {
            var icon = widget.children[0]
            if (icon.font.pixelSize !== 14) console.error("DISPLAY_V2_ICON_SIZE_FAIL expected14 actual" + icon.font.pixelSize)
            else if (widget.implicitWidth !== 36 || icon.color !== theme.widgetIconColor) console.error("V2 slot/theme regression")
            else console.log("DISPLAY_V2_ICON_SIZE_PASS production widget 14px; slot36/theme preserved; hidden")
            Qt.quit()
        }
    }
}''')
    env=dict(os.environ,QT_QPA_PLATFORM='wayland');env.pop('DISPLAY',None)
    result=subprocess.run(['qs','-n','-p',str(folder/'shell.qml')],env=env,capture_output=True,text=True,timeout=8)
    output=re.sub(r'\x1b\[[0-9;]*m','',result.stdout+result.stderr)
    print(output)
    assert result.returncode==0 and 'DISPLAY_V2_ICON_SIZE_PASS' in output
    assert not any(t in output for t in ['ReferenceError','TypeError','Unable to assign','ERROR:'])
