import re
from pathlib import Path
repo = Path('.')
source = (repo / 'tests/test-vertical-bar-layout.py').read_text()
fixture = source.split("write_text('''import QtQuick", 1)[1].split("'''", 1)[0]
fixture = 'import QtQuick' + fixture[:fixture.index(' property int step:')]
fixture, width_bindings = re.subn(r'property int verticalBarWidth: [^\n]+', 'property int verticalBarWidth: 40', fixture)
fixture, surface_bindings = re.subn(r'property int verticalModuleSurfaceWidth: .*', 'property int verticalModuleSurfaceWidth: 32', fixture)
assert width_bindings == 1
assert surface_bindings == 1
fixture = fixture.replace('  property int panelRadius: 6', '''  property int wsPillPad: 2
  property int pillH: 28
  property int pillRadius: 6
  property bool styleBorder: true
  property int pillBorderW: styleBorder ? 1 : 0
  property color pill: "#222222"
  property color pillBorder: "#555555"
  property bool styleShadow: false
  property color pillShadow: "#000000"
  property int panelRadius: 6''', 1)
fixture = fixture.replace(' Component { id: widget;', ' Component { id: cpuWidget; CpuWidget { root:harness.state } }\\n Component { id: widget;')
fixture = fixture.replace('G5:widget', 'G5:cpuWidget,G4:memoryWidget,G9:mediaWidget')
fixture = fixture.replace(' Component { id: cpuWidget;', ' Component { id: memoryWidget; MemoryWidget { root:harness.state } }\\n Component { id: mediaWidget; MprisWidget { root:harness.state } }\\n Component { id: cpuWidget;')
fixture = fixture.replace('ListElement {gid:"G5"; extra:false}', 'ListElement {gid:"G5"; extra:false} ListElement {gid:"G4"; extra:false} ListElement {gid:"G9"; extra:false}')
fixture = fixture.replace('  property int panelRadius: 6', '''  property int barAnim: 0
  property bool compactCpu: false
  property bool compactGpu: false
  property bool compactMemory: false
  property bool compactMpris: true
  property bool modCpu: true
  property bool modGpu: true
  property bool modMemory: true
  property bool modMpris: true
  property bool gpuAvailable: true
  property int systemCpuPercent: 100
  property var systemCpuHistory: []
  property int cpuTemperatureC: 42
  property int gpuPercent: 100
  property var gpuHistory: []
  property string gpuName: "Test GPU"
  property int gpuTemperatureC: 42
  property int systemMemPercent: 45
  property real systemMemUsedGiB: 13.1
  property real systemMemTotalGiB: 32
  property bool memVisible: false
  property bool gpuVisible: false
  property bool mprisVisible: false
  property int panelRadius: 6''', 1)
fixture = fixture.replace(' QtObject {\n  id: owner\n  property string screenName', ''' QtObject {
  id: owner
  property color accent: "#ff8800"
  property bool dragging: false
  property var srcModel: null
  property int srcIndex: -1
  property var dropModel: null
  property int dropIndex: -1
  property string screenName''', 1)
fixture = fixture.replace('AiPanelSurface { id: connectedSurface; root:harness.state; targetX:0; reveal:1 }', '')
lines = fixture.split('\n')
# find duplicate property definitions by scanning object scopes
import ast
# Simpler: print lines 125-145 of the generated shell.qml
shell = 'ShellRoot {\n    id: harness\n' + fixture
print('\n'.join(shell.split('\n')[125:145]))
