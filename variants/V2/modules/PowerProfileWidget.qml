import QtQuick
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    property string profile: rootMod.root.powerProfileCurrent

    readonly property bool isPowerSaver:  profile === "power-saver"
    readonly property bool isBalanced:    profile === "balanced"
    readonly property bool isPerformance: profile === "performance"

    readonly property string profileIcon: {
        if (isPowerSaver)  return "\uF06C"
        if (isPerformance) return "\uF0E7"
        return "\uF24E"
    }

    readonly property color profileColor: {
        if (rootMod.root.widgetHasFill("G14")) return rootMod.root.widgetContrastColor("G14")
        if (isPowerSaver)  return rootMod.root.indigo
        if (isPerformance) return rootMod.root.seal
        return rootMod.root.seal
    }

    readonly property string tooltipText: {
        if (isPowerSaver)  return "Power Saver"
        if (isPerformance) return "Performance"
        return "Balanced"
    }

    visible: implicitWidth > 0.5
    implicitWidth: rootMod.root.modPower ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: rootMod.root.modPower ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.profileIcon
            renderType: Text.QtRendering
            color: rootMod.profileColor
            font.family: rootMod.root.mono
            font.pixelSize: rootMod.isBalanced ? 13 : 14
            Behavior on color { ColorAnimation { duration: 200 } }
        }

    }

    Process {
        id: profileProc
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo balanced"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim()
                if (p) { rootMod.profile = p; rootMod.root.powerProfileCurrent = p }
            }
        }
    }

    Timer {
        interval: 5000; running: rootMod.root.modPower || rootMod.root.powerProfileVisible; repeat: true; triggeredOnStart: true
        onTriggered: { profileProc.running = false; profileProc.running = true }
    }

    Process {
        id: setProfileProc
        command: ["bash", "-c", "powerprofilesctl set balanced"]
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited: { tip.hide() }
        onClicked: (e) => {
            tip.hide()
            if (e.button === Qt.RightButton) {
                const profiles = ["power-saver", "balanced", "performance"]
                const idx = profiles.indexOf(rootMod.root.powerProfileCurrent)
                const next = profiles[(Math.max(0, idx) + 1) % profiles.length]
                setProfileProc.command = ["bash", "-c", "powerprofilesctl set " + next]
                setProfileProc.running = false; setProfileProc.running = true
                rootMod.root.powerProfileCurrent = next
            } else {
                rootMod.root.powerProfileVisible = !rootMod.root.powerProfileVisible
            }
        }
    }
}
