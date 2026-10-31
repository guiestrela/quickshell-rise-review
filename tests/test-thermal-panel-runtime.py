#!/usr/bin/env python3
"""Exercise thermal display and source selection with fictitious sensors."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-thermal-', dir='/tmp') as directory:
    base = Path(directory)
    runtime = base / 'runtime'
    runtime.mkdir(mode=0o700)
    panels, modules = base / 'panels', base / 'modules'
    panels.mkdir()
    modules.mkdir()
    source = repo / 'versions/V1/variants/V2'
    text = (source / 'panels/ThermalsPanel.qml').read_text()
    text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', text, flags=re.M)
    text = text.replace('PanelWindow {', 'Rectangle {\n    width: 800; height: 700\n    property var screen', 1)
    text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n', '', text, flags=re.M)
    text = text.replace('id: card\n', 'id: card; objectName: "card"\n')
    text = text.replace('id: sourceOption\n', 'id: sourceOption; objectName: "source-" + modelData.id\n')
    text = text.replace('id: thermalRow\n', 'id: thermalRow; objectName: "sensor-" + label\n')
    (panels / 'ThermalsPanel.qml').write_text(text)
    for name in ['UiText', 'PillShadow', 'SidePanelPositioner']:
        (modules / f'{name}.qml').write_bytes((source / 'modules' / f'{name}.qml').read_bytes())
    (modules / 'ConnectedPanelSurface.qml').write_text('''import QtQuick
Item { property var root; property bool ownerActive; property real targetX; property real reveal }
''')
    theme = []
    colors = {'fillActive','fillHover','fillIdle','ink','panelBorder','seal','sealRaw','sep','sumi','sumiHi','accentHint','color02','color03'}
    for field in sorted(set(re.findall(r'thermalPanel\.root\.(\w+)', text))):
        if field in colors:
            theme.append(f'property color {field}: "#999999"')
        elif field == 'activePopupScreen':
            theme.append('property var activePopupScreen: ({width:800,height:700})')
        elif field == 'mono':
            theme.append('property string mono: "monospace"')
        elif field == 'barPosition':
            theme.append('property string barPosition: "top"')
        elif field in {'barTemperatureSourceAvailable','barTemperatureSourceLabel','evenW'}:
            continue
        elif field == 'barTemperatureSource':
            theme.append('property string barTemperatureSource: "cpu"')
        elif field == 'gpuName':
            theme.append('property string gpuName: "Fixture GPU"')
        elif field in {'thermalVisible', 'cpuTemperatureAvailable'}:
            theme.append(f'property bool {field}: false')
        else:
            theme.append(f'property real {field}: 6')
    theme += ['property bool barVertical: false', 'property real verticalBarWidth: 40',
              'property bool styleShadow: false', 'property color pillShadow: "black"',
              'function verticalAnchorY(name) { return 200 }',
              'function evenW(value) { return Math.round(value/2)*2 }',
              'function barTemperatureSourceAvailable(name) { return name !== "memory" }',
              'function barTemperatureSourceLabel(name) { return name.toUpperCase() }']
    qml = '''import QtQuick
import QtTest
import "panels"
Item {
 width:800; height:700
 QtObject { id: theme; THEME }
 ThermalsPanel { id: panel; root: theme }
 TestCase {
  name: "ThermalsPanel"; when: windowShown
  function test_sensors_selection_and_close() {
   compare(panel.status(95,80,100), "HOT")
   compare(panel.status(70,80,100), "WARM")
   compare(panel.status(40,80,100), "NORMAL")
   compare(panel.status(40,0,0), "LIVE")
   theme.thermalVisible = true
   tryCompare(panel,"visible",true)
   theme.cpuTemperatureC = 50
   theme.cpuTemperatureMaxC = 80
   theme.cpuTemperatureCriticalC = 100
   var row = findChild(panel,"sensor-CPU package")
   verify(row !== null)
   compare(row.value,50)
   compare(row.scaleMax,100)
   var gpu = findChild(panel,"source-gpu")
   verify(gpu !== null)
   function area(item) {
    for(var i=0;i<item.children.length;i++)
     if(item.children[i].toString().indexOf("MouseArea")>=0) return item.children[i]
    return null
   }
   mouseClick(area(gpu))
   compare(theme.barTemperatureSource,"gpu")
   compare(gpu.selected,true)
   var memory = findChild(panel,"source-memory")
   compare(area(memory).enabled,false)
   mouseClick(area(memory))
   compare(theme.barTemperatureSource,"gpu")
   theme.cpuTemperatureC = 0
   compare(row.visible,false)
   var card = findChild(panel,"card")
   card.forceActiveFocus()
   keyClick(Qt.Key_Escape)
   compare(theme.thermalVisible,false)
  }
 }
}
'''.replace('THEME', '\n'.join(theme))
    probe = base / 'tst_thermal.qml'
    probe.write_text(qml)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               QT_QPA_PLATFORMTHEME='', XDG_RUNTIME_DIR=str(runtime))
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(probe)],
                            env=env, text=True, capture_output=True, timeout=15)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode:
        raise SystemExit(result.returncode)
    assert not any(error in output for error in ['ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign', ' ERROR'])
