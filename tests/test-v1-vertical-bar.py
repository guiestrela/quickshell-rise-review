#!/usr/bin/env python3
"""Production V1 vertical layout with inert service widgets; no live actions."""
from pathlib import Path
import os, re, shutil, subprocess, tempfile
repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-v1-vertical-', dir='/tmp') as directory:
    base = Path(directory)
    runtime = base / 'runtime'; runtime.mkdir(mode=0o700)
    for name in ['VerticalBarContent.qml', 'SidePanelPositioner.qml', 'WorkspaceWidget.qml', 'PillShadow.qml', 'CpuWidget.qml', 'MemoryWidget.qml', 'MprisWidget.qml', 'UiText.qml', 'IconText.qml', 'TooltipMixin.qml']:
        shutil.copy2(repo / 'versions/V1/modules' / name, base)
    for name in ['ArchUpdaterWidget', 'TrayWidget', 'NotificationWidget', 'IdleInhibitorWidget', 'MediaBrowserWidget', 'ThemeDisplayWidget', 'WeatherWidget']:
        (base / (name + '.qml')).write_text('import QtQuick\nItem { property var root; property var screen; implicitWidth: 30; implicitHeight: 28 }\n')
    (base / 'MprisSelect.qml').write_text('import QtQuick\nItem { property var player: ({trackTitle:"Long song name",trackArtist:"Artist",canGoPrevious:true,canGoNext:true}); property bool active: true; property bool playing: false }')
    (base / 'ParticleStream.qml').write_text('import QtQuick\nItem { objectName: "vertical-gap-effect"; property var theme; property var layout; property int mode; property bool active; property string monitor }')
    source = (repo / 'tests/test-vertical-bar-layout.py').read_text()
    fixture = source.split("write_text('''import QtQuick", 1)[1].split("'''", 1)[0]
    fixture = 'import QtQuick' + fixture[:fixture.index(' property int step:')]
    fixture = fixture.replace('barShellStyle === "fit" ? 44 : 40', '40')
    fixture = fixture.replace('  property int panelRadius: 6', '''  property int wsPillPad: 2
  property int pillH: 28
  property int pillRadius: 6
  property bool styleBorder: true
  property int pillBorderW: styleBorder ? 1 : 0
  property color pill: "#222222"
  property color pillBorder: "#555555"
  property bool styleShadow: false
  property color pillShadow: "#000000"
  property int panelRadius: 6''')
    fixture = fixture.replace(' Component { id: widget;', ' Component { id: cpuWidget; CpuWidget { root: harness.state } }\n Component { id: widget;')
    fixture = fixture.replace('G5:widget', 'G5:cpuWidget,G4:memoryWidget,G9:mediaWidget')
    fixture = fixture.replace(' Component { id: cpuWidget;', ' Component { id: memoryWidget; MemoryWidget { root: harness.state } }\n Component { id: mediaWidget; MprisWidget { root: harness.state } }\n Component { id: cpuWidget;')
    fixture = fixture.replace('ListElement {gid:"G5"}', 'ListElement {gid:"G5"} ListElement {gid:"G4"} ListElement {gid:"G9"}')
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
  property var tooltipOwner: null
  property bool memVisible: false
  property bool gpuVisible: false
  property bool mprisVisible: false
  property int panelRadius: 6''')
    fixture = fixture.replace('   AiPanelSurface { root:harness.state; targetX:0; reveal:1 }', '')
    fixture += '''
 function check(condition, label) { if (!condition) throw new Error(label) }
 Timer {
  id: modes
  interval: 25; running: true; repeat: true
  property int phase: 0
  onTriggered: {
   harness.state.barAnim = phase + 1
   Qt.callLater(function() {
    var found = false
    function visit(item) {
     if (item.objectName === "vertical-gap-effect") { check(item.mode === modes.phase + 1, "gap effect mode forwarded"); found = true }
     for (var i=0; i<item.children.length; i++) visit(item.children[i])
    }
    visit(rail)
    check(found, "vertical effect instantiated")
    modes.phase++
    if (modes.phase === 8) { harness.state.barAnim = 0; modes.stop() }
   })
  }
 }
 Timer {
  interval: 300; running: true
  onTriggered: {
   var cells = rail.layoutSnapshot()
   function descendants(item, visit) { visit(item); for (var i=0; i<item.children.length; i++) descendants(item.children[i], visit) }
   var checked = false
   descendants(rail, function(item) {
    if (item.fullMode !== undefined) {
     check(item.fullMode && item.width === 34 && item.height === 160, "V2 vertical full media geometry")
     check(item.parent.scale === 1, "media controls stay at native size")
    }
    if (item.verticalCompact !== undefined && item.percent === 100) {
     check(item.verticalCompact, "CPU uses compact presentation vertically")
     check(item.width <= 80, "CPU fits without scaling")
     check(item.parent.scale === 1, "CPU text stays at native size")
     checked = true
    }
   })
   check(checked, "production CPU rendered")
   var borders = []
   descendants(rail, function(item) { if (item.objectName === "vertical-run-surface") borders.push(item) })
   check(borders.length > 0, "split surfaces instantiated")
   harness.state.styleBorder = false
   for (var b=0; b<borders.length; b++) check(borders[b].border.width === 0, "Border off")
   harness.state.styleBorder = true
   for (var b=0; b<borders.length; b++) check(borders[b].border.width === 1, "Border on")
   check(cells.length === 9, "all regions present")
   check(rail.runs.length === 9, "split layout renders separate surfaces")
   rail.splitState = Qt.createQmlObject('import QtQuick; QtObject { property var leftSplits: []; property var rightSplits: []; property var boundarySplits: [false,false] }', harness)
   rail.updateRuns()
   check(rail.runs.length === 1, "merge layout renders one surface")
   rail.splitState = null
   rail.updateRuns()
   check(rail.runs.length === 9, "split layout restored")
   for (var i=1; i<cells.length; i++) check(cells[i].y >= cells[i-1].y + cells[i-1].height, "no overlapping widgets")
   check(card.x === 48, "left panel gap")
   check(harness.state.anchorsByName.cpu > 0, "panel anchor published")
   harness.state.barPosition = "right"
   Qt.callLater(function() {
    check(card.x === 800 - 40 - 280 - 8, "right panel gap")
    harness.state.barPosition = "top"
    Qt.callLater(function() {
     check(card.x === 200 && card.y === 100, "horizontal bindings restored")
     check(!harness.state.compactCpu && harness.state.compactMpris, "saved presentation preferences preserved")
     descendants(rail, function(item) {
      if (item.fullMode !== undefined) check(item.fullMode, "full media restored horizontally")
      if (item.verticalCompact !== undefined && item.percent === 100) check(!item.verticalCompact, "full CPU restored horizontally")
     })
     console.log("V1_VERTICAL_LAYOUT_PASS")
     Qt.quit()
    })
   })
  }
 }
}
'''
    if os.environ.get('V1_VERTICAL_PREVIEW'):
        fixture = fixture.replace('   harness.state.barPosition = "right"', '   window.contentItem.grabToImage(function(result) { result.saveToFile("' + os.environ['V1_VERTICAL_PREVIEW'] + '"); console.log("V1_VERTICAL_LAYOUT_PASS"); Qt.quit() }); return;\n   harness.state.barPosition = "right"')
    (base / 'shell.qml').write_text(fixture)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='')
    result = subprocess.run(['qs','-n','-p',str(base/'shell.qml')],env=env,capture_output=True,text=True,timeout=10)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and 'V1_VERTICAL_LAYOUT_PASS' in output
    assert not re.search(r'ERROR|ReferenceError|TypeError|Unable to assign|Binding loop', output)
