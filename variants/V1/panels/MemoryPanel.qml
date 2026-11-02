pragma ComponentBehavior: Bound
import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: memPanel
    required property var root

    screen: memPanel.root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-memory"

    readonly property int barBottom: 35
    readonly property int gap: 8

    readonly property int memTotal: memPanel.root.systemMemTotalMiB
    readonly property int memAvail: memPanel.root.systemMemAvailMiB
    readonly property int memFree: memPanel.root.systemMemFreeMiB
    readonly property int memBuffers: memPanel.root.systemMemBuffersMiB
    readonly property int memCached: memPanel.root.systemMemCachedMiB
    readonly property int memUsed: memPanel.root.systemMemUsedMiB
    readonly property int pct: memPanel.root.systemMemPercent
    readonly property real usedGiB: memUsed / 1024
    readonly property real totalGiB: memTotal / 1024

    property real reveal: memPanel.root.memVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: memPanel.root.memVisible ? 160 : 120
            easing.type: memPanel.root.memVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: memPanel.root.memVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: memPanel.root.memVisible = false
    }

    Rectangle {
        id: card
        width: 320
        height: col.implicitHeight + 24
        radius: memPanel.reveal > 0.001 ? memPanel.root.pillRadius : 0
        color: memPanel.root.bg
        border.color: memPanel.root.pillBorder
        border.width: memPanel.root.pillBorderW
        PillShadow { theme: memPanel.root }

        x: Math.round(Math.max(6, Math.min(memPanel.root.memoryBarX - width / 2, parent.width - width - 6)))
        y: memPanel.root.barPosition === "bottom" ? (parent.height - memPanel.barBottom - memPanel.gap - height) : (memPanel.barBottom + memPanel.gap)
        opacity: memPanel.reveal
        focus: memPanel.root.memVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                memPanel.root.memVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header ──
            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Memory"
                    color: memPanel.root.ink
                    font.family: memPanel.root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2715"
                    color: closeMa.containsMouse ? memPanel.root.seal : memPanel.root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: memPanel.root.memVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: memPanel.root.sep }

            // ── usage bar ──
            Item {
                width: parent.width
                height: 30
                UiText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: memPanel.pct + "%"
                    color: memPanel.root.seal
                    font.family: memPanel.root.mono; font.pixelSize: 11; font.weight: Font.Medium
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 8; radius: 4
                    color: memPanel.root.fillActive
                    Rectangle {
                        width: parent.width * memPanel.pct / 100
                        height: parent.height; radius: 4
                        color: memPanel.root.seal
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }

            // ── stats ──
            Column {
                width: parent.width
                spacing: 4
                Row {
                    width: parent.width
                    UiText { text: "Used"; color: memPanel.root.sumiHi; font.family: memPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    UiText { text: memPanel.usedGiB.toFixed(1) + " GiB"; color: memPanel.root.ink; font.family: memPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.3 }
                    UiText { text: memPanel.memUsed + " MiB"; color: Qt.rgba(memPanel.root.ink.r, memPanel.root.ink.g, memPanel.root.ink.b, 0.6); font.family: memPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.3 }
                }
                Row {
                    width: parent.width
                    UiText { text: "Available"; color: memPanel.root.sumiHi; font.family: memPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    UiText { text: (memPanel.memAvail / 1024).toFixed(1) + " GiB"; color: memPanel.root.ink; font.family: memPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.3 }
                    UiText { text: memPanel.memAvail + " MiB"; color: Qt.rgba(memPanel.root.ink.r, memPanel.root.ink.g, memPanel.root.ink.b, 0.6); font.family: memPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.3 }
                }
                Row {
                    width: parent.width
                    UiText { text: "Total"; color: memPanel.root.sumiHi; font.family: memPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    UiText { text: memPanel.totalGiB.toFixed(1) + " GiB"; color: memPanel.root.ink; font.family: memPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.3 }
                    UiText { text: memPanel.memTotal + " MiB"; color: Qt.rgba(memPanel.root.ink.r, memPanel.root.ink.g, memPanel.root.ink.b, 0.6); font.family: memPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.3 }
                }
            }

            Rectangle { width: parent.width; height: 1; color: memPanel.root.sep }

            // ── button ──
            Rectangle {
                width: parent.width
                height: 28; radius: memPanel.root.tileRadius
                color: btopMa.containsMouse ? memPanel.root.fillPrimaryHover : memPanel.root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: "Open btop"
                    color: memPanel.root.paper
                    font.family: memPanel.root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        memPanel.root.memVisible = false;
                        btopRunner.running = false;
                        btopRunner.running = true;
                    }
                }
            }
        }
    }

    Process {
        id: btopRunner
        command: ["bash", "-c", "omarchy-launch-floating-terminal-with-presentation 'btop'"]
    }
    SidePanelPositioner { root: memPanel.root; target: card; anchorName: "memory" }
}
