import QtQuick
import Quickshell
import Quickshell.Wayland
import "../panels" as Panels

ShellRoot {
    id: shell
    QtObject {
        id: fakeRoot
        property var displayManagerControllerApi: fakeController
        property bool displayManagerVisible: false
        property var activePopupScreen: Quickshell.screens.length ? Quickshell.screens[0] : null
        property string barPosition: "top"
        property real displayManagerBarY: 35
        property real displayManagerBarX: 300
        property int tileRadius: 8
        property color bg: "#202020"
        property color sep: "#404040"
        property color seal: "#ffffff"
        property string mono: "monospace"
        property color ink: "#ffffff"
        property color fillActive: "#303030"
        property color fillIdle: "#282828"
        property bool displayManagerAutoWorkspaces: true
    }
    QtObject {
        id: fakeController
        property var monitors: []
        property string selectedMonitor: ""
        property string error: ""
        property bool busy: false
        property bool loading: false
        property bool brightnessAvailable: false
        property int brightnessPercent: 0
        property var scalePresets: [1, 1.25, 1.5]
        property var textSizeStops: [9, 10, 12]
        property int textSizeIndex: 1
        property int refreshCount: 0
        property var drafts: ({})
        property var draftBrightness: ({})
        property int draftTextSizeIndex: -1
        readonly property bool hasDrafts: Object.keys(drafts).length > 0 || Object.keys(draftWorkspaceAssignments).length > 0 || Object.keys(draftBrightness).length > 0 || draftTextSizeIndex >= 0
        readonly property var previewMonitors: monitors.map(function(m) { return fakeController.previewMonitor(m.name) })
        readonly property var previewPositions: {
            var result = {}
            for (var m of previewMonitors) result[m.name] = { x: m.x, y: m.y }
            return result
        }
        property var workspaceAssignments: ({ "1": "DP-1", "2": "DP-2" })
        property var workspaceOverrides: ({})
        property var draftWorkspaceAssignments: ({})
        property bool workspaceStateReady: true
        property bool workspaceLoading: false
        property bool workspaceCommitPending: false
        property var extraQueue: []
        property string workspaceError: ""
        function refreshWorkspaces() { }
        function workspaceOwner(number) { return draftWorkspaceAssignments[String(number)] || workspaceAssignments[String(number)] || "" }
        function stageWorkspace(number, name) { var copy=Object.assign({},draftWorkspaceAssignments);copy[String(number)]=name;draftWorkspaceAssignments=copy;return true }
        property var applyCalls: []
        function previewMonitor(name) { for (var m of monitors) if (m.name === name) return Object.assign({}, m, drafts[name] || {}); return null }
        function stageMonitor(name, patch) { var copy = Object.assign({}, drafts); copy[name] = Object.assign({}, previewMonitor(name), patch); drafts = copy; return true }
        function stageDisable(name) { return stageMonitor(name, { disabled: true }) }
        function stageBrightness(name, value) { var copy = Object.assign({}, draftBrightness); copy[name] = value; draftBrightness = copy; return true }
        function stageTextSize(index) { draftTextSizeIndex = index; return true }
        function applyDrafts() { applyCalls.push(JSON.parse(JSON.stringify({ monitors: previewMonitors, brightness: draftBrightness, text: draftTextSizeIndex }))); return true }
        function refresh() { refreshCount++ }
        function monitor(name) { return null }
        function applyMonitor() { }
        function setPosition() { }
        function enableMonitor() { }
        function disableMonitor() { }
        function setBrightness() { }
        function setTextSize() { }
        function saveLayout() { }
    }
    Panels.DisplayManagerPanel {
        id: productionPanel
        root: fakeRoot
        Component.onCompleted: console.log("DISPLAY_PANEL_INSTANCE_CREATED")
    }
    Timer {
        interval: 250
        running: true
        onTriggered: {
            fakeRoot.displayManagerVisible = true
            Qt.callLater(function() {
                if (fakeController.refreshCount !== 1) { console.error("DISPLAY_PANEL_DISCOVERY_MISSING"); Qt.quit(); return }
                console.log("DISPLAY_PANEL_INSTANCE_PASS refresh=" + fakeController.refreshCount)
                Qt.quit()
            })
        }
    }
}
