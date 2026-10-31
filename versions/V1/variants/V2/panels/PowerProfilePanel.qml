pragma ComponentBehavior: Bound
import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: profilePanel
    required property var root

    screen: profilePanel.root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-power-profile"

    readonly property int barBottom: profilePanel.root.v2BarHeight
    readonly property int gap: 6

    readonly property var profiles: [
        { key: "power-saver",  icon: "\uF06C",  label: "Power Saver" },
        { key: "balanced",     icon: "\uF24E", label: "Balanced" },
        { key: "performance",  icon: "\uF0E7", label: "Performance" },
    ]

    property real reveal: profilePanel.root.powerProfileVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: profilePanel.root.powerProfileVisible ? 160 : 120
            easing.type: profilePanel.root.powerProfileVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: profilePanel.root.powerProfileVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: profilePanel.root.powerProfileVisible = false
    }

    Rectangle {
        id: card
        width: 220
        height: col.implicitHeight + 24
        radius: profilePanel.reveal > 0.001 ? profilePanel.root.panelRadius : 0
        color: "transparent"
        border.color: profilePanel.root.panelBorder
        border.width: 0
        PillShadow { theme: profilePanel.root }
        ConnectedPanelSurface {
            root: profilePanel.root
            ownerActive: profilePanel.root.powerProfileVisible
            targetX: profilePanel.root.powerBarX
            reveal: profilePanel.reveal
        }

        SidePanelPositioner { root: profilePanel.root; target: parent; anchorName: "power" }
        x: Math.round(Math.max(6, Math.min(profilePanel.root.powerBarX - width / 2, parent.width - width - 6)))
        y: profilePanel.root.barPosition === "bottom"
            ? (parent.height - profilePanel.barBottom - profilePanel.gap - height) + 2 * (1 - profilePanel.reveal)
            : (profilePanel.barBottom + profilePanel.gap) - 2 * (1 - profilePanel.reveal)
        opacity: profilePanel.reveal
        focus: profilePanel.root.powerProfileVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                profilePanel.root.powerProfileVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            // ── header ──
            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Power Profile"
                    color: profilePanel.root.ink
                    font.family: profilePanel.root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2715"
                    color: closeMa.containsMouse ? profilePanel.root.seal : profilePanel.root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: profilePanel.root.powerProfileVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: profilePanel.root.sep }

            // ── profile buttons ──
            Repeater {
                model: profilePanel.profiles

                delegate: Item {
                    id: profileRow
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 32

                    property bool isActive: profilePanel.root.powerProfileCurrent === modelData.key

                    Rectangle {
                        anchors.fill: parent
                        radius: profilePanel.root.panelButtonRadius
                        color: profileRow.isActive ? profilePanel.root.fillActive
                               : ma.containsMouse ? profilePanel.root.fillHover : profilePanel.root.fillIdle
                        border.color: (ma.containsMouse || profileRow.isActive) ? profilePanel.root.seal : profilePanel.root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 8
                        anchors.right: parent.right; anchors.rightMargin: 8
                        spacing: 8

                        UiText {
                            text: profileRow.modelData.icon
                            renderType: Text.QtRendering
                            color: (ma.containsMouse || profileRow.isActive) ? profilePanel.root.seal : profilePanel.root.ink
                            font.family: profilePanel.root.mono
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        UiText {
                            text: profileRow.modelData.label
                            color: (ma.containsMouse || profileRow.isActive) ? profilePanel.root.seal : profilePanel.root.ink
                            font.family: profilePanel.root.mono
                            font.pixelSize: 12
                            font.weight: profileRow.isActive ? Font.Medium : Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            setProfileProc.command = ["bash", "-c", "powerprofilesctl set " + profileRow.modelData.key]
                            setProfileProc.running = false
                            setProfileProc.running = true
                            profilePanel.root.powerProfileCurrent = profileRow.modelData.key
                            profilePanel.root.powerProfileVisible = false
                        }
                    }
                }
            }
        }
    }

    Process {
        id: setProfileProc
        command: ["bash", "-c", "powerprofilesctl set balanced"]
        running: false
    }
}
