pragma ComponentBehavior: Bound
import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: cpuPanel
    required property var root

    screen: cpuPanel.root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-cpu"

    readonly property int barBottom: 35
    readonly property int gap: 8
    readonly property int cpuPct: cpuPanel.root.systemCpuPercent

    readonly property string topologySummary: cpuPanel.root.cpuCoreCount > 0 && cpuPanel.root.cpuThreadCount > 0
        ? cpuPanel.root.cpuCoreCount + "C / " + cpuPanel.root.cpuThreadCount + "T" : ""
    readonly property string clockSummary: cpuPanel.root.cpuClockMHz > 0
        ? (cpuPanel.root.cpuClockMHz / 1000).toFixed(1) + " / "
            + (cpuPanel.root.cpuMaxClockMHz / 1000).toFixed(1) + " GHz"
        : ""
    readonly property string loadSummary: cpuPanel.root.systemLoad1.toFixed(2) + " · "
        + cpuPanel.root.systemLoad5.toFixed(2) + " · " + cpuPanel.root.systemLoad15.toFixed(2)
    readonly property string powerMode: {
        var mode = cpuPanel.root.cpuEnergyPreference !== ""
            ? cpuPanel.root.cpuEnergyPreference : cpuPanel.root.cpuScalingGovernor
        return mode.replace(/_/g, " ")
    }

    property real reveal: cpuPanel.root.cpuVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: cpuPanel.root.cpuVisible ? 160 : 120
            easing.type: cpuPanel.root.cpuVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: cpuPanel.root.cpuVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    component InfoRow: Item {
        id: infoRow
        property string label: ""
        property string value: ""
        property color valueColor: cpuPanel.root.ink

        width: parent ? parent.width : 0
        height: 16
        visible: value !== ""

        UiText {
            id: infoLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: infoRow.label
            color: cpuPanel.root.sumiHi
            font.family: cpuPanel.root.mono
            font.pixelSize: 10
        }
        UiText {
            anchors.left: infoLabel.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: infoRow.value
            color: infoRow.valueColor
            font.family: cpuPanel.root.mono
            font.pixelSize: 10
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: cpuPanel.root.cpuVisible = false
    }

    Rectangle {
        id: card
        width: 320
        height: col.implicitHeight + 24
        radius: cpuPanel.reveal > 0.001 ? cpuPanel.root.pillRadius : 0
        color: cpuPanel.root.bg
        border.color: cpuPanel.root.pillBorder
        border.width: cpuPanel.root.pillBorderW
        PillShadow { theme: cpuPanel.root }


        x: Math.round(Math.max(6, Math.min(cpuPanel.root.cpuBarX - width / 2, parent.width - width - 6)))
        y: cpuPanel.root.barPosition === "bottom"
            ? (parent.height - cpuPanel.barBottom - cpuPanel.gap - height) + 2 * (1 - cpuPanel.reveal)
            : (cpuPanel.barBottom + cpuPanel.gap) - 2 * (1 - cpuPanel.reveal)
        opacity: cpuPanel.reveal
        focus: cpuPanel.root.cpuVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                cpuPanel.root.cpuVisible = false
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
                    text: "CPU"
                    color: cpuPanel.root.ink
                    font.family: cpuPanel.root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                UiText {
                    anchors.right: closeText.left
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "KERNEL " + cpuPanel.root.kernelRelease
                    color: cpuPanel.root.sumiHi
                    font.family: cpuPanel.root.mono
                    font.pixelSize: 9
                }
                UiText {
                    id: closeText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeMa.containsMouse ? cpuPanel.root.seal : cpuPanel.root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cpuPanel.root.cpuVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: cpuPanel.root.sep }

            Item {
                width: parent.width
                height: 16
                UiText {
                    anchors.left: parent.left
                    anchors.right: topologyValue.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: cpuPanel.root.cpuModelName
                    color: cpuPanel.root.ink
                    font.family: cpuPanel.root.mono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                UiText {
                    id: topologyValue
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: cpuPanel.topologySummary
                    color: cpuPanel.root.sumiHi
                    font.family: cpuPanel.root.mono
                    font.pixelSize: 10
                }
            }

            Item {
                width: parent.width
                height: 16
                UiText {
                    id: cpuLbl
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "USAGE"
                    color: cpuPanel.root.sumiHi
                    font.family: cpuPanel.root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }
                UiText {
                    id: cpuVal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: cpuPanel.cpuPct + "%"
                    color: cpuPanel.root.seal
                    font.family: cpuPanel.root.mono
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
                Rectangle {
                    anchors.left: cpuLbl.right
                    anchors.leftMargin: 8
                    anchors.right: cpuVal.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8
                    radius: 4
                    color: cpuPanel.root.fillActive
                    Rectangle {
                        width: parent.width * cpuPanel.cpuPct / 100
                        height: parent.height
                        radius: 4
                        color: cpuPanel.root.seal
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }

            FanRpmHistory {
                width: parent.width
                theme: cpuPanel.root
                active: cpuPanel.root.cpuVisible
            }

            FanControl {
                width: parent.width
                theme: cpuPanel.root
                active: cpuPanel.root.cpuVisible
            }

            InfoRow { label: "Clock"; value: cpuPanel.clockSummary }
            InfoRow { label: "Load 1 · 5 · 15"; value: cpuPanel.loadSummary }
            InfoRow {
                label: "Breakdown"
                value: "User " + cpuPanel.root.systemCpuUserPercent + "% · System "
                    + cpuPanel.root.systemCpuSystemPercent + "% · I/O " + cpuPanel.root.systemCpuIoWaitPercent + "%"
            }
            InfoRow { label: "Power mode"; value: cpuPanel.powerMode }
            InfoRow {
                label: "Throttling"
                value: cpuPanel.root.cpuThrottleCount > 0 ? cpuPanel.root.cpuThrottleCount + " events" : ""
                valueColor: cpuPanel.root.sealRaw
            }

            Rectangle { width: parent.width; height: 1; color: cpuPanel.root.sep }

            Item {
                width: parent.width
                height: 14
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TOP PROCESSES"
                    color: cpuPanel.root.sumiHi
                    font.family: cpuPanel.root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CPU"
                    color: cpuPanel.root.sumi
                    font.family: cpuPanel.root.mono
                    font.pixelSize: 9
                }
            }

            Column {
                width: parent.width
                spacing: 4

                Repeater {
                    model: 3
                    delegate: Item {
                        id: processRow
                        required property int index
                        readonly property var process: index < cpuPanel.root.cpuTopProcesses.length
                            ? cpuPanel.root.cpuTopProcesses[index] : null
                        width: col.width
                        height: 16

                        UiText {
                            id: processRank
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(processRow.index + 1).padStart(2, "0")
                            color: cpuPanel.root.sumi
                            font.family: cpuPanel.root.mono
                            font.pixelSize: 9
                        }
                        UiText {
                            anchors.left: processRank.right
                            anchors.leftMargin: 10
                            anchors.right: processValue.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: processRow.process ? processRow.process.name : (processRow.index === 0 ? "Collecting…" : "—")
                            color: processRow.process ? cpuPanel.root.ink : cpuPanel.root.sumi
                            font.family: cpuPanel.root.mono
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                        UiText {
                            id: processValue
                            width: 52
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: processRow.process ? Number(processRow.process.percent).toFixed(1) + "%" : "—"
                            color: processRow.process ? cpuPanel.root.ink : cpuPanel.root.sumi
                            font.family: cpuPanel.root.mono
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: cpuPanel.root.sep }

            Rectangle {
                width: parent.width
                height: 28
                radius: cpuPanel.root.tileRadius
                color: btopMa.containsMouse ? cpuPanel.root.fillPrimaryHover : cpuPanel.root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: "Open btop"
                    color: cpuPanel.root.paper
                    font.family: cpuPanel.root.mono
                    font.pixelSize: 11
                }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        cpuPanel.root.cpuVisible = false
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
    SidePanelPositioner { root: cpuPanel.root; target: card; anchorName: "cpu" }
}
