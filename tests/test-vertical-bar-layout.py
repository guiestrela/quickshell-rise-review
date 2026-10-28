#!/usr/bin/env python3
"""Exercise the real vertical layout and side-panel bindings with inert widget boundaries."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import re

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-vertical-', dir='/tmp') as directory:
    base = Path(directory)
    (base / 'runtime').mkdir(mode=0o700)
    for name in ['VerticalBarContent.qml', 'SidePanelPositioner.qml', 'AiPanelSurface.qml', 'WorkspaceWidget.qml']:
        shutil.copy2(repo / 'versions/V1/variants/V2/modules' / name, base)
    for name in ['ArchUpdaterWidget', 'TrayWidget', 'NotificationWidget', 'IdleInhibitorWidget', 'MediaBrowserWidget', 'ThemeDisplayWidget']:
        (base / (name + '.qml')).write_text('import QtQuick\nItem { property var root; property var screen; implicitWidth: 30; implicitHeight: 28 }\n')
    (base / 'WeatherWidget.qml').write_text('import QtQuick\nItem { property var root; property bool weatherLoaded: true; property string weatherTempStr: "25°C"; implicitWidth: 32; implicitHeight: 28 }\n')
    (base / 'shell.qml').write_text('''import QtQuick
import QtQuick.Window
import Quickshell
ShellRoot {
 id: harness
 property QtObject state: QtObject {
  property string barPosition: "left"
  property bool barVertical: barPosition === "left" || barPosition === "right"
  property string barShellStyle: "full"
  property int verticalBarWidth: barShellStyle === "fit" ? 44 : 40
  property bool barUnlocked: false
  property bool layoutProtected: false
  property bool modStatus: true
  property bool modQuick: true
  property bool modWeather: true
  property bool clock12h: false
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
  property string mono: "monospace"
  property string workspaceMode: "10"
  property string workspaceStyle: "numbers"
  property int panelButtonRadius: 6
  function widgetContentColor(gid, fallback) { return fallback }
  function gotoWorkspace(id) {}
  property bool barBorderEnabled: true
  property var anchorsByName: ({})
  property var verticalAnchorsByScreen: ({})
  property string activePopupScreenName: "fixture"
  property real panelInsetReveal: 0
  property bool cpuVisible: false
  property bool controlVisible: false
  property bool workspaceVisible: false
  property bool calendarVisible: false
  function sepAfter(gid) { return gid === "G5" }
  function widgetSurfacePadding(gid) { return 0 }
  function widgetSurfaceRadius(gid) { return 6 }
  function widgetFillColor(gid) { return "transparent" }
  function widgetSurfaceStyle(gid) { return {opacity: 1, borderWidth: 1} }
  function widgetHasBorder(gid) { return false }
  function widgetBorderColor(gid) { return "#777777" }
  function publishVerticalAnchors(name, values) { anchorsByName = values }
  function publishBarAnchors(name, values) {}
  function verticalAnchorY(name) { return anchorsByName[name] === undefined ? 10 : anchorsByName[name] }
  function activatePopupScreen(screen) {}
 }
 ListModel { id: left; ListElement {gid:"G1"} ListElement {gid:"G2"} ListElement {gid:"G3"} ListElement {gid:"G5"} }
 ListModel { id: center; ListElement {gid:"G8"} }
 ListModel { id: right; ListElement {gid:"G6"} ListElement {gid:"G10"} }
 QtObject {
  id: owner
  property string screenName: "fixture"
  property var screen: ({width:800, height:1400})
  function swapVerticalSlots(sr, si, tr, ti) {
   var models = [left, center, right]
   var a = models[sr].get(si).gid, b = models[tr].get(ti).gid
   models[sr].setProperty(si, "gid", b)
   models[tr].setProperty(ti, "gid", a)
  }
 }
 Component { id: widget; Item { implicitWidth:32; implicitHeight:28 } }
 Window {
  id: window
  visible:true; width:800; height:1400; color:"white"
  VerticalBarContent { id: rail; width:harness.state.verticalBarWidth; height:1400; root:harness.state; barWindow:owner; models:[left,center,right]; registry:({G1:widget,G5:widget,G6:widget}) }
  Rectangle {
   id: card; x:200; y:100; width:280; height:200; color:"transparent"
   AiPanelSurface { root:harness.state; targetX:0; reveal:1 }
   SidePanelPositioner { root:harness.state; target:card; anchorName:"cpu" }
  }
 }
 property int step:0
 property bool captured:false
 Timer { interval:100; repeat:true; running:true; onTriggered: {
  function check(ok, message) { if (!ok) { console.error(message); Qt.exit(1) } }
  if (harness.step === 0) {
   var cells = rail.layoutSnapshot().sort(function(a,b) { return a.y - b.y })
   for (var i = 1; i < cells.length; i++)
    check(cells[i].y >= cells[i-1].y + cells[i-1].height, "OVERLAPPING_SLOTS_" + cells[i-1].gid + "_" + cells[i].gid)
   var workspace = cells.filter(function(cell) { return cell.gid === "G2" })[0]
   check(workspace && workspace.height === 258, "REAL_WORKSPACE_GEOMETRY")
   check(card.x === 46, "LEFT_PANEL_POSITION")
   check(harness.state.anchorsByName.cpu > 0, "MISSING_WIDGET_ANCHOR")
   check(rail.surfaceHeight === 1400, "FULL_HEIGHT")
   var centerCell = cells.filter(function(cell) { return cell.gid === "G8" })[0]
   check(Math.abs(centerCell.y + centerCell.height / 2 - 697) <= 1, "CENTER_REGION_NOT_CENTERED")
   check(harness.state.anchorsByName.weather < harness.state.anchorsByName.calendar, "WEATHER_AND_CLOCK_ANCHORS")
   check(harness.state.anchorsByName.volume > 1000, "RIGHT_REGION_NOT_AT_BOTTOM")
   check(harness.state.anchorsByName.cpu < 600, "LEFT_REGION_NOT_AT_TOP")
   console.log("PANEL_SAMPLE", card.x + 20, card.y + 20)
   window.contentItem.grabToImage(function(result) {
    result.saveToFile("PANEL_CAPTURE")
    harness.state.barShellStyle = "fit"
    harness.state.barPosition = "right"
    harness.captured = true
   })
  } else if (harness.step === 1) {
   if (!harness.captured) return
   check(card.x === 470, "RIGHT_PANEL_POSITION")
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
   harness.state.barVertical = true
   harness.state.barShellStyle = "dock"
   harness.state.clock12h = true
  } else if (harness.step === 6) {
   check(rail.width === 40 && card.x === 474, "DOCK_WIDTH_AND_PANEL")
   var clockCell = rail.layoutSnapshot().filter(function(cell) { return cell.gid === "G8" })[0]
   check(clockCell.height === 64, "TWELVE_HOUR_CLOCK_HEIGHT")
   harness.state.barShellStyle = "notch"
   harness.state.barPosition = "left"
  } else if (harness.step === 7) {
   check(rail.width === 40 && card.x === 46, "NOTCH_WIDTH_AND_PANEL")
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
  } else {
   check(card.x === 200 && card.y === 100, "HORIZONTAL_BINDING_RESTORE")
   console.log("VERTICAL_LAYOUT_PASS")
   Qt.quit()
  }
  harness.step++
 }}
}
'''.replace('PANEL_CAPTURE', str(base / 'panel.png')))
    env = dict(os.environ, XDG_RUNTIME_DIR=str(base / 'runtime'), QT_QPA_PLATFORM='offscreen',
               QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='')
    env.pop('WAYLAND_DISPLAY', None)
    env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
    result = subprocess.run(['qs', '-n', '-p', str(base / 'shell.qml')], env=env,
                            capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode or 'VERTICAL_LAYOUT_PASS' not in output or 'WARN scene:' in output or 'ERROR qml:' in output:
        raise SystemExit(result.returncode or 1)

    sample = re.search(r'PANEL_SAMPLE (\d+) (\d+)', output)
    if not sample:
        raise SystemExit('Missing panel opacity sample')
    color = subprocess.check_output(['magick', str(base / 'panel.png'), '-crop',
        f'1x1+{sample[1]}+{sample[2]}', '-depth', '8', 'rgb:-'])
    if len(color) != 3 or max(color) > 50:
        raise SystemExit(f'Panel background is too transparent: {tuple(color)}')
    print('PANEL_BACKGROUND_PASS')
