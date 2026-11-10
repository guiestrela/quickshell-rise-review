#!/usr/bin/env python3
"""Drive V1 vertical production slot delegates through BarSlot drag logic."""
from pathlib import Path
import os
import re
import subprocess
import tempfile
from qml_fixture_source import copy_qml_fixture, qml_fixture_source, qml_fixture_text, write_hyprland_stub

repo = Path(__file__).resolve().parents[1]
bar_source = (repo / "variants/V1/BarSlot.qml").read_text()
drag_start = bar_source.index("    property bool dragging:")
drag_end = bar_source.index("    // ── order persistence", drag_start)
drag_block = bar_source[drag_start:drag_end]
conn_start = bar_source.index("    Connections {\n        target: barSlot.root")
conn_end = bar_source.index("\n\n    readonly property color accent", conn_start)
connection_block = bar_source[conn_start:conn_end]
move_start = bar_source.index("    function moveSlotToTray(model, index) {")
restore_start = bar_source.index("    function restoreTrayWidget(gid) {", move_start)
restore_end = bar_source.index("\n    function saveOrder", restore_start)
move_restore = bar_source[move_start:restore_end]
for old, new in [("leftModel", "barSlot.fixtureLeftModel"), ("centerModel", "barSlot.fixtureCenterModel"), ("rightModel", "barSlot.fixtureRightModel")]:
    move_restore = move_restore.replace(old, new)

