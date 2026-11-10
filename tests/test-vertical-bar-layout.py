#!/usr/bin/env python3
"""Exercise the real vertical layout and side-panel bindings with inert widget boundaries."""
from qml_fixture_source import copy_qml_fixture, write_hyprland_stub
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import re

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rv-', dir=os.environ.get('TMPDIR')) as directory:
    base = Path(directory)
    (base / 'runtime').mkdir(mode=0o700)
    for name in ['SidePanelPositioner.qml', 'AiPanelSurface.qml', 'WorkspaceWidget.qml']:
        copy_qml_fixture(repo / 'variants/V2/modules' / name, base)
    vertical_path = Path(os.environ.get(
        'RISE_VERTICAL_CONTENT_SOURCE', str(repo / 'variants/V2/modules/VerticalBarContent.qml')))
    vertical_source = vertical_path.read_text()
    vertical_source = vertical_source.replace(
        'import "../../../shared/components" as CommonComponents', 'import "."')
    vertical_source = vertical_source.replace('CommonComponents.', '')
    vertical_source = vertical_source.replace(
        'objectName: "vertical-module-surface"',
        'objectName: "vertical-module-surface"\n                            Text { anchors.centerIn: parent; text: cell.gid; color: "#eeeeee"; font.pixelSize: 8; visible: cell.gid !== "" }')
    vertical_source = vertical_source.replace(
        'import "../../../shared/logic/VerticalBarContentValuesLogic.js" as VerticalBarContentValuesLogic',
        'import "VerticalBarContentValuesLogic.js" as VerticalBarContentValuesLogic')
    vertical_source = vertical_source.replace(
        'import "../../../shared/logic/VerticalBarContentLogic.js" as VerticalBarContentLogic',
        'import "VerticalBarContentLogic.js" as VerticalBarContentLogic')
    (base / 'VerticalBarContent.qml').write_text(vertical_source)
    copy_qml_fixture(repo / 'shared/logic/VerticalBarContentValuesLogic.js', base)
    copy_qml_fixture(repo / 'shared/logic/VerticalBarContentLogic.js', base)
    copy_qml_fixture(repo / 'shared/logic/MonitorWorkspaces.js', base)
    for module_name in ['VerticalBarContent.qml', 'WorkspaceWidget.qml']:
        module_path = base / module_name
        module_path.write_text(module_path.read_text().replace(
            'import Quickshell.Hyprland', 'import "."'))
    workspace_source = base / 'WorkspaceWidget.qml'
    workspace_source.write_text(workspace_source.read_text().replace(
        'import "../../../shared/logic/MonitorWorkspaces.js" as MonitorWorkspaces',
        'import "MonitorWorkspaces.js" as MonitorWorkspaces'))
    for name in ['IndicatorsWidget.qml', 'UiText.qml', 'TooltipMixin.qml']:
        copy_qml_fixture(repo / 'shared/components' / name, base)
    for name in ['ArchUpdaterWidget', 'TrayWidget', 'NotificationWidget', 'IdleInhibitorWidget', 'MediaBrowserWidget', 'ThemeDisplayWidget']:
        (base / (name + '.qml')).write_text('import QtQuick\nItem { property var root; property var screen; implicitWidth: 30; implicitHeight: 28 }\n')
    (base / 'WeatherWidget.qml').write_text('import QtQuick\nItem { property var root; property bool weatherLoaded: true; property string weatherTempStr: "25°C"; implicitWidth: 32; implicitHeight: 28 }\n')
    write_hyprland_stub(base)
    (base / 'shell.qml').write_text('''import QtQuick
import QtQuick.Window
import Quickshell
ShellRoot {
 id: harness
 property bool lifecycleProbeEnabled: false
 property var lifecycleProbeFirst: null
 property bool capturedUnlocked: false
 property var lifecycleProbeOwner: lifecycleOwner
 property var lifecycleProbeModels: [left, center, right]
 property var lifecycleProbeRegistry: ({G1:widget,G5:widget,G6:widget})
 property QtObject state: QtObject {
  property string barPosition: "left"
  property bool barVertical: barPosition === "left" || barPosition === "right"
  property string barShellStyle: "full"
  property int verticalBarWidth: barShellStyle === "fit" ? 40 : 36
  property bool barUnlocked: false
  property bool layoutProtected: false
  property bool modStatus: true
  property bool modQuick: true
  property bool modWeather: true
  property bool modIndicators: true
  property bool clock12h: false
  property var omarchyIndicators: null
  property var tooltipOwner: null
  property string tooltipText: ""
  function showTooltip(text, x, y, bottom, owner) {}
  function hideTooltip(owner) {}
  property color bg: Qt.rgba(0.1, 0.1, 0.1, 0.98)
  property int panelRadius: 6
  property int panelOuterBorderW: 1
  property color panelOuterBorderColor: "#777777"
  property color barBg: "#222222"
  property color islandBorder: "#555555"
  property color v2BarBorder: "#777777"
  property color ink: "#eeeeee"
  property color seal: "#ff8800"
  property color sep: "#777777"
  property color sumi: "#cccccc"
  property color fillIdle: "#333333"
  property color fillHover: "#444444"
  property color fillActive: "#555555"
  property int tileRadius: 6
  property string mono: "monospace"
  property string workspaceMode: "10"
  property string workspaceStyle: "numbers"
  property int panelButtonRadius: 6
  function widgetContentColor(gid, fallback) { return fallback }
  function gotoWorkspace(id) {}
  property bool barBorderEnabled: true
  property var anchorsByName: ({})
  property var verticalAnchorsByScreen: ({})
  property var trayWidgets: []
  property var trayDropRectsByScreen: ({})
  property bool trayVisible: false
  property bool trayDragActive: false
  property bool trayDropActive: false
  property string activePopupScreenName: "fixture"
  property real panelInsetReveal: 0
  property bool cpuVisible: false
  property bool controlVisible: false
  property bool workspaceVisible: false
  property bool calendarVisible: false
  property bool oneDriveVisible: false
  property bool oneDriveAnchorTest: false
  property real oneDriveAnchorTestY: 20
  function sepAfter(gid) { return gid === "G5" }
  function widgetSurfacePadding(gid) { return 0 }
  property int verticalModuleSurfaceWidth: Math.min(34, 24 + 2 * widgetSurfacePadding("G1"))
  function widgetSurfaceRadius(gid) { return 6 }
  function widgetFillColor(gid) { return "transparent" }
  function widgetSurfaceStyle(gid) { return {opacity: 1, borderWidth: 1} }
  function widgetHasBorder(gid) { return false }
  function widgetBorderColor(gid) { return "#777777" }
  function publishVerticalAnchors(name, values) {
   if (name === "probe") { var next=Object.assign({},verticalAnchorsByScreen); next[name]=values; verticalAnchorsByScreen=next; return }
   anchorsByName = values
  }
  function publishBarAnchors(name, values) {}
  function verticalAnchorY(name) {
   if (name === "oneDrive") return oneDriveAnchorTestY
   return anchorsByName[name] === undefined ? 10 : anchorsByName[name]
  }
  function activatePopupScreen(screen) {}
  function setTrayDropRect(screenName, rect) { var next=Object.assign({},trayDropRectsByScreen); next[screenName]=rect; trayDropRectsByScreen=next }
  function removeTrayDropRect(screenName) { var next=Object.assign({},trayDropRectsByScreen); delete next[screenName]; trayDropRectsByScreen=next }
 }
 ListModel { id: left;
  ListElement {gid:"G1"; extra:false} ListElement {gid:"G2"; extra:false}
  ListElement {gid:"G3"; extra:false} ListElement {gid:"G5"; extra:false}
  ListElement {gid:""; extra:false} ListElement {gid:""; extra:false}
  ListElement {gid:""; extra:false} ListElement {gid:""; extra:false}
  ListElement {gid:""; extra:false} ListElement {gid:""; extra:false}
 }
 ListModel { id: center; ListElement {gid:"G8"; extra:false} }
 ListModel { id: right;
  ListElement {gid:"G6"; extra:false} ListElement {gid:"G10"; extra:false}
  ListElement {gid:""; extra:false} ListElement {gid:""; extra:false}
  ListElement {gid:""; extra:false} ListElement {gid:""; extra:false}
  ListElement {gid:""; extra:false}
 }
 QtObject {
  id: owner
  property string screenName: "fixture"
  property var screen: ({width:800, height:1400})
  property color accent: "#ff8800"
  property bool dragging: false
  property var dropModel: null
  property int dropIndex: -1
  property var srcModel: null
  property int srcIndex: -1
  property int leftBaseSlotCount: 10
  property int centerBaseSlotCount: 1
  property int rightBaseSlotCount: 7
  property int leftExtraSlotLimit: 10
  property int centerExtraSlotLimit: 7
  property int rightExtraSlotLimit: 13
  property var slotOperations: []
  function modelRegion(model) { return model === left ? 0 : model === center ? 1 : 2 }
  function addExtraSlot(model, baseCount, maxExtraCount) {
   var region = modelRegion(model)
   slotOperations = slotOperations.concat(["add:" + region])
   if (model.count - baseCount < maxExtraCount) model.append({gid:"", extra:true})
  }
  function removeExtraSlot(model, index, baseCount) {
   var region = modelRegion(model)
   slotOperations = slotOperations.concat(["remove:" + region + ":" + index])
   if (index >= baseCount && index < model.count && model.get(index).extra && model.get(index).gid === "") model.remove(index, 1)
  }
  function swapVerticalSlots(sr, si, tr, ti) {
   var models = [left, center, right]
   var a = models[sr].get(si).gid, b = models[tr].get(ti).gid
   models[sr].setProperty(si, "gid", b)
   models[tr].setProperty(ti, "gid", a)
  }
 }
 QtObject {
  id: lifecycleOwner
  property string screenName: "probe"
  property var screen: ({name:"probe",width:800,height:1400})
  property int leftBaseSlotCount: 10
  property int centerBaseSlotCount: 1
  property int rightBaseSlotCount: 7
  property int leftExtraSlotLimit: 10
  property int centerExtraSlotLimit: 7
  property int rightExtraSlotLimit: 13
  property bool dragging: false
  property bool dragActive: false
  property var srcModel: null
  property int srcIndex: -1
  property var dropModel: null
  property int dropIndex: -1
  property color accent: "#ff8800"
  function beginDrag(item, x, y, w, h, model, index) {}
  function moveDrag(x, y, globalX, globalY) {}
  function endDrag() {}
  function cancelDrag() {}
  function addExtraSlot(model, baseCount, limit) { if (model.count-baseCount<limit) model.append({gid:"",extra:true}) }
  function removeExtraSlot(model, index, baseCount) { if (index>=baseCount && index<model.count && model.get(index).gid==="") model.remove(index,1) }
 }
 Component { id: widget; Item { implicitWidth:32; implicitHeight:28 } }
 Window {
  id: window
  visible:true; width:800; height:1400; color:"white"
  VerticalBarContent { id: rail; width:harness.state.verticalBarWidth; height:1400; root:harness.state; barWindow:owner; models:[left,center,right]; registry:({G1:widget,G5:widget,G6:widget}) }
  Rectangle {
   id: card; x:200; y:100; width:280; height:200; color:"transparent"
   AiPanelSurface { id: connectedSurface; root:harness.state; targetX:0; reveal:1 }
   SidePanelPositioner { root:harness.state; target:card; anchorName:harness.state.oneDriveAnchorTest ? "oneDrive" : "cpu" }
  }
 }
 Loader {
  id: lifecycleProbeLoader
  parent: window.contentItem
  x: 820; y: 0; width: harness.state.verticalBarWidth; height: window.height
  active: harness.lifecycleProbeEnabled && harness.state.barVertical
  sourceComponent: Component {
   VerticalBarContent {
    width: harness.state.verticalBarWidth; height: window.height
    root: harness.state; barWindow: harness.lifecycleProbeOwner
    models: harness.lifecycleProbeModels
    registry: harness.lifecycleProbeRegistry
   }
  }
 }
 property int step:0
 property bool captured:false
 Timer { interval:100; repeat:true; running:true; onTriggered: {
  function check(ok, message) { if (!ok) { console.error(message); Qt.exit(1) } }
  function findObject(item, name) {
   if (item.objectName === name) return item
   for (var n=0; n<item.children.length; n++) {
    var found = findObject(item.children[n], name)
    if (found) return found
   }
   return null
  }
  function assertVisualIdentity(label, requireUniqueGids) {
   var expected = {}, expectedGids = {}, actual = {}, actualGids = {}
   var models = [left, center, right]
   for (var r = 0; r < models.length; r++) {
    for (var i = 0; i < models[r].count; i++) {
     var gid = String(models[r].get(i).gid || "")
     if (!gid && !harness.state.barUnlocked) continue
     var key = r + ":" + i
     expected[key] = gid
     if (gid) expectedGids[gid] = (expectedGids[gid] || 0) + 1
    }
   }
   var columns = rail.regionBaseColumns.concat(rail.regionExtraColumns)
   for (var c = 0; c < columns.length; c++) {
    var children = columns[c].children
    for (var n = 0; n < children.length; n++) {
     var cell = children[n]
     if (!cell || cell.modelData === undefined || cell.gid === undefined) continue
     var key = cell.modelData.region + ":" + cell.modelData.index
     var gid = String(cell.gid || "")
     actual[key] = (actual[key] || 0) + 1
     if (gid) actualGids[gid] = (actualGids[gid] || 0) + 1
    }
   }
   check(Object.keys(actual).length === Object.keys(expected).length,
    "VISUAL_SLOT_CARDINALITY_" + label + "_" + Object.keys(actual).length + "_vs_" + Object.keys(expected).length)
   for (var key in expected) check(actual[key] === 1, "VISUAL_SLOT_MISSING_OR_DUPLICATED_" + label + "_" + key + "_" + actual[key])
   for (var key in actual) check(expected[key] !== undefined, "ORPHAN_VISUAL_SLOT_" + label + "_" + key)
   for (var gid in expectedGids) {
    check(actualGids[gid] === expectedGids[gid], "VISUAL_GID_COUNT_MISMATCH_" + label + "_" + gid)
    if (requireUniqueGids) check(expectedGids[gid] === 1, "MODEL_GID_DUPLICATE_" + label + "_" + gid)
   }
  }
  function assertLifecycleIdentity(label) {
   var item = lifecycleProbeLoader.item
   if (!item) return
   var expected = {}, actual = {}, models = [left, center, right]
   for (var r=0; r<models.length; r++) {
    for (var i=0; i<models[r].count; i++) {
     var gid=String(models[r].get(i).gid || "")
     if (!gid && !harness.state.barUnlocked) continue
     expected[r+":"+i]=gid
    }
   }
   var columns=item.regionBaseColumns.concat(item.regionExtraColumns)
   for (var c=0; c<columns.length; c++) {
    var children=columns[c].children
    for (var n=0; n<children.length; n++) {
     var cell=children[n]
     if (!cell || cell.modelData===undefined || cell.gid===undefined) continue
     var key=cell.modelData.region+":"+cell.modelData.index
     actual[key]=(actual[key] || 0)+1
     check(String(cell.gid || "")===expected[key],"PROBE_GID_MISMATCH_"+label+"_"+key)
    }
   }
   check(Object.keys(actual).length===Object.keys(expected).length,
    "PROBE_SLOT_CARDINALITY_"+label+"_"+Object.keys(actual).length+"_vs_"+Object.keys(expected).length)
   for (var key in expected) check(actual[key]===1,"PROBE_SLOT_MISSING_OR_DUPLICATED_"+label+"_"+key+"_"+actual[key])
   for (var key in actual) check(expected[key]!==undefined,"PROBE_ORPHAN_SLOT_"+label+"_"+key)
  }
  assertVisualIdentity("step-" + harness.step, harness.step !== 19)
  assertLifecycleIdentity("step-" + harness.step)
  if (harness.step === 0) {
   var cells = rail.layoutSnapshot().sort(function(a,b) { return a.y - b.y })
   var moduleSurfaces = []
   function findModuleSurfaces(item) {
    if (item.objectName === "vertical-module-surface") moduleSurfaces.push(item)
    for (var n=0; n<item.children.length; n++) findModuleSurfaces(item.children[n])
   }
   findModuleSurfaces(rail)
   check(moduleSurfaces.length === cells.length, "VERTICAL_MODULE_SURFACE_COUNT")
   for (var m=0; m<moduleSurfaces.length; m++) {
    check(Math.abs(moduleSurfaces[m].width - harness.state.verticalModuleSurfaceWidth) < 0.01, "VERTICAL_MODULE_SURFACE_WIDTH_" + moduleSurfaces[m].width)
    check(Math.abs(moduleSurfaces[m].x + moduleSurfaces[m].width / 2 - moduleSurfaces[m].parent.width / 2) < 0.51, "VERTICAL_MODULE_SURFACE_CENTER")
   }
   for (var i = 1; i < cells.length; i++)
    check(cells[i].y >= cells[i-1].y + cells[i-1].height, "OVERLAPPING_SLOTS_" + cells[i-1].gid + "_" + cells[i].gid)
   var workspace = cells.filter(function(cell) { return cell.gid === "G2" })[0]
   check(workspace && workspace.height === 258, "REAL_WORKSPACE_GEOMETRY")
   check(card.x === 42, "LEFT_PANEL_POSITION")
   check(harness.state.anchorsByName.cpu > 0, "MISSING_WIDGET_ANCHOR")
   check(rail.surfaceHeight === 1400, "FULL_HEIGHT")
   var centerCell = cells.filter(function(cell) { return cell.gid === "G8" })[0]
   check(Math.abs(centerCell.y + centerCell.height / 2 - 697) <= 1, "CENTER_REGION_NOT_CENTERED")
   check(harness.state.anchorsByName.weather < harness.state.anchorsByName.calendar, "WEATHER_AND_CLOCK_ANCHORS")
   check(harness.state.anchorsByName.volume > 1000, "RIGHT_REGION_NOT_AT_BOTTOM")
   check(harness.state.anchorsByName.cpu < 600, "LEFT_REGION_NOT_AT_TOP")
   console.log("PANEL_SAMPLE", card.x + 20, card.y + 20)
   rail.grabToImage(function(result) { result.saveToFile("INITIAL_CAPTURE") })
   window.contentItem.grabToImage(function(result) {
    result.saveToFile("PANEL_CAPTURE")
    harness.state.barShellStyle = "fit"
    harness.state.barPosition = "right"
    harness.captured = true
   })
   harness.lifecycleProbeEnabled = true
  } else if (harness.step === 1) {
   if (!harness.captured || !lifecycleProbeLoader.item) return
   harness.lifecycleProbeFirst = lifecycleProbeLoader.item
   check(card.x === 474, "RIGHT_PANEL_POSITION")
   check(rail.surfaceHeight < 1400 && rail.surfaceY > 0, "FIT_GEOMETRY")
   check(card.y >= 6 && card.y + card.height <= 1394, "PANEL_CLAMP")
   owner.swapVerticalSlots(0,3,2,0)
  } else if (harness.step === 2) {
   check(left.get(3).gid === "G6" && right.get(0).gid === "G5", "ORDER_SWAP")
   check(harness.state.anchorsByName.cpu > harness.state.anchorsByName.calendar, "STALE_ANCHOR_AFTER_SWAP")
   harness.state.workspaceMode = "5"
  } else if (harness.step === 3 || harness.step === 4) {
   var resized = rail.layoutSnapshot().sort(function(a,b) { return a.y - b.y })
   for (var i = 1; i < resized.length; i++)
    check(resized[i].y >= resized[i-1].y + resized[i-1].height, "OVERLAP_AFTER_WORKSPACE_RESIZE")
   check(resized.filter(function(cell) { return cell.gid === "G2" })[0].height === 128, "WORKSPACE_RESIZE_NOT_APPLIED")
   if (harness.step === 3) rail.height = 300
   else harness.state.barVertical = false
  } else if (harness.step === 5) {
   check(!lifecycleProbeLoader.item, "VERTICAL_LOADER_REMAINS_ACTIVE_IN_HORIZONTAL_ORIENTATION")
   harness.state.barVertical = true
   harness.state.barShellStyle = "dock"
   harness.state.clock12h = true
  } else if (harness.step === 6) {
   check(rail.width === 36 && card.x === 478, "DOCK_WIDTH_AND_PANEL")
   check(lifecycleProbeLoader.item && lifecycleProbeLoader.item !== harness.lifecycleProbeFirst,
    "VERTICAL_LOADER_DID_NOT_RECREATE_AFTER_ORIENTATION_SWITCH")
   harness.lifecycleProbeFirst = lifecycleProbeLoader.item
   var clockCell = rail.layoutSnapshot().filter(function(cell) { return cell.gid === "G8" })[0]
   check(clockCell.height === 64, "TWELVE_HOUR_CLOCK_HEIGHT")
   harness.state.barShellStyle = "notch"
   harness.state.barPosition = "left"
  } else if (harness.step === 7) {
   check(rail.width === 36 && card.x === 42, "NOTCH_WIDTH_AND_PANEL")
   function findBorder(item) {
    if (item.objectName === "vertical-notch-border") return item
    for (var n=0; n<item.children.length; n++) { var found = findBorder(item.children[n]); if (found) return found }
    return null
   }
   var border = findBorder(rail)
   check(border && border.visible && border.z === 3, "NOTCH_BORDER_FOREGROUND")
   harness.state.barBorderEnabled = false
   check(!border.visible, "NOTCH_BORDER_OFF")
   harness.state.barBorderEnabled = true
   check(border.visible, "NOTCH_BORDER_ON")
   check(rail.surfaceY >= 0 && rail.surfaceY + rail.surfaceHeight <= rail.height, "NOTCH_INPUT_BOUNDS")
   harness.state.cpuVisible = true
   harness.state.panelInsetReveal = 1
  } else if (harness.step === 8) {
   check(rail.panelNotchProgress === 1, "NOTCH_REVEAL_LEFT")
   check(rail.panelNotchY === harness.state.anchorsByName.cpu, "NOTCH_PANEL_ANCHOR")
   harness.state.barPosition = "right"
  } else if (harness.step === 9) {
   check(rail.panelNotchProgress === 1, "NOTCH_REVEAL_RIGHT")
   harness.state.activePopupScreenName = "other"
  } else if (harness.step === 10) {
   check(rail.panelNotchProgress === 0, "NOTCH_WRONG_MONITOR")
   harness.state.activePopupScreenName = "fixture"
   harness.state.cpuVisible = false
   harness.state.panelInsetReveal = 0
   harness.state.barVertical = false
  } else if (harness.step === 11) {
   check(card.x === 200 && card.y === 100, "HORIZONTAL_BINDING_RESTORE")
   harness.state.barShellStyle = "full"
   harness.state.barPosition = "left"
   harness.state.barVertical = true
   harness.state.oneDriveAnchorTest = true
   harness.state.oneDriveVisible = true
   harness.state.oneDriveAnchorTestY = 20
  } else if (harness.step === 12) {
   check(Math.abs(card.y - 6) < 0.01, "ONEDRIVE_PANEL_CLAMP_TOP")
   check(Math.abs(connectedSurface.sideTargetY - (harness.state.verticalAnchorY("oneDrive") - card.y)) < 0.5,
    "ONEDRIVE_VERTICAL_CARET_TOP_ALIGNMENT_" + connectedSurface.sideTargetY)
   harness.state.barPosition = "right"
   harness.state.oneDriveAnchorTestY = 1380
  } else if (harness.step === 13) {
   check(Math.abs(card.y - 1194) < 0.01, "ONEDRIVE_PANEL_CLAMP_BOTTOM")
   check(Math.abs(connectedSurface.sideTargetY - (harness.state.verticalAnchorY("oneDrive") - card.y)) < 0.5,
    "ONEDRIVE_VERTICAL_CARET_BOTTOM_ALIGNMENT_" + connectedSurface.sideTargetY)
   console.log("ONEDRIVE_VERTICAL_CARET_PASS")
  } else if (harness.step === 14) {
   check(card.x === 478 && card.y === 1194, "ONEDRIVE_PANEL_FINAL_GEOMETRY")
   var lockedAdd = findObject(rail, "vertical-slot-add-cell-0")
   check(lockedAdd && !lockedAdd.visible, "VERTICAL_ADD_CONTROL_VISIBLE_WHILE_LOCKED")
   harness.state.barPosition = "left"
   harness.state.barVertical = true
   harness.state.barUnlocked = true
  } else if (harness.step === 15) {
   var addTop = findObject(rail, "vertical-slot-add-cell-0")
   check(addTop, "VERTICAL_ADD_CONTROL_TOP_MISSING")
   addTop.activate()
   check(left.count === 11 && left.get(10).extra && left.get(10).gid === "", "VERTICAL_ADD_TOP_SLOT")
  } else if (harness.step === 16) {
   var addCenter = findObject(rail, "vertical-slot-add-cell-1")
   check(addCenter, "VERTICAL_ADD_CONTROL_CENTER_MISSING")
   addCenter.activate()
   check(center.count === 2 && center.get(1).extra && center.get(1).gid === "", "VERTICAL_ADD_CENTER_SLOT")
  } else if (harness.step === 17) {
   var addBottom = findObject(rail, "vertical-slot-add-cell-2")
   check(addBottom, "VERTICAL_ADD_CONTROL_BOTTOM_MISSING")
   addBottom.activate()
   check(right.count === 8 && right.get(7).extra && right.get(7).gid === "", "VERTICAL_ADD_BOTTOM_SLOT")
  } else if (harness.step === 18) {
   left.setProperty(10, "gid", "G5")
  } else if (harness.step === 19) {
   check(!findObject(rail, "vertical-empty-slot-0-10"), "FILLED_EXTRA_SLOT_IS_NOT_REMOVABLE")
   left.setProperty(10, "gid", "")
  } else if (harness.step === 20) {
   var removeTop = findObject(rail, "vertical-empty-slot-0-10")
   check(removeTop, "VERTICAL_REMOVE_CONTROL_TOP_MISSING")
   removeTop.activate()
   check(left.count === 10, "VERTICAL_REMOVE_TOP_SLOT")
  } else if (harness.step === 21) {
   var removeCenter = findObject(rail, "vertical-empty-slot-1-1")
   check(removeCenter, "VERTICAL_REMOVE_CONTROL_CENTER_MISSING")
   removeCenter.activate()
   check(center.count === 1, "VERTICAL_REMOVE_CENTER_SLOT")
  } else if (harness.step === 22) {
   var removeBottom = findObject(rail, "vertical-empty-slot-2-7")
   check(removeBottom, "VERTICAL_REMOVE_CONTROL_BOTTOM_MISSING")
   removeBottom.activate()
   check(right.count === 7, "VERTICAL_REMOVE_BOTTOM_SLOT")
  } else if (harness.step === 23) {
   for (var region = 0; region < 3; region++) {
    var limit = region === 0 ? owner.leftExtraSlotLimit : region === 1 ? owner.centerExtraSlotLimit : owner.rightExtraSlotLimit
    for (var i = 0; i < limit; i++) rail.addExtraSlot(region)
   }
  } else if (harness.step === 24) {
   var addTopAtCapacity = findObject(rail, "vertical-slot-add-cell-0")
   var addCenterAtCapacity = findObject(rail, "vertical-slot-add-cell-1")
   var addBottomAtCapacity = findObject(rail, "vertical-slot-add-cell-2")
   check(left.count === 20 && center.count === 8 && right.count === 20
    && addTopAtCapacity && !addTopAtCapacity.visible
    && addCenterAtCapacity && !addCenterAtCapacity.visible
    && addBottomAtCapacity && !addBottomAtCapacity.visible, "VERTICAL_ADD_CONTROLS_HIDDEN_AT_CAPACITY_" + [left.count,center.count,right.count] + "_" + [addTopAtCapacity && addTopAtCapacity.visible,addCenterAtCapacity && addCenterAtCapacity.visible,addBottomAtCapacity && addBottomAtCapacity.visible])
   check(owner.slotOperations.join(",").startsWith("add:0,add:1,add:2,remove:0:10,remove:1:1,remove:2:7"), "VERTICAL_SLOT_ACTION_ROUTING")
   console.log("VERTICAL_SLOT_EDIT_PASS")
   harness.state.barUnlocked=false
  } else if (harness.step === 25) {
   check(!harness.state.barUnlocked && left.count===20 && center.count===8 && right.count===20,
    "LOCK_MUST_PRESERVE_EMPTY_SLOT_MODELS")
   harness.state.barUnlocked=true
  } else if (harness.step === 26) {
   check(harness.state.barUnlocked && left.count===20 && center.count===8 && right.count===20,
    "UNLOCK_MUST_RESTORE_INTENTIONAL_EMPTY_SLOTS")
   rail.grabToImage(function(result) {
    result.saveToFile("UNLOCKED_CAPTURE")
    harness.capturedUnlocked=true
   })
   harness.lifecycleProbeEnabled=false
  } else if (harness.step === 27) {
   if (!harness.capturedUnlocked) return
   check(!lifecycleProbeLoader.item,"REBUILD_PROBE_DID_NOT_UNLOAD")
   harness.lifecycleProbeEnabled=true
  } else if (harness.step === 28) {
   check(lifecycleProbeLoader.item && lifecycleProbeLoader.item!==harness.lifecycleProbeFirst,
    "REBUILD_PROBE_DID_NOT_CREATE_A_FRESH_RAIL")
   console.log("VERTICAL_LOADER_REBUILD_PASS")
   console.log("VERTICAL_LAYOUT_PASS")
   Qt.quit()
  } else {
   check(false, "UNEXPECTED_TEST_STEP_" + harness.step)
  }
  harness.step++
 }}
}
'''.replace('PANEL_CAPTURE', str(base / 'panel.png')).replace(
    'INITIAL_CAPTURE', str(Path(os.environ.get(
        'RISE_VERTICAL_LAYOUT_INITIAL_CAPTURE', str(base / 'vertical-initial.png'))))).replace(
    'UNLOCKED_CAPTURE', str(Path(os.environ.get(
        'RISE_VERTICAL_LAYOUT_UNLOCKED_CAPTURE', str(base / 'vertical-unlocked.png'))))))
    env = dict(os.environ, XDG_RUNTIME_DIR=str(base / 'runtime'), QT_QPA_PLATFORM='offscreen',
               QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='')
    env.pop('WAYLAND_DISPLAY', None)
    env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
    try:
        result = subprocess.run(['qs', '-n', '-p', str(base / 'shell.qml')], env=env,
                                capture_output=True, text=True, timeout=15)
    except subprocess.TimeoutExpired as error:
        print((error.stdout or b'').decode(errors='replace'), end='')
        print((error.stderr or b'').decode(errors='replace'), end='')
        raise SystemExit('Vertical layout fixture timed out')
    output = result.stdout + result.stderr
    clean_output = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", output).replace("\r", "")
    print(output, end='')
    if result.returncode or 'VERTICAL_LAYOUT_PASS' not in clean_output or 'WARN scene:' in clean_output or 'ERROR qml:' in clean_output:
        raise SystemExit(result.returncode or 1)

    sample = re.search(r'PANEL_SAMPLE (\d+) (\d+)', output)
    if not sample:
        raise SystemExit('Missing panel opacity sample')
    color = subprocess.check_output(['magick', str(base / 'panel.png'), '-crop',
        f'1x1+{sample[1]}+{sample[2]}', '-depth', '8', 'rgb:-'])
    if len(color) != 3 or max(color) > 50:
        raise SystemExit(f'Panel background is too transparent: {tuple(color)}')
    print('PANEL_BACKGROUND_PASS')
