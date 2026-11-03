#!/usr/bin/env python3
"""Exercise shared tray geometry with mock items and no SystemTray connection."""
from pathlib import Path
import os
import re
import subprocess
import tempfile
from qml_fixture_source import qml_fixture_text

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-shared-tray-', dir='/tmp') as directory:
    folder = Path(directory)
    runtime = folder / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant in ('V1', 'V2'):
        text = qml_fixture_text(repo / f'variants/{variant}/modules/TrayWidget.qml')
        text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', text, flags=re.M)
        text = text.replace('required property SystemTrayItem', 'required property var')
        text = text.replace('model: SystemTray.items', 'model: SystemTray.items.values')
        text = text.replace('SystemTray.items', 'rootMod.root.fixtureItems')
        (folder / f'Tray{variant}.qml').write_text(text)
    for name in ('UiText', 'IconText', 'TooltipMixin'):
        (folder / f'{name}.qml').write_text((repo / f'shared/components/{name}.qml').read_text())
    (folder / 'tst_tray.qml').write_text('''import QtQuick
import QtTest
Item {
 width:300; height:300
 QtObject {
  id:theme
  property var fixtureItems: ({values:[{id:"a",icon:""},{id:"b",icon:""}]})
  property var trayPinned: []
  property bool trayVisible:false
  property bool barVertical:false
  property real v2ActionIconCellWidth:22
  property real v2IconClusterSpacing:2
  property color ink:"white"; property color seal:"orange"; property color paper:"black"
  property string mono:"monospace"
  property var tooltipOwner:null
  function widgetContentColor(group, fallback) { return fallback }
  function widgetHasFill(group) { return false }
  function widgetAssignedColor(group) { return "black" }
  function showTooltip() {} function hideTooltip() {}
  function trayToggleHide(item) {}
 }
 TrayV1 { id:v1; root:theme; width:implicitWidth; height:implicitHeight }
 TrayV2 { id:v2; root:theme; y:100; width:implicitWidth; height:implicitHeight }
 TestCase {
  name:"SharedTrayGeometry"; when:windowShown
  function test_pins_and_orientation() {
   tryCompare(v1,"implicitWidth",22)
   theme.trayPinned=["a"]
   tryCompare(v1,"implicitWidth",42)
   theme.trayPinned=["a","b"]
   tryCompare(v1,"implicitWidth",38)
   theme.barVertical=true
   tryCompare(v1,"implicitHeight",28)
   tryCompare(v2,"implicitHeight",58)
   theme.barVertical=false
   tryCompare(v2,"implicitHeight",28)
   theme.fixtureItems=({values:[]})
   theme.trayPinned=[]
   tryCompare(v1,"implicitWidth",0)
   tryCompare(v2,"implicitWidth",0)
  }
 }
}
''')
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(folder)],
                            capture_output=True, text=True, timeout=20,
                            env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen',
                                 'QT_QUICK_BACKEND': 'software', 'QT_QPA_PLATFORMTHEME': '',
                                 'XDG_RUNTIME_DIR': str(runtime)})
    output = result.stdout + result.stderr
    print(output, end='')
    assert result.returncode == 0, output
    assert not any(error in output for error in ('ReferenceError', 'TypeError', 'Unable to assign', 'Binding loop', ' ERROR')), output
