#!/usr/bin/env python3
"""Deliver real V1/V2 clock clicks with only command execution intercepted."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import QtTest
import "variants/V1/modules" as V1
import "variants/V2/modules" as V2
Item {
    id: host
    width: 400; height: 160
    property var widget: null
    QtObject {
        id: theme
        property bool clock12h: false
        property string mono: "monospace"
        property color ink: "white"
        property bool barUnlocked: false
        property var tooltipOwner: null
        property string tooltipText: ""
        function hideTooltip(owner) {}
        function showTooltip(text, x, y, bottom, owner) {}
        function widgetContentColor(group, fallback) { return fallback }
    }
    Component { id: v1; V1.ClockWidget { root: theme; width: 160; height: 32 } }
    Component { id: v2; V2.ClockWidget { root: theme; width: 160; height: 32 } }
    TestCase {
        name: "ClockTimezoneMenu"
        when: windowShown
        function cleanup() { if (host.widget) { host.widget.destroy(); host.widget=null }; wait(10) }
        function test_buttons_data() { return [{tag:"V1",variant:1},{tag:"V2",variant:2}] }
        function test_buttons(data) {
            theme.clock12h=false
            host.widget=(data.variant===1 ? v1 : v2).createObject(host)
            verify(host.widget!==null)
            wait(20)
            var launcher=findChild(host.widget,"clock-timezone-command")
            verify(launcher!==null)
            compare(launcher.launches,0)
            mouseClick(host.widget,80,16,Qt.RightButton)
            compare(launcher.launches,1)
            compare(JSON.stringify(launcher.command),JSON.stringify(["omarchy-menu-timezone"]))
            compare(theme.clock12h,false)
            mouseClick(host.widget,80,16,Qt.RightButton)
            compare(launcher.launches,2)
            mouseClick(host.widget,80,16,Qt.LeftButton)
            compare(theme.clock12h,true)
            compare(launcher.launches,2)
        }
    }
}
'''

with tempfile.TemporaryDirectory(prefix="rise-clock-click-", dir=os.environ.get("TMPDIR")) as tmp:
    base=Path(tmp)
    for rel in ("shared/components/ClockWidget.qml", "shared/components/UiText.qml",
                "shared/components/TooltipMixin.qml", "shared/logic/ClockWidgetValuesLogic.js",
                "variants/V1/modules/ClockWidget.qml", "variants/V2/modules/ClockWidget.qml"):
        target=base/rel
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/rel,target)
    clock=base/"shared/components/ClockWidget.qml"
    text=clock.read_text().replace('import Quickshell.Io','import "stubs"')
    assert text.count('id: tzRunner')==1
    clock.write_text(text.replace('id: tzRunner','id: tzRunner\n        objectName: "clock-timezone-command"'))
    stubs=base/"shared/components/stubs"
    stubs.mkdir()
    (stubs/"Process.qml").write_text('import QtQuick\nQtObject { property var command: []; property bool running: false; property int launches: 0; onRunningChanged: if (running) launches++ }\n')
    (base/"tst_clock.qml").write_text(QML)
    runner=shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"
    env=dict(os.environ,QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software",QT_QPA_PLATFORMTHEME="",QT_FORCE_STDERR_LOGGING="1")
    for key in ("DISPLAY","WAYLAND_DISPLAY","DBUS_SESSION_BUS_ADDRESS"):
        env.pop(key,None)
    result=subprocess.run([runner,"-input",str(base/"tst_clock.qml")],env=env,capture_output=True,text=True,timeout=20)
    output=result.stdout+result.stderr
    print(output)
    assert result.returncode==0 and '0 failed' in output, "Real clock-click regression failed"
    assert not re.search(r'ReferenceError|TypeError|Unable to assign|Binding loop',output),output
    print("Clock V1/V2 clicks PASS; timezone command execution intercepted, no timezone changed")
