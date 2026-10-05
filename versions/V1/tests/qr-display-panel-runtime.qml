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
