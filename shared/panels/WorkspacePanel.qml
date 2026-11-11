pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../components" as CommonComponents

PanelWindow {
    id: wsPanel
    required property var root

    screen: wsPanel.root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-workspace"

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

    property real reveal: wsPanel.root.workspaceVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: wsPanel.root.workspaceVisible ? 160 : 120
            easing.type: wsPanel.root.workspaceVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: wsPanel.root.workspaceVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: wsPanel.root.workspaceVisible = false }

    Rectangle {
        id: card
        width: 240
        height: col.implicitHeight + 24
        radius: wsPanel.reveal > 0.001 ? wsPanel.frameRadius : 0
        color: wsPanel.frameColor
        border.color: wsPanel.frameBorderColor
        border.width: wsPanel.frameBorderWidth
        Loader { anchors.fill: parent; sourceComponent: wsPanel.surfaceComponent }
        x: Math.round(Math.max(6, Math.min(wsPanel.root.workspaceBarX - width / 2, parent.width - width - 6)))
        y: wsPanel.root.barPosition === "bottom"
            ? (parent.height - wsPanel.barBottom - wsPanel.gap - height) + wsPanel.revealShift
            : (wsPanel.barBottom + wsPanel.gap) - wsPanel.revealShift
        opacity: wsPanel.reveal
        focus: wsPanel.root.workspaceVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { wsPanel.root.workspaceVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 24
                CommonComponents.UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Workspaces"
                    color: wsPanel.root.ink; font.family: wsPanel.root.mono; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                CommonComponents.UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? wsPanel.root.seal : wsPanel.root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wsPanel.root.workspaceVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: wsPanel.root.sep }

            Column {
                width: parent.width
                spacing: 4
                Repeater {
                    model: Hyprland.workspaces

                    delegate: Rectangle {

                        id: workspaceRow
                        required property var modelData
                        visible: modelData.id > 0   // F13: hide special (negative-id) workspaces from the normal list
                        readonly property bool isActive: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
                        width: col.width
                        height: 30; radius: wsPanel.buttonRadius
                        color: isActive ? wsPanel.root.fillActive
                                : ma.containsMouse ? wsPanel.root.fillHover : wsPanel.root.fillIdle
                        border.color: (ma.containsMouse || isActive) ? wsPanel.root.seal : wsPanel.root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        CommonComponents.UiText {
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Workspace " + workspaceRow.modelData.id
                            color: (ma.containsMouse || workspaceRow.isActive) ? wsPanel.root.seal : wsPanel.root.ink
                            font.family: wsPanel.root.mono; font.pixelSize: 12
                            font.weight: workspaceRow.isActive ? Font.Medium : Font.Normal
                        }
                        CommonComponents.UiText {
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: workspaceRow.modelData.toplevels && workspaceRow.modelData.toplevels.values ? workspaceRow.modelData.toplevels.values.length : ""
                            color: wsPanel.root.sumiHi; font.family: wsPanel.root.mono; font.pixelSize: 10
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wsPanel.root.gotoWorkspace(workspaceRow.modelData.id)
                                wsPanel.root.workspaceVisible = false
                            }
                        }
                    }
                }
            }
        }
    }

}
