#!/usr/bin/env python3
"""Exercise real vertical V2 slot buttons and drag events with inert models."""
from pathlib import Path
import os
import re
import subprocess
import tempfile

from qml_fixture_source import copy_qml_fixture, write_hyprland_stub

repo = Path(__file__).resolve().parents[1]
bar_slot_source = (repo / "variants/V2/BarSlot.qml").read_text()
drag_start = bar_slot_source.index("    property bool dragging:")
drag_end = bar_slot_source.index("    // ── order persistence", drag_start)
drag_block = bar_slot_source[drag_start:drag_end]
connection_start = bar_slot_source.index("    Connections {\n        target: barSlot.root")
connection_end = bar_slot_source.index("\n\n    readonly property color accent", connection_start)
connection_block = bar_slot_source[connection_start:connection_end]
move_start = bar_slot_source.index("    function moveSlotToTray(model, index) {")
restore_start = bar_slot_source.index("    function restoreTrayWidget(gid) {", move_start)
restore_end = bar_slot_source.index("\n    function saveOrder", restore_start)
move_restore_block = bar_slot_source[move_start:restore_end]
for old, new in [("leftModel", "barSlot.fixtureLeftModel"),
                 ("centerModel", "barSlot.fixtureCenterModel"),
                 ("rightModel", "barSlot.fixtureRightModel")]:
    move_restore_block = move_restore_block.replace(old, new)
for old, new in [("leftModel", "left"), ("centerModel", "center"), ("rightModel", "right")]:
    drag_block = drag_block.replace(old, new)