with tempfile.TemporaryDirectory(prefix="v1-vertical-pointer-", dir=os.environ.get("TMPDIR")) as folder:
    base = Path(folder)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    copy_qml_fixture(repo / "shared/logic/NordVpnLayout.js", base)
    for name in ["VerticalBarContent.qml", "SidePanelPositioner.qml", "WorkspaceWidget.qml", "PillShadow.qml",
                 "CpuWidget.qml", "MemoryWidget.qml", "MprisWidget.qml", "UiText.qml", "IconText.qml", "TooltipMixin.qml"]:
        copy_qml_fixture(qml_fixture_source(repo / "variants/V1/modules" / name), base)
    copy_qml_fixture(repo / "shared/logic/MonitorWorkspaces.js", base)
    for name in ["VerticalBarContent.qml", "WorkspaceWidget.qml"]:
        path = base / name
        path.write_text(path.read_text().replace("import Quickshell.Hyprland", 'import "."').replace("import Quickshell\n", ""))
    vertical_path = base / "VerticalBarContent.qml"
    vertical_text = vertical_path.read_text().replace(
        "SystemClock { id: now; precision: SystemClock.Minutes }",
        "QtObject { id: now; property date date: new Date() }")
    vertical_text = vertical_text.replace(
        "property int revision: 0",
        "property int revision: 0\n    property int testDelegateAdded: 0\n    property int testDelegateRemoved: 0")
    vertical_text = vertical_text.replace(
        "onObjectAdded: layoutTimer.restart()",
        "onObjectAdded: { rail.testDelegateAdded++; layoutTimer.restart() }")
    vertical_text = vertical_text.replace(
        "onObjectRemoved: layoutTimer.restart()",
        "onObjectRemoved: { rail.testDelegateRemoved++; layoutTimer.restart() }")
    vertical_path.write_text(vertical_text)
    custom_types = set(re.findall(r"(?m)^\s*([A-Z][A-Za-z0-9_]*)\s*\{", vertical_text))
    builtin_types = {"Item", "Rectangle", "Text", "MouseArea", "HoverHandler", "DragHandler", "TapHandler",
                     "Loader", "Flickable", "Column", "Row", "Repeater", "Instantiator", "Shape", "ShapePath",
                     "PathLine", "PathQuad", "PathCubic", "Timer", "WheelHandler", "QtObject", "Component", "Connections",
                     "Window", "FocusScope", "Behavior", "NumberAnimation", "ParallelAnimation",
                     "SequentialAnimation", "ColorAnimation", "PathView", "ListView", "GridView", "Qt",
                     "VerticalBarContent", "SystemClock"}
    generic_stub = ('import QtQuick\nItem { property var root; property var screen; property var monitor; '
                    'property var theme; property var layout; property var player; property var model; '
                    'property string text; property string icon; property string label; property int mode:0; '
                    'property int percent:0; property bool active:false; property bool playing:false; '
                    'property bool compact:false; property bool verticalCompact:false; implicitWidth:32; implicitHeight:28 }\n')
    (base / "GenericWidget.qml").write_text(generic_stub)
    for type_name in custom_types | {"CpuWidget", "MemoryWidget", "MprisWidget", "WorkspaceWidget"}:
        if type_name not in builtin_types:
            (base / (type_name + ".qml")).write_text(generic_stub)
    (base / "WorkspaceWidget.qml").write_text(generic_stub)
    path = base / "WorkspaceWidget.qml"
    path.write_text(path.read_text().replace('import "../../../shared/logic/MonitorWorkspaces.js" as MonitorWorkspaces',
                                              'import "MonitorWorkspaces.js" as MonitorWorkspaces'))
    for name in ["ArchUpdaterWidget", "TrayWidget", "NotificationWidget", "IdleInhibitorWidget",
                 "MediaBrowserWidget", "ThemeDisplayWidget", "WeatherWidget"]:
        (base / (name + ".qml")).write_text('import QtQuick\nItem { property var root; property var screen; implicitWidth:30; implicitHeight:28 }\n')
    (base / "MprisSelect.qml").write_text('import QtQuick\nItem { property var player: ({trackTitle:"Song",trackArtist:"Artist",canGoPrevious:true,canGoNext:true}); property bool active:true; property bool playing:false; property bool canGoPrevious:true; property bool canGoNext:true; property bool canTogglePlayback:true }')
    (base / "ParticleStream.qml").write_text('import QtQuick\nItem { objectName:"vertical-gap-effect"; property var theme; property var layout; property int mode; property bool active; property string monitor }')
    write_hyprland_stub(base)

    source = qml_fixture_text(repo / "tests/test-vertical-bar-layout.py")
    fixture = source.split("write_text('''import QtQuick", 1)[1].split("'''", 1)[0]
    fixture = "import QtQuick" + fixture[:fixture.index(" property int step:")]
    fixture = fixture.replace("ShellRoot {", "Item {", 1)
    fixture = fixture.replace('import QtQuick\n', 'import QtQuick\nimport QtTest\nimport "NordVpnLayout.js" as NordVpnLayout\n', 1)
    fixture = fixture.replace("import Quickshell\n", "", 1)
    fixture, width_count = re.subn(r"property int verticalBarWidth: [^\n]+", "property int verticalBarWidth: 40", fixture)
    fixture, surface_count = re.subn(r"property int verticalModuleSurfaceWidth: .*", "property int verticalModuleSurfaceWidth: 32", fixture)
    if width_count != 1 or surface_count != 1:
        raise SystemExit("V1 vertical fixture geometry declarations not found")
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
    fixture = fixture.replace(' Component { id: widget;', ' Component { id: cpuWidget; CpuWidget { root:harness.state } }\n Component { id: widget;', 1)
    fixture = fixture.replace('G5:widget', 'G5:cpuWidget,G4:memoryWidget,G9:mediaWidget', 1)
    fixture = fixture.replace(' Component { id: cpuWidget;', ' Component { id: memoryWidget; MemoryWidget { root:harness.state } }\n Component { id: mediaWidget; MprisWidget { root:harness.state } }\n Component { id: cpuWidget;', 1)
    fixture = fixture.replace('ListElement {gid:"G5"}', 'ListElement {gid:"G5"} ListElement {gid:"G4"} ListElement {gid:"G9"}', 1)
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
  property int systemCpuPercent: 42
  property var systemCpuHistory: []
  property int cpuTemperatureC: 42
  property int gpuPercent: 24
  property var gpuHistory: []
  property string gpuName: "Fixture GPU"
  property int gpuTemperatureC: 42
  property int systemMemPercent: 45
  property real systemMemUsedGiB: 13.1
  property real systemMemTotalGiB: 32
  property bool memVisible: false
  property bool gpuVisible: false
  property bool mprisVisible: false
  property int panelRadius: 6''', 1)
    fixture = fixture.replace('   AiPanelSurface { id: connectedSurface; root:harness.state; targetX:0; reveal:1 }', '', 1)

    owner_start = fixture.index(" QtObject {\n  id: owner")
    owner_end = fixture.index("\n Component { id: cpuWidget;", owner_start)
    owner_qml = r''' Item {
  id: barSlot
  parent: window.contentItem
  x: 0; y: 0; width: harness.state.verticalBarWidth; height: window.height
  property var root: harness.state
  property string screenName: "fixture"
  property var screen: ({name:"fixture",width:800,height:1400})
  property var fixtureLeftModel: left
  property var fixtureCenterModel: center
  property var fixtureRightModel: right
  property var registry: ({G1:widget,G5:cpuWidget,G4:memoryWidget,G9:mediaWidget,G6:widget})
  property bool _orderLoaded: true
  property int orderSaveCalls: 0
  property color accent: root.seal
  function saveOrder() { orderSaveCalls++ }
  MOVE_RESTORE
  CONNECTIONS
  DRAG
 }
 QtObject { id:leftRowItem; property var rep:({count:0}); property var rmodel:left }
 QtObject { id:centerRowItem; property var rep:({count:0}); property var rmodel:center }
 QtObject { id:rightRowItem; property var rep:({count:0}); property var rmodel:right }
