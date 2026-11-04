pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../integrations/onedrive" as OneDrive

PanelWindow {
    id: panel
    required property var root
    required property int barBottom
    required property int gap
    required property real frameRadius
    required property color frameColor
    required property color frameBorderColor
    required property real frameBorderWidth
    required property real buttonRadius
    property real revealShift: 0
    property Component surfaceComponent
    readonly property Item surfaceHost: card
    readonly property var service: root.oneDriveService
    readonly property real reveal: root.oneDriveVisible ? 1 : 0
    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rise-onedrive"
    WlrLayershell.keyboardFocus: root.oneDriveVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: reveal > 0

    function open(accountTarget) { body.open(accountTarget) }
    function close() { root.oneDriveVisible = false }
    Connections {
        target: panel.root
        function onOneDriveVisibleChanged() {
            if (panel.root.oneDriveVisible) {
                const target = panel.root.oneDriveOpenTarget
                panel.root.oneDriveOpenTarget = ""
                body.open(target)
            }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: panel.close() }
    Rectangle {
        id: card
        width: Math.min(414, parent.width - 16)
        height: Math.min(body.contentHeight + 24, parent.height - panel.barBottom - panel.gap - 16)
        x: Math.round(Math.max(8, Math.min(panel.root.oneDriveBarX - width / 2, parent.width - width - 8)))
        y: panel.root.barPosition === "bottom"
            ? parent.height - panel.barBottom - panel.gap - height + panel.revealShift
            : panel.barBottom + panel.gap - panel.revealShift
        radius: panel.frameRadius
        color: panel.frameColor
        border.color: panel.frameBorderColor
        border.width: panel.frameBorderWidth
        Loader { anchors.fill: parent; sourceComponent: panel.surfaceComponent }
        MouseArea { anchors.fill: parent; onClicked: {} }
        OneDrive.Panel {
            id: body
            anchors.fill: parent
            anchors.margins: 12
            theme: panel.root
            service: panel.service
        }
    }
}