drag_block = drag_block.replace("[left, center, right]", "[barSlot.fixtureLeftModel, barSlot.fixtureCenterModel, barSlot.fixtureRightModel]")
with tempfile.TemporaryDirectory(prefix="v2-slot-pointer-", dir=os.environ.get("TMPDIR")) as folder:
    base = Path(folder)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    copy_qml_fixture(repo / "shared/logic/NordVpnLayout.js", base)
    for name in ["SidePanelPositioner.qml", "AiPanelSurface.qml", "WorkspaceWidget.qml"]:
        copy_qml_fixture(repo / "variants/V2/modules" / name, base)

    vertical = (repo / "variants/V2/modules/VerticalBarContent.qml").read_text()
    vertical = vertical.replace(
        "property int revision: 0",
        "property int revision: 0\n    property int testDelegateAdded: 0\n    property int testDelegateRemoved: 0")
    vertical = vertical.replace(
        "onObjectAdded: layoutTimer.restart()",
        "onObjectAdded: { rail.testDelegateAdded++; layoutTimer.restart() }")
    vertical = vertical.replace(
        "if (object) rail.detachRemovedDelegate(object)",
        "rail.testDelegateRemoved++; if (object) rail.detachRemovedDelegate(object)")
    vertical = vertical.replace("import Quickshell\n", "")
    vertical = vertical.replace("SystemClock { id: now; precision: SystemClock.Minutes }",
                                "QtObject { id: now; property date date: new Date() }")
    vertical = vertical.replace(
        'import "../../../shared/components" as CommonComponents', 'import "."')
    vertical = vertical.replace("CommonComponents.", "")
    vertical = vertical.replace(
        'import "../../../shared/logic/VerticalBarContentValuesLogic.js" as VerticalBarContentValuesLogic',
        'import "VerticalBarContentValuesLogic.js" as VerticalBarContentValuesLogic')
    vertical = vertical.replace(
        'import "../../../shared/logic/VerticalBarContentLogic.js" as VerticalBarContentLogic',
        'import "VerticalBarContentLogic.js" as VerticalBarContentLogic')
    (base / "VerticalBarContent.qml").write_text(vertical)
    for name in ["VerticalBarContentValuesLogic.js", "VerticalBarContentLogic.js", "MonitorWorkspaces.js"]:
        copy_qml_fixture(repo / "shared/logic" / name, base)
    for name in ["VerticalBarContent.qml", "WorkspaceWidget.qml"]:
        path = base / name
        path.write_text(path.read_text().replace('import Quickshell.Hyprland', 'import "."'))
    workspace = base / "WorkspaceWidget.qml"
    workspace.write_text(workspace.read_text().replace(
        'import "../../../shared/logic/MonitorWorkspaces.js" as MonitorWorkspaces',
        'import "MonitorWorkspaces.js" as MonitorWorkspaces'))
    workspace.write_text("import QtQuick" + chr(10) +
                         "Item { property var root; property var monitor; implicitWidth: 32; implicitHeight: 28 }" + chr(10))
    for name in ["IndicatorsWidget.qml", "UiText.qml", "TooltipMixin.qml"]:
        copy_qml_fixture(repo / "shared/components" / name, base)
    for name in ["ArchUpdaterWidget", "TrayWidget", "NotificationWidget", "MediaBrowserWidget", "ThemeDisplayWidget"]:
        (base / (name + ".qml")).write_text(
            'import QtQuick\nItem { property var root; property var screen; implicitWidth: 30; implicitHeight: 28 }\n')
    (base / "WeatherWidget.qml").write_text(
        'import QtQuick\nItem { property var root; property bool weatherLoaded: true; property string weatherTempStr: "25°C"; implicitWidth: 32; implicitHeight: 28 }\n')
    (base / "Action.qml").write_text(
        "import QtQuick" + chr(10) +
        "Rectangle { id: action; property string label: \"\"; property color contentColor: \"white\"; " +
        "signal activated(); signal secondaryActivated(); implicitWidth: 34; implicitHeight: 32; " +
        "Text { anchors.centerIn: parent; text: action.label; color: action.contentColor } " +
        "MouseArea { anchors.fill: parent; onClicked: mouse.button === Qt.RightButton ? action.secondaryActivated() : action.activated() } }" + chr(10))
    write_hyprland_stub(base)

    source = (repo / "tests/test-vertical-bar-layout.py").read_text()
    fixture = source.split("(base / 'shell.qml').write_text('''", 1)[1].split("'''", 1)[0]
    fixture, hidden_widget_count = fixture.replace(
        "Component { id: widget; Item { implicitWidth:32; implicitHeight:28 } }",
        "Component { id: widget; Item { implicitWidth:32; implicitHeight:28 } }\n"
        "  Component { id: hiddenWidget; Item { property bool moduleEnabled:true; visible:moduleEnabled; implicitWidth:moduleEnabled ? 32 : 0; implicitHeight:28 } }",
        1), 1
    if hidden_widget_count != 1:
        raise SystemExit("Could not add the disabled-widget drag fixture")
    fixture, fill_color_count = fixture.replace(
        'function widgetFillColor(gid) { return "transparent" }',
        'function widgetFillColor(gid) { return gid === "G24" ? "#cc2266" : "transparent" }', 1), 1
    if fill_color_count != 1:
        raise SystemExit("Could not color the disabled-widget fixture")
    fixture, right_position_count = fixture.replace(
        "x: 820; y: 0; width: harness.state.verticalBarWidth;",
        'x: harness.state.barPosition === "right" ? 760 : 820; y: 0; width: harness.state.verticalBarWidth;', 1), 1
    if right_position_count != 1:
        raise SystemExit("Could not make pointer fixture follow left/right bar position")
    fixture = fixture.replace("import QtQuick\n", "import QtQuick\nimport QtTest\n", 1)
    fixture = fixture.replace("import Quickshell\n", "", 1)
    fixture = fixture.replace("ShellRoot {", "Item {", 1)
    fixture = fixture.replace('import QtTest\n', 'import QtTest\nimport "NordVpnLayout.js" as NordVpnLayout\n', 1)
    owner_start = fixture.index(" QtObject {\n  id: owner")
    owner_end = fixture.index("\n Component { id: widget;", owner_start)
    owner_fixture = r''' Item {
  id: barSlot
  parent: window.contentItem
  x: 0; y: 0; width: harness.state.verticalBarWidth; height: window.height
  property var root: harness.state
  property string screenName: "fixture"
  property var screen: ({name:"fixture",width:800,height:1400})
  property var registry: ({G1:widget,G5:widget,G6:widget,G24:hiddenWidget})
  property var fixtureLeftModel: left
  property var fixtureCenterModel: center
  property var fixtureRightModel: right
  property bool _orderLoaded: true
  property int orderSaveCalls: 0
  property int revision: 0
  property color accent: root.seal
  property int leftBaseSlotCount: 10
  property int centerBaseSlotCount: 1
  property int rightBaseSlotCount: 7
  property int leftExtraSlotLimit: 10
  property int centerExtraSlotLimit: 7
  property int rightExtraSlotLimit: 13
  property var slotOperations: []
  function modelRegion(model) { return model === fixtureLeftModel ? 0 : model === fixtureCenterModel ? 1 : 2 }
  function modelForRegion(region) { return region === 0 ? fixtureLeftModel : region === 1 ? fixtureCenterModel : fixtureRightModel }
  function baseCountForRegion(region) { return region === 0 ? leftBaseSlotCount : region === 1 ? centerBaseSlotCount : rightBaseSlotCount }
  function extraLimitForRegion(region) { return region === 0 ? leftExtraSlotLimit : region === 1 ? centerExtraSlotLimit : rightExtraSlotLimit }
  function canAddExtraSlot(region) { var model=modelForRegion(region); return model.count-baseCountForRegion(region) < extraLimitForRegion(region) }
  function addExtraSlot(model, baseCount, maxExtraCount) {
   var region = modelRegion(model); slotOperations = slotOperations.concat(["add:" + region])
   if (model.count - baseCount < maxExtraCount) model.append({gid:"", extra:true})
  }
  function removeExtraSlot(model, index, baseCount) {
   var region = modelRegion(model); slotOperations = slotOperations.concat(["remove:" + region + ":" + index])
   if (index >= baseCount && index < model.count && model.get(index).extra && model.get(index).gid === "") model.remove(index, 1)
  }
  MOVE_RESTORE
  function saveOrder() { orderSaveCalls++ }
  Rectangle { anchors.fill:parent; z:1; color:"black"; visible:barSlot.root.barUnlocked; MouseArea { anchors.fill:parent; enabled:barSlot.root.barUnlocked; onClicked:barSlot.root.barUnlocked=false } }
  CONNECTIONS
  DRAG
  QtObject { id:leftRowItem; property var rep:({count:0}); property var rmodel:left }
  QtObject { id:centerRowItem; property var rep:({count:0}); property var rmodel:center }
  QtObject { id:rightRowItem; property var rep:({count:0}); property var rmodel:right }
 }
'''.replace("MOVE_RESTORE", move_restore_block).replace("CONNECTIONS", connection_block).replace("DRAG", drag_block)
    fixture = fixture[:owner_start] + owner_fixture + fixture[owner_end:]
    fixture = fixture.replace("barWindow:owner", "barWindow:barSlot")
    rail_marker = '  VerticalBarContent { id: rail; width:harness.state.verticalBarWidth;'
    if rail_marker not in fixture:
        raise SystemExit("Could not locate the vertical rail in layout fixture")
    rail_start = fixture.index(rail_marker)
    rail_end = fixture.index("\n", rail_start)
    fixture = fixture[:rail_start] + fixture[rail_end + 1:]
    fixture, disabled = fixture.replace(
        "Timer { interval:100; repeat:true; running:true; onTriggered: {",
        "Timer { interval:100; repeat:true; running:false; onTriggered: {", 1), 1
    if disabled != 1:
        raise SystemExit("Could not disable the layout timer for pointer tests")
    if not fixture.rstrip().endswith("}"):
        raise SystemExit("Could not locate QML fixture root")
    fixture = fixture.rstrip()[:-1] + r'''
 TestCase {
  name: "V2VerticalSlotPointer"
  when: windowShown
  property var rail: verticalLoader.item
  function findObject(item, name) {
   if (item.objectName === name) return item
   for (var i=0; i<item.children.length; i++) {
    var found = findObject(item.children[i], name)
    if (found) return found
   }
   return null
  }
  function findSlotIn(item, region, index) {
   var data = item.modelData
   if (data && data.region === region && data.index === index) return item
   for (var i=0; i<item.children.length; i++) {
    var found = findSlotIn(item.children[i], region, index)
    if (found) return found
   }
   return null
  }
  function findSlot(region, index) {
   return findSlotIn(rail.regionColumns[region], region, index)
  }
  function findFlickable(item) {
   if (item && item.contentHeight !== undefined && item.interactive !== undefined && item.contentItem !== undefined) return item
   for (var i=0; i<item.children.length; i++) { var found=findFlickable(item.children[i]); if (found) return found }
   return null
  }
  function clickCenter(item) {
   verify(item && typeof item.mapToItem === "function", "pointer target must be a visual Item")
   var p = item.mapToItem(window.contentItem, item.width/2, item.height/2)
   mouseClick(window.contentItem, p.x, p.y, Qt.LeftButton)
  }
  function test_add_remove_and_move_by_pointer() {
   wait(150)
   verify(!harness.state.barUnlocked)
   var unlockPoint = rail.mapToItem(window.contentItem, rail.width/2, 500)
   mouseClick(window.contentItem, unlockPoint.x, unlockPoint.y, Qt.LeftButton, Qt.NoModifier, 0)
   wait(50)
   verify(!harness.state.barUnlocked, "a single tap must not unlock editing")
   wait(400)
   var farPoint = rail.mapToItem(window.contentItem, rail.width/2, 540)
   mouseClick(window.contentItem, unlockPoint.x, unlockPoint.y, Qt.LeftButton, Qt.NoModifier, 0)
   mouseClick(window.contentItem, farPoint.x, farPoint.y, Qt.LeftButton, Qt.NoModifier, 0)
   wait(50)
   verify(!harness.state.barUnlocked, "two taps at different positions must not unlock")
   wait(400)
   mouseClick(window.contentItem, unlockPoint.x, unlockPoint.y, Qt.LeftButton, Qt.NoModifier, 0)
   mouseClick(window.contentItem, unlockPoint.x, unlockPoint.y, Qt.LeftButton, Qt.NoModifier, 0)
   wait(100)
   verify(harness.state.barUnlocked, "a vertical double-tap should unlock editing")
   var scrollView = findFlickable(rail)
   verify(scrollView && !scrollView.interactive, "V2 edit mode disables Flickable scrolling while dragging")
   var addTop = findObject(rail, "vertical-slot-add-cell-0")
   var addCenter = findObject(rail, "vertical-slot-add-cell-1")
   var addBottom = findObject(rail, "vertical-slot-add-cell-2")
   verify(addTop && addTop.visible, "left-region plus should be visible in edit mode")
   verify(addCenter && addCenter.visible, "center-region plus should be visible in edit mode")
   verify(addBottom && addBottom.visible, "right-region plus should be visible in edit mode")
   var addTopPoint = addTop.mapToItem(window.contentItem, addTop.width/2, addTop.height/2)
   clickCenter(addTop)
   wait(80)
   compare(left.count, 11, "left-region click adds one extra slot")
   verify(left.get(10).extra)
   addTop = findObject(rail, "vertical-slot-add-cell-0")
   verify(addTop && addTop.visible, "plus remains available for additional slots")
   var addTopAfter = addTop.mapToItem(window.contentItem, addTop.width/2, addTop.height/2)
   compare(addTopAfter.x, addTopPoint.x, "plus remains at the same x after adding")
   compare(addTopAfter.y, addTopPoint.y, "plus remains at the same y after adding")
   mouseClick(window.contentItem, addTopPoint.x, addTopPoint.y, Qt.LeftButton)
   wait(80)
   compare(left.count, 12, "repeated click at the same plus coordinate adds another slot")
   verify(left.get(11).extra)
   addCenter = findObject(rail, "vertical-slot-add-cell-1")
   var addCenterPoint = addCenter.mapToItem(window.contentItem, addCenter.width/2, addCenter.height/2)
   clickCenter(addCenter)
   wait(80)
   compare(center.count, 2, "center-region click adds one extra slot")
   verify(center.get(1).extra)
   verify(addCenter && addCenter.visible, "center plus persists after first add")
   var addCenterAfter = addCenter.mapToItem(window.contentItem, addCenter.width/2, addCenter.height/2)
   compare(addCenterAfter.y, addCenterPoint.y, "center plus stays at the same screen position")
   mouseClick(window.contentItem, addCenterPoint.x, addCenterPoint.y, Qt.LeftButton)
   wait(80)
   compare(center.count, 3, "repeated center click at the same coordinate adds another slot")
   verify(center.get(2).extra)
   addBottom = findObject(rail, "vertical-slot-add-cell-2")
   var addBottomPoint = addBottom.mapToItem(window.contentItem, addBottom.width/2, addBottom.height/2)
   clickCenter(addBottom)
   wait(80)
   compare(right.count, 8, "right-region click adds one extra slot")
   verify(right.get(7).extra)
   verify(addBottom && addBottom.visible, "bottom plus persists after first add")
   var addBottomAfter = addBottom.mapToItem(window.contentItem, addBottom.width/2, addBottom.height/2)
   compare(addBottomAfter.y, addBottomPoint.y, "bottom plus stays at the same screen position")
   mouseClick(window.contentItem, addBottomPoint.x, addBottomPoint.y, Qt.LeftButton)
   wait(80)
   compare(right.count, 9, "repeated bottom click at the same coordinate adds another slot")
   verify(right.get(8).extra)
   verify(rail.regionColumns[0].y + rail.regionColumns[0].implicitHeight + 12 <= rail.regionColumns[1].y,
       "top extras must not overlap the center region")
   verify(rail.regionColumns[1].y + rail.regionColumns[1].implicitHeight + 12 <= rail.regionColumns[2].y,
       "center extras must not overlap the bottom region")
   var removeLeft = findObject(rail, "vertical-slot-remove-action-0-11")
   var removeCenter = findObject(rail, "vertical-slot-remove-action-1-2")
   var removeRight = findObject(rail, "vertical-slot-remove-action-2-8")
   verify(removeLeft && removeLeft.enabled && removeLeft.visible)
   verify(removeCenter && removeCenter.enabled && removeCenter.visible)
   verify(removeRight && removeRight.enabled && removeRight.visible)
   clickCenter(removeLeft)
   wait(80)
   compare(left.count, 11, "left-region click removes the last empty extra slot")
   removeLeft = findObject(rail, "vertical-slot-remove-action-0-10")
   verify(removeLeft && removeLeft.enabled && removeLeft.visible)
   clickCenter(removeLeft)
   wait(80)
   compare(left.count, 10, "left-region click removes the remaining empty extra slot")
   removeCenter = findObject(rail, "vertical-slot-remove-action-1-2")
   verify(removeCenter && removeCenter.enabled && removeCenter.visible)
   clickCenter(removeCenter)
   wait(80)
   compare(center.count, 2, "center-region click removes one empty extra slot")
   removeCenter = findObject(rail, "vertical-slot-remove-action-1-1")
   verify(removeCenter && removeCenter.enabled && removeCenter.visible)
   clickCenter(removeCenter)
   wait(80)
   compare(center.count, 1, "center-region click removes the remaining empty extra slot")
   removeRight = findObject(rail, "vertical-slot-remove-action-2-8")
   verify(removeRight && removeRight.enabled && removeRight.visible)
   clickCenter(removeRight)
   wait(80)
   compare(right.count, 8, "right-region click removes one empty extra slot")
   removeRight = findObject(rail, "vertical-slot-remove-action-2-7")
   verify(removeRight && removeRight.enabled && removeRight.visible)
   clickCenter(removeRight)
   wait(80)
   compare(right.count, 7, "right-region click removes the remaining empty extra slot")
   while (left.count < 20) left.append({gid:"", extra:true})
   while (center.count < 8) center.append({gid:"", extra:true})
   while (right.count < 20) right.append({gid:"", extra:true})
   wait(100)
   verify(scrollView.contentHeight > scrollView.height, "fixture must overflow to exercise wheel/drag competition")
   var sourceSlot = findSlot(0, 0)
   var targetSlot = findSlot(2, 0)
   verify(sourceSlot && targetSlot, "drag source and target cells must exist")
   var from = sourceSlot.mapToItem(window.contentItem, sourceSlot.width/2, sourceSlot.height/2)
   var to = targetSlot.mapToItem(window.contentItem, targetSlot.width/2, targetSlot.height/2)
   var savesBefore = barSlot.orderSaveCalls
   rail.testDelegateAdded=0; rail.testDelegateRemoved=0
   mousePress(window.contentItem, from.x, from.y, Qt.LeftButton)
   verify(barSlot.dragging && barSlot.dragActive, "vertical press must enter the horizontal BarSlot drag lifecycle")
   var contentYBeforeDragWheel = scrollView.contentY
   mouseWheel(window.contentItem, from.x, from.y, 0, -120, Qt.NoButton, Qt.NoModifier)
   compare(scrollView.contentY, contentYBeforeDragWheel, "wheel input must not scroll slots beneath an active drag")
   compare(barSlot.srcModel, left, "drag source keeps model identity")
   compare(barSlot.srcIndex, 0)
   mouseMove(window.contentItem, to.x, to.y, 150)
   compare(barSlot.dropModel, right, "vertical hit testing resolves the destination model")
   compare(barSlot.dropIndex, 0)
   compare(barSlot.orderSaveCalls, savesBefore, "pointer movement must not persist before release")
   mouseRelease(window.contentItem, to.x, to.y, Qt.LeftButton)
   wait(100)
   console.log("SLOT_DELEGATE_CHURN V2 added="+rail.testDelegateAdded+" removed="+rail.testDelegateRemoved)
   compare(rail.testDelegateAdded,0,"a widget swap must preserve unrelated vertical delegates")
   compare(rail.testDelegateRemoved,0,"a widget swap must not recreate every Instantiator delegate")
   compare(left.get(0).gid, "G6", "vertical drag swaps the source widget out")
   compare(right.get(0).gid, "G1", "vertical drag moves the widget into the target")
   compare(barSlot.orderSaveCalls, savesBefore + 1, "successful vertical swap persists through BarSlot")
   verify(!barSlot.dragActive && !harness.state.trayDragActive && !harness.state.trayDropActive,
       "release clears drag and tray-highlight state")
   var idleWheelStart = scrollView.contentY
   mouseWheel(window.contentItem, from.x, from.y, 0, -120, Qt.NoButton, Qt.NoModifier)
   verify(scrollView.contentY > idleWheelStart, "wheel scrolling remains available when no drag is active")
   scrollView.contentY = 0
   wait(40)
   harness.state.barPosition = "right"
   wait(40)
   compare(lifecycleProbeLoader.x, 760, "V2 fixture places the rail on the right edge for invalid-drop hit testing")
   var emptyTarget = findSlot(0, 4)
   var restoredSource = findSlot(2, 0)
   verify(emptyTarget && restoredSource, "empty base slots remain draggable destinations")
   var emptyPoint = emptyTarget.mapToItem(window.contentItem, emptyTarget.width/2, emptyTarget.height/2)
   var restoredPoint = restoredSource.mapToItem(window.contentItem, restoredSource.width/2, restoredSource.height/2)
   mousePress(window.contentItem, restoredPoint.x, restoredPoint.y, Qt.LeftButton)
   mouseMove(window.contentItem, emptyPoint.x, emptyPoint.y, 150)
   var emptyHighlight = findObject(emptyTarget, "vertical-drop-target-0-4")
   verify(emptyHighlight && emptyHighlight.visible, "drop target highlight follows an empty vertical slot")
   compare(barSlot.orderSaveCalls, savesBefore + 1, "pointer move must not persist before release")
   compare(barSlot.dropModel, left)
   compare(barSlot.dropIndex, 4)
   mouseRelease(window.contentItem, emptyPoint.x, emptyPoint.y, Qt.LeftButton)
   wait(100)
   compare(left.get(4).gid, "G1", "drop into empty base slot preserves empty-target semantics")
   compare(right.get(0).gid, "", "source slot is cleared when moved into an empty destination")
   compare(barSlot.orderSaveCalls, savesBefore + 2, "empty-target move persists through BarSlot")
   var outsideSource = findSlot(0, 0)
   var outsidePoint = outsideSource.mapToItem(window.contentItem, outsideSource.width/2, outsideSource.height/2)
   var unchangedLeft = left.get(0).gid, unchangedEmpty = left.get(1).gid
   mousePress(window.contentItem, outsidePoint.x, outsidePoint.y, Qt.LeftButton)
   verify(barSlot.dragActive)
   mouseMove(window.contentItem, 400, 1200, 150)
   verify(!barSlot.dropModel && !barSlot.dropTray, "drop outside the rail and tray has no destination")
   mouseRelease(window.contentItem, 400, 1200, Qt.LeftButton)
   wait(300)
   compare(left.get(0).gid, unchangedLeft, "invalid drop leaves source order unchanged")
   compare(left.get(1).gid, unchangedEmpty, "invalid drop leaves target order unchanged")
   verify(!barSlot.dragging && !barSlot.dragActive, "invalid drop eventually clears the ghost")
   verify(!harness.state.trayDragActive && !harness.state.trayDropActive)
   harness.state.barPosition = "left"
   wait(40)
   var traySource = findSlot(0, 0)
   var traySourcePoint = traySource.mapToItem(window.contentItem, traySource.width/2, traySource.height/2)
   var trayPoint = barSlot.mapToGlobal(500, 1050)
   var trayLocalPoint = window.contentItem.mapFromGlobal(trayPoint.x, trayPoint.y)
   harness.state.trayVisible = true
   harness.state.setTrayDropRect("fixture", {x:trayPoint.x-20, y:trayPoint.y-20, width:40, height:40})
   mousePress(window.contentItem, traySourcePoint.x, traySourcePoint.y, Qt.LeftButton)
   mouseMove(window.contentItem, trayLocalPoint.x, trayLocalPoint.y, 150)
   verify(barSlot.dropTray && harness.state.trayDropActive, "global tray rectangle is recognized as a drop target")
   mouseRelease(window.contentItem, trayLocalPoint.x, trayLocalPoint.y, Qt.LeftButton)
   wait(100)
   compare(left.get(0).gid, "", "tray drop empties the source slot")
   compare(harness.state.trayWidgets.length, 1)
   compare(harness.state.trayWidgets[0], "G6")
   compare(barSlot.orderSaveCalls, savesBefore + 3, "tray move persists through BarSlot")
   verify(!harness.state.trayDragActive && !harness.state.trayDropActive)
   verify(barSlot.restoreTrayWidget("G6"), "tray restore uses the production BarSlot helper")
   compare(left.get(0).gid, "G6", "tray restore fills the first available slot")
   compare(harness.state.trayWidgets.length, 0, "tray restore removes the widget from the tray list")
   compare(barSlot.orderSaveCalls, savesBefore + 4, "tray restore persists through BarSlot")
   var lockSource = findSlot(0, 0)
   var lockTarget = findSlot(2, 0)
   var lockStart = lockSource.mapToItem(window.contentItem, lockSource.width/2, lockSource.height/2)
   var lockEnd = lockTarget.mapToItem(window.contentItem, lockTarget.width/2, lockTarget.height/2)
   var lockedLeft = left.get(0).gid, lockedRight = right.get(0).gid
   mousePress(window.contentItem, lockStart.x, lockStart.y, Qt.LeftButton)
   mouseMove(window.contentItem, lockEnd.x, lockEnd.y, 100)
   harness.state.barUnlocked = false
   wait(40)
   verify(!barSlot.dragActive && !barSlot.dragging, "locking cancels the active vertical drag immediately")
   verify(!harness.state.trayDragActive && !harness.state.trayDropActive)
   compare(left.get(0).gid, lockedLeft, "lock cancellation does not mutate source")
   compare(right.get(0).gid, lockedRight, "lock cancellation does not mutate target")
   mouseRelease(window.contentItem, lockEnd.x, lockEnd.y, Qt.LeftButton)
   var backdropPoint = rail.mapToItem(window.contentItem, 0.25, 100)
   mouseClick(window.contentItem, backdropPoint.x, backdropPoint.y)
   wait(80)
   verify(!harness.state.barUnlocked, "empty rail edge still relocks through the dim backdrop")
   harness.state.layoutProtected = true
   mouseClick(window.contentItem, unlockPoint.x, unlockPoint.y, Qt.LeftButton, Qt.NoModifier, 0)
   mouseClick(window.contentItem, unlockPoint.x, unlockPoint.y, Qt.LeftButton, Qt.NoModifier, 0)
   wait(100)
   verify(!harness.state.barUnlocked, "layout protection must block edit unlock")
   harness.state.layoutProtected = false
   left.setProperty(10, "gid", "G24")
   harness.state.barUnlocked = true
   wait(100)
   var hiddenSource = findSlot(0, 10)
   verify(hiddenSource && hiddenSource.height > 0, "disabled assigned widgets still occupy a movable edit slot")
   var hiddenSurface = findObject(hiddenSource, "vertical-module-surface")
   verify(hiddenSurface && hiddenSurface.visible, "an enabled widget has its configured surface")
   hiddenSource.contentItem.moduleEnabled = false
   wait(80)
   verify(hiddenSurface && !hiddenSurface.visible, "a widget disabled after loading must not leave its per-widget color painted on an empty slot")
   var disabledPlaceholder = findObject(hiddenSource, "vertical-disabled-module-placeholder-0-10")
   verify(disabledPlaceholder && disabledPlaceholder.visible, "disabled assigned widgets must have a neutral identity placeholder")
   var hiddenTarget = findSlot(0, 5)
   verify(hiddenTarget && hiddenTarget.emptySlot, "fixture has an empty target for the disabled widget")
   var hiddenStart = hiddenSource.mapToItem(window.contentItem, hiddenSource.width/2, hiddenSource.height/2)
   var hiddenEnd = hiddenTarget.mapToItem(window.contentItem, hiddenTarget.width/2, hiddenTarget.height/2)
   var hiddenSaves = barSlot.orderSaveCalls
   mousePress(window.contentItem, hiddenStart.x, hiddenStart.y, Qt.LeftButton)
   verify(barSlot.dragActive, "disabled assigned widgets must start a drag in edit mode")
   mouseMove(window.contentItem, hiddenEnd.x, hiddenEnd.y, 100)
   compare(barSlot.dropModel, left)
   compare(barSlot.dropIndex, 5)
   mouseRelease(window.contentItem, hiddenEnd.x, hiddenEnd.y, Qt.LeftButton)
   wait(80)
   compare(left.get(10).gid, "", "disabled widget leaves its original slot")
   compare(left.get(5).gid, "G24", "disabled widget can be moved into an empty slot")
   compare(barSlot.orderSaveCalls, hiddenSaves + 1, "disabled widget reorder persists through BarSlot")
   harness.state.barUnlocked = false
  }
 }
}'''
    qml = base / "tst_v2_vertical_slots.qml"
    qml.write_text(fixture)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen",
               QT_QUICK_BACKEND="software", QT_QPA_PLATFORMTHEME="")
    env.pop("WAYLAND_DISPLAY", None)
    env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(qml)],
                            env=env, text=True, capture_output=True, timeout=30)
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode:
        raise SystemExit(result.returncode)
    if "V2VerticalSlotPointer::test_add_remove_and_move_by_pointer()" not in output:
        raise SystemExit("QtTest did not execute the vertical slot pointer test")