'''.replace("MOVE_RESTORE", move_restore).replace("CONNECTIONS", connection_block).replace("DRAG", drag_block)
    fixture = fixture[:owner_start] + owner_qml + fixture[owner_end:]
    fixture = fixture.replace("barWindow:owner", "barWindow:barSlot")
    rail_start = fixture.index("  VerticalBarContent { id: rail;")
    rail_end = fixture.index("\n", rail_start)
    rail_line = fixture[rail_start:rail_end]
    rail_line = rail_line.replace("id: rail;", 'id: rail; z:2; x:harness.state.barPosition === "right" ? window.width-width : 0;')
    rail_line = re.sub(r"registry:\([^;]*\)", "registry:({G1:Qt.createComponent('GenericWidget.qml',Component.PreferSynchronous),G5:Qt.createComponent('GenericWidget.qml',Component.PreferSynchronous),G4:Qt.createComponent('GenericWidget.qml',Component.PreferSynchronous),G9:Qt.createComponent('GenericWidget.qml',Component.PreferSynchronous),G6:Qt.createComponent('GenericWidget.qml',Component.PreferSynchronous)})", rail_line)
    replacement = ('  Rectangle { anchors.fill:parent; z:1; color:"black"; visible:harness.state.barUnlocked; '
                   'MouseArea { anchors.fill:parent; enabled:harness.state.barUnlocked; onClicked:harness.state.barUnlocked=false } }\n'
                   + rail_line + '\n  QtObject { id:verticalLoader; property var item:rail }')
    fixture = fixture[:rail_start] + replacement + fixture[rail_end:]
    fixture = fixture.rstrip()[:-1] + r'''
 TestCase {
  name: "V1VerticalSlotPointer"
  when: windowShown
  property var rail: verticalLoader.item
  function findSlotIn(item, region, index) {
   var data = item.modelData
   if (data && data.region === region && data.index === index) return item
   for (var i=0; i<item.children.length; i++) { var found=findSlotIn(item.children[i], region, index); if (found) return found }
   return null
  }
  function findSlot(region,index) { return findSlotIn(rail.regionColumns[region], region, index) }
  function findNamed(item,name) {
   if (item.objectName === name) return item
   for (var i=0; i<item.children.length; i++) { var found=findNamed(item.children[i],name); if (found) return found }
   return null
  }
  function findFlickable(item) {
   if (item && item.contentHeight !== undefined && item.interactive !== undefined && item.contentItem !== undefined) return item
   for (var i=0; i<item.children.length; i++) { var found=findFlickable(item.children[i]); if (found) return found }
   return null
  }
  function waitForVerticalLayout() {
   var previousSignature="", stableSamples=0
   for (var attempt=0; attempt<80; attempt++) {
    var stable=true, parts=[]
    for (var region=0; region<3; region++) {
     var column=rail.regionColumns[region], model=region===0 ? left : region===1 ? center : right
     var expectedIndices=[]
     for (var row=0; row<model.count; row++)
      if (harness.state.barUnlocked || model.get(row).gid !== "") expectedIndices.push(row)
     if (column.children.length !== expectedIndices.length) { stable=false; break }
     var bottom=-Infinity
     for (var i=0; i<column.children.length; i++) {
      var cell=column.children[i]
      if (!cell.modelData || cell.modelData.region !== region || cell.modelData.index !== expectedIndices[i]
          || cell.height <= 0 || cell.y < bottom + (i ? column.spacing : 0)) { stable=false; break }
      parts.push(region+":"+cell.modelData.index+":"+Math.round(cell.x*100)+":"+Math.round(cell.y*100)+":"+Math.round(cell.height*100))
      bottom=cell.y+cell.height
     }
     if (!stable) break
    }
    var signature=parts.join("|")
    if (stable && signature===previousSignature) stableSamples++
    else stableSamples=0
    previousSignature=stable ? signature : ""
    if (stable && stableSamples>=3) return true
    wait(10)
   }
   return false
  }
  function test_vertical_drag_drop_tray_and_cancel() {
   wait(200)
   harness.state.barUnlocked=true
   var scrollView=findFlickable(rail)
   verify(scrollView && !scrollView.interactive,"V1 edit mode disables Flickable scrolling while dragging")
   var baseLeftCount=left.count, baseCenterCount=center.count, baseRightCount=right.count
   while (left.count < 20) left.append({gid:"", extra:true})
   while (center.count < 8) center.append({gid:"", extra:true})
   while (right.count < 20) right.append({gid:"", extra:true})
   wait(100)
   verify(scrollView.contentHeight > scrollView.height,"fixture must overflow to exercise wheel/drag competition")
   scrollView.contentY=300
   wait(40)
   var wheelSource=findSlot(2,0)
   var wheelPoint=wheelSource.mapToItem(window.contentItem,wheelSource.width/2,wheelSource.height/2)
   mousePress(window,wheelPoint.x,wheelPoint.y,Qt.LeftButton)
   verify(barSlot.dragActive,"wheel competition probe must begin an actual vertical drag")
   var contentYBeforeDragWheel=scrollView.contentY
   mouseWheel(window.contentItem,wheelPoint.x,wheelPoint.y,0,-120,Qt.NoButton,Qt.NoModifier)
   compare(scrollView.contentY,contentYBeforeDragWheel,"wheel input must not scroll slots beneath an active drag")
   mouseRelease(window.contentItem,wheelPoint.x,wheelPoint.y,Qt.LeftButton)
   wait(280)
   var idleWheelStart=scrollView.contentY
   mouseWheel(window.contentItem,wheelPoint.x,wheelPoint.y,0,-120,Qt.NoButton,Qt.NoModifier)
   verify(scrollView.contentY>idleWheelStart,"wheel scrolling remains available when no drag is active")
   scrollView.contentY=0
   while (left.count > baseLeftCount) left.remove(left.count-1)
   while (center.count > baseCenterCount) center.remove(center.count-1)
   while (right.count > baseRightCount) right.remove(right.count-1)
   wait(80)
   harness.state.barPosition="right"
   wait(40)
   compare(rail.x,window.width-rail.width,"V1 drag fixture places the vertical rail on the right edge")
   verify(waitForVerticalLayout(),"Instantiator delegates must settle before pointer coordinates are chosen")
   var source=findSlot(0,0), target=findSlot(2,0)
   verify(source && target)
   compare(source.gid,"G1"); compare(source.modelData.region,0); compare(source.modelData.index,0)
   compare(target.gid,"G6"); compare(target.modelData.region,2); compare(target.modelData.index,0)
   var from=source.mapToItem(window.contentItem,source.width/2,source.height/2)
   var to=target.mapToItem(window.contentItem,target.width/2,target.height/2)
   verify(from.y < to.y && Math.abs(from.x-to.x) < 1,"source and target pointer centers must match laid-out cells")
   var saves=barSlot.orderSaveCalls
   rail.testDelegateAdded=0; rail.testDelegateRemoved=0
   mousePress(window,from.x,from.y,Qt.LeftButton)
   verify(barSlot.dragging && barSlot.dragActive,"V1 press enters shared BarSlot drag cycle")
   compare(barSlot.srcModel,left); compare(barSlot.srcIndex,0)
   mouseMove(window,to.x,to.y,100)
   compare(barSlot.dropModel,right); compare(barSlot.dropIndex,0)
   var marker=findNamed(target,"vertical-drop-target-2-0")
   verify(marker && marker.visible,"V1 destination feedback tracks the pointer")
   compare(barSlot.orderSaveCalls,saves,"V1 pointer movement does not persist order before release")
   mouseRelease(window.contentItem,to.x,to.y,Qt.LeftButton)
   wait(100)
   console.log("SLOT_DELEGATE_CHURN V1 added="+rail.testDelegateAdded+" removed="+rail.testDelegateRemoved)
   compare(rail.testDelegateAdded,0,"a widget swap must update existing vertical delegates, not rebuild the Instantiator model")
   compare(rail.testDelegateRemoved,0,"a widget swap must not destroy unrelated vertical delegates")
   compare(left.get(0).gid,"G6"); compare(right.get(0).gid,"G1")
   compare(barSlot.orderSaveCalls,saves+1)
   verify(waitForVerticalLayout(),"V1 cross-region drag must leave one visual delegate per model slot")
   harness.state.barPosition="left"
   wait(40)
   compare(rail.x,0,"V1 rail returns to the left edge for the remaining drag matrix")
   verify(!barSlot.dragActive && !harness.state.trayDragActive && !harness.state.trayDropActive)
   var empty=findSlot(0,4), sourceAgain=findSlot(2,0)
   verify(empty && sourceAgain,"fixed empty V1 cells remain drop targets")
   var ep=empty.mapToItem(window.contentItem,empty.width/2,empty.height/2)
   var sp=sourceAgain.mapToItem(window.contentItem,sourceAgain.width/2,sourceAgain.height/2)
   mousePress(window.contentItem,sp.x,sp.y,Qt.LeftButton); mouseMove(window.contentItem,ep.x,ep.y,100)
   compare(barSlot.dropModel,left); compare(barSlot.dropIndex,4)
   mouseRelease(window.contentItem,ep.x,ep.y,Qt.LeftButton); wait(100)
   compare(left.get(4).gid,"G1"); compare(right.get(0).gid,"")
   verify(waitForVerticalLayout(),"V1 drop into intentional empty slot must not retain the source delegate")
   var traySource=findSlot(0,0)
   var tp0=traySource.mapToItem(window.contentItem,traySource.width/2,traySource.height/2)
   var trayGlobal=rail.mapToGlobal(500,1050), trayLocal=window.contentItem.mapFromGlobal(trayGlobal.x,trayGlobal.y)
   harness.state.trayVisible=true
   harness.state.setTrayDropRect("fixture",{x:trayGlobal.x-20,y:trayGlobal.y-20,width:40,height:40})
   mousePress(window.contentItem,tp0.x,tp0.y,Qt.LeftButton); mouseMove(window.contentItem,trayLocal.x,trayLocal.y,100)
   verify(barSlot.dropTray && harness.state.trayDropActive,"global TrayPanel rectangle is a target")
   mouseRelease(window.contentItem,trayLocal.x,trayLocal.y,Qt.LeftButton); wait(100)
   compare(harness.state.trayWidgets.length,1); compare(harness.state.trayWidgets[0],"G6")
   verify(barSlot.restoreTrayWidget("G6")); compare(harness.state.trayWidgets.length,0); compare(left.get(0).gid,"G6")
   verify(waitForVerticalLayout(),"V1 tray return must preserve one visual delegate per model slot")
   var lockSource=findSlot(0,0), lockTarget=findSlot(2,0)
   var lp=lockSource.mapToItem(window.contentItem,lockSource.width/2,lockSource.height/2)
   var rp=lockTarget.mapToItem(window.contentItem,lockTarget.width/2,lockTarget.height/2)
   mousePress(window.contentItem,lp.x,lp.y,Qt.LeftButton); mouseMove(window.contentItem,rp.x,rp.y,100)
   harness.state.barUnlocked=false; wait(40)
   verify(!barSlot.dragging && !barSlot.dragActive,"V1 lock cancels a live drag")
   compare(left.get(0).gid,"G6"); compare(right.get(0).gid,"")
   verify(waitForVerticalLayout(),"V1 lock should hide only intentional empty slots")
   mouseRelease(window.contentItem,rp.x,rp.y,Qt.LeftButton)
   harness.state.layoutProtected=true
   verify(!harness.state.barUnlocked,"V1 lock remains applied before protected state")
   function replaceModel(model, gids) {
    model.clear()
    for (var i=0; i<gids.length; i++) model.append({gid:gids[i]})
   }
   harness.state.layoutProtected=false
   harness.state.barUnlocked=true
   for (var cycle=0; cycle<5; cycle++) {
    left.clear(); center.clear(); right.clear(); wait(30)
    verify(waitForVerticalLayout(),"V1 cleared region models must remove all old visual delegates, cycle " + cycle)
    replaceModel(left,["G1","G2","G3","G5","G4","G9","","","",""])
    replaceModel(center,["G8"])
    replaceModel(right,["G6","G10","","","","",""])
    wait(30)
    verify(waitForVerticalLayout(),"V1 region rebuild must yield one delegate per slot, cycle " + cycle)
   }
  }
 }
}
}'''
    qml = base / "tst_v1_vertical_slots.qml"
    qml.write_text(fixture)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen",
               QT_QUICK_BACKEND="software", QT_QPA_PLATFORMTHEME="")
    env.pop("WAYLAND_DISPLAY", None); env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(qml)], env=env,
                            text=True, capture_output=True, timeout=30)
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode:
        raise SystemExit(result.returncode)
    if "V1VerticalSlotPointer::test_vertical_drag_drop_tray_and_cancel()" not in output:
        raise SystemExit("QtTest did not execute the V1 vertical drag test")
    if any(token in output for token in ["ReferenceError", "TypeError", "Binding loop", "Unable to assign"]):
        raise SystemExit("V1 QML fixture emitted a runtime error")
