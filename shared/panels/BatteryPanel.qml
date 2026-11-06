pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../components" as CommonComponents

PanelWindow {
    id: batPanel
    required property var root

    screen: batPanel.root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-battery"

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

    property int    percent: 0
    property string status:  "unknown"
    property string batteryId: ""
    property string healthText: ""
    property string sizeText: ""
    property string timeLabel: "Time left"
    property string timeText: ""
    property string powerRate: ""
    property int    cycles:   0
    readonly property string healthLabel: batteryId !== "" ? "Health (" + batteryId + ")" : "Health"
    readonly property bool charging: status === "charging"
    function refreshBatteryData() {
        if (!batData.running) batData.running = true
    }
    function statusTitle(s) {
        var t = String(s || "unknown")
        if (t === "fully-charged") return "Full"
        return t.length > 0 ? t.charAt(0).toUpperCase() + t.slice(1) : "Unknown"
    }

    property real reveal: batPanel.root.batteryVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: batPanel.root.batteryVisible ? 160 : 120
            easing.type: batPanel.root.batteryVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: batPanel.root.batteryVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: batPanel.root.batteryVisible = false }

    Rectangle {
        id: card
        width: 300
        height: col.implicitHeight + 24
        radius: batPanel.reveal > 0.001 ? batPanel.frameRadius : 0
        color: batPanel.frameColor
        border.color: batPanel.frameBorderColor
        border.width: batPanel.frameBorderWidth
        Loader {
            anchors.fill: parent
            sourceComponent: batPanel.surfaceComponent
        }

        x: Math.round(Math.max(6, Math.min(batPanel.root.batteryBarX - width / 2, parent.width - width - 6)))
        y: batPanel.root.barPosition === "bottom"
            ? (parent.height - batPanel.barBottom - batPanel.gap - height) + batPanel.revealShift
            : (batPanel.barBottom + batPanel.gap) - batPanel.revealShift
        opacity: batPanel.reveal
        focus: batPanel.root.batteryVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { batPanel.root.batteryVisible = false; event.accepted = true }
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
                    text: "Battery"
                    color: batPanel.root.ink; font.family: batPanel.root.mono; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                CommonComponents.UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? batPanel.root.seal : batPanel.root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: batPanel.root.batteryVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: batPanel.root.sep }

            Item {
                width: parent.width
                height: 30
                CommonComponents.UiText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: batPanel.percent + "%"
                    color: batPanel.charging ? batPanel.root.indigo : batPanel.root.seal
                    font.family: batPanel.root.mono; font.pixelSize: 11; font.weight: Font.Medium
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 8; radius: 4
                    color: batPanel.root.fillActive
                    Rectangle {
                        width: parent.width * batPanel.percent / 100
                        height: parent.height; radius: 4
                        color: batPanel.charging ? batPanel.root.indigo : batPanel.root.seal
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 4
                Row {
                    width: parent.width
                    CommonComponents.UiText { text: "Status"; color: batPanel.root.sumiHi; font.family: batPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    CommonComponents.UiText {
                        text: batPanel.statusTitle(batPanel.status)
                        color: batPanel.charging ? batPanel.root.indigo : batPanel.root.ink
                        font.family: batPanel.root.mono; font.pixelSize: 11
                    }
                }
                Row {
                    width: parent.width
                    visible: batPanel.timeText !== ""
                    CommonComponents.UiText { text: batPanel.timeLabel; color: batPanel.root.sumiHi; font.family: batPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    CommonComponents.UiText { text: batPanel.timeText; color: batPanel.root.ink; font.family: batPanel.root.mono; font.pixelSize: 11 }
                }
                Row {
                    width: parent.width
                    visible: batPanel.healthText !== ""
                    CommonComponents.UiText { text: batPanel.healthLabel; color: batPanel.root.sumiHi; font.family: batPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    CommonComponents.UiText { text: batPanel.healthText; color: batPanel.root.ink; font.family: batPanel.root.mono; font.pixelSize: 11 }
                }
                Row {
                    width: parent.width
                    visible: batPanel.powerRate !== ""
                    CommonComponents.UiText { text: batPanel.charging ? "Charge rate" : "Power draw"; color: batPanel.root.sumiHi; font.family: batPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    CommonComponents.UiText { text: batPanel.powerRate + " W"; color: batPanel.root.ink; font.family: batPanel.root.mono; font.pixelSize: 11 }
                }
                Row {
                    width: parent.width
                    visible: batPanel.sizeText !== ""
                    CommonComponents.UiText { text: "Battery size"; color: batPanel.root.sumiHi; font.family: batPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    CommonComponents.UiText { text: batPanel.sizeText; color: batPanel.root.ink; font.family: batPanel.root.mono; font.pixelSize: 11 }
                }
                Row {
                    width: parent.width
                    visible: batPanel.cycles > 0
                    CommonComponents.UiText { text: "Charge cycles"; color: batPanel.root.sumiHi; font.family: batPanel.root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    CommonComponents.UiText { text: String(batPanel.cycles); color: batPanel.root.ink; font.family: batPanel.root.mono; font.pixelSize: 11 }
                }
            }

            Rectangle { width: parent.width; height: 1; color: batPanel.root.sep }

            Rectangle {
                width: parent.width
                height: 28; radius: batPanel.buttonRadius
                color: btopMa.containsMouse ? batPanel.root.fillPrimaryHover : batPanel.root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                CommonComponents.UiText { anchors.centerIn: parent; text: "Open btop"; color: batPanel.root.paper; font.family: batPanel.root.mono; font.pixelSize: 11 }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { batPanel.root.batteryVisible = false; btopRunner.running = false; btopRunner.running = true }
                }
            }
        }
    }

    Process {
        id: batData
        command: ["python3", Qt.resolvedUrl("../scripts/rise-battery-status.py")]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var data
                try { data = JSON.parse(this.text) }
                catch (error) { return }
                if (!data || data.schema !== 1 || !Number.isFinite(Number(data.percentage))) return
                batPanel.batteryId = String(data.batteryId || "")
                batPanel.percent = Math.max(0, Math.min(100, Math.round(Number(data.percentage))))
                batPanel.status = String(data.status || "unknown")
                batPanel.timeLabel = String(data.timeLabel || "Time left")
                batPanel.timeText = String(data.timeText || "")
                batPanel.powerRate = String(data.powerRate || "")
                batPanel.sizeText = String(data.sizeText || "")
                batPanel.healthText = String(data.healthText || "")
                batPanel.cycles = Math.max(0, parseInt(data.cycles, 10) || 0)
            }
        }
    }

    Timer {
        interval: 5000
        running: batPanel.root.batteryVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: batPanel.refreshBatteryData()
    }

    Process { id: btopRunner; command: ["bash", "-c", "omarchy-launch-floating-terminal-with-presentation 'btop'"] }
}
