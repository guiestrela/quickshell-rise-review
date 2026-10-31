pragma ComponentBehavior: Bound
import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: gpuPanel
    required property var root

    screen: gpuPanel.root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-gpu"

    readonly property int barBottom: 35
    readonly property int gap: 8
    readonly property int gpuUtil: gpuPanel.root.gpuPercent
    readonly property int gpuTemp: gpuPanel.root.gpuTemperatureC
    readonly property int gpuMemUsed: gpuPanel.root.gpuMemoryUsedMiB
    readonly property int gpuMemTotal: gpuPanel.root.gpuMemoryTotalMiB

    function gib(mib) {
        return (Math.max(0, mib) / 1024).toFixed(1) + " GiB"
    }

    property real reveal: gpuPanel.root.gpuVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: gpuPanel.root.gpuVisible ? 160 : 120
            easing.type: gpuPanel.root.gpuVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: gpuPanel.root.gpuVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    component InfoRow: Item {
        id: infoRow
        property string label: ""
        property string value: ""

        width: parent ? parent.width : 0
        height: 16
        visible: value !== ""

        UiText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: infoRow.label
            color: gpuPanel.root.sumiHi
            font.family: gpuPanel.root.mono
            font.pixelSize: 10
        }
        UiText {
            anchors.left: parent.left
            anchors.leftMargin: 112
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: infoRow.value
            color: gpuPanel.root.ink
            font.family: gpuPanel.root.mono
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: gpuPanel.root.gpuVisible = false
    }

    Rectangle {
        id: card
        width: 320
        height: col.implicitHeight + 24
        radius: gpuPanel.reveal > 0.001 ? gpuPanel.root.pillRadius : 0
        color: gpuPanel.root.bg
        border.color: gpuPanel.root.pillBorder
        border.width: gpuPanel.root.pillBorderW
        PillShadow { theme: gpuPanel.root }


        x: Math.round(Math.max(6, Math.min(gpuPanel.root.gpuBarX - width / 2, parent.width - width - 6)))
        y: gpuPanel.root.barPosition === "bottom"
            ? (parent.height - gpuPanel.barBottom - gpuPanel.gap - height) + 2 * (1 - gpuPanel.reveal)
            : (gpuPanel.barBottom + gpuPanel.gap) - 2 * (1 - gpuPanel.reveal)
        opacity: gpuPanel.reveal
        focus: gpuPanel.root.gpuVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                gpuPanel.root.gpuVisible = false
                event.accepted = true
            }
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
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "GPU"
                    color: gpuPanel.root.ink
                    font.family: gpuPanel.root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeMa.containsMouse ? gpuPanel.root.seal : gpuPanel.root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: gpuPanel.root.gpuVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: gpuPanel.root.sep }

            InfoRow {
                label: "Model"
                value: gpuPanel.root.gpuAvailable
                    ? (gpuPanel.root.gpuName !== "" ? gpuPanel.root.gpuName
                        : (gpuPanel.root.gpuBackend === "nvidia" ? "NVIDIA GPU" : "GPU"))
                    : ""
            }

            Item {
                width: parent.width
                height: 16
                visible: gpuPanel.root.gpuAvailable
                UiText {
                    id: gpuLbl
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "USAGE"
                    color: gpuPanel.root.sumiHi
                    font.family: gpuPanel.root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }
                UiText {
                    id: gpuVal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: gpuPanel.gpuUtil + "%"
                    color: gpuPanel.root.seal
                    font.family: gpuPanel.root.mono
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
                Rectangle {
                    anchors.left: gpuLbl.right
                    anchors.leftMargin: 8
                    anchors.right: gpuVal.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8
                    radius: 4
                    color: gpuPanel.root.fillActive
                    Rectangle {
                        width: parent.width * gpuPanel.gpuUtil / 100
                        height: parent.height
                        radius: 4
                        color: gpuPanel.root.seal
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }

            InfoRow {
                label: "Temperature"
                value: gpuPanel.gpuTemp > 0 ? gpuPanel.gpuTemp + "°C" : ""
            }
            FanRpmHistory {
                width: parent.width
                theme: gpuPanel.root
                active: gpuPanel.root.gpuVisible
                externalSource: true
                externalRpm: gpuPanel.root.gpuFanRpm
                sensorLabel: "FAN"
            }
            InfoRow {
                label: "VRAM"
                value: gpuPanel.gpuMemTotal > 0
                    ? gpuPanel.gib(gpuPanel.gpuMemUsed) + " / " + gpuPanel.gib(gpuPanel.gpuMemTotal)
                    : ""
            }
            InfoRow {
                label: "Graphics clock"
                value: gpuPanel.root.gpuClockMHz > 0 ? gpuPanel.root.gpuClockMHz + " MHz" : ""
            }
            InfoRow {
                label: "Power"
                value: gpuPanel.root.gpuPowerW > 0
                    ? gpuPanel.root.gpuPowerW.toFixed(0) + " W"
                        + (gpuPanel.root.gpuPowerLimitW > 0 ? " / " + gpuPanel.root.gpuPowerLimitW.toFixed(0) + " W" : "")
                    : ""
            }
            InfoRow {
                label: "Fan · state"
                value: gpuPanel.root.gpuFanPercent > 0 || gpuPanel.root.gpuPerformanceState !== ""
                    ? (gpuPanel.root.gpuFanPercent > 0 ? gpuPanel.root.gpuFanPercent + "%" : "—")
                        + (gpuPanel.root.gpuPerformanceState !== "" ? " · " + gpuPanel.root.gpuPerformanceState : "")
                    : ""
            }
            InfoRow { label: "Driver"; value: gpuPanel.root.gpuDriverVersion }

            UiText {
                width: parent.width
                visible: !gpuPanel.root.gpuAvailable
                text: "GPU telemetry unavailable"
                color: gpuPanel.root.sumiHi
                font.family: gpuPanel.root.mono
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle { width: parent.width; height: 1; color: gpuPanel.root.sep }

            Rectangle {
                width: parent.width
                height: 28
                radius: gpuPanel.root.tileRadius
                color: btopMa.containsMouse ? gpuPanel.root.fillPrimaryHover : gpuPanel.root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: "Open btop"
                    color: gpuPanel.root.paper
                    font.family: gpuPanel.root.mono
                    font.pixelSize: 11
                }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        gpuPanel.root.gpuVisible = false
                        btopRunner.running = false
                        btopRunner.running = true
                    }
                }
            }
        }
    }

    Process {
        id: btopRunner
        command: ["bash", "-c", "omarchy-launch-floating-terminal-with-presentation 'btop'"]
    }
    SidePanelPositioner { root: gpuPanel.root; target: card; anchorName: "gpu" }
}
