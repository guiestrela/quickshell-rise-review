import QtQuick
import "../../../shared/logic/AudioWidgetLogic.js" as AudioWidgetLogic
import Quickshell.Io
import "../../../shared/services" as CommonServices
import "../../../shared/components" as CommonComponents

Item {
    id: rootMod
    required property var root

    CommonServices.AudioData { id: audio; poll: true }
    readonly property int    volume:   audio.volume
    readonly property bool   muted:    audio.muted
    readonly property string volumeIcon: "graphic_eq"
    readonly property color contentColor: root.widgetContentColor("G6", root.widgetIconColor)

    readonly property string tooltipText: muted
        ? "Muted · " + volume + "%"
        : "Audio " + volume + "%"

    visible: implicitWidth > 0.5
    implicitWidth: root.modVolume ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: root.modVolume ? 1 : 0
    Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        CommonComponents.IconText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.volumeIcon
            color: rootMod.muted
                ? Qt.rgba(rootMod.contentColor.r, rootMod.contentColor.g, rootMod.contentColor.b, 0.35)
                : rootMod.contentColor
            font.pixelSize: 15
            font.weight: Font.Medium
            fill: 1
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        CommonComponents.UiText {
            visible: !rootMod.root.iconOnly("G6")
            anchors.verticalCenter: parent.verticalCenter
            text: String(rootMod.volume).padStart(2, '0') + "%"
            color: rootMod.muted
                ? Qt.rgba(rootMod.contentColor.r, rootMod.contentColor.g, rootMod.contentColor.b, 0.35)
                : rootMod.contentColor
            font.family: rootMod.root.mono
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 160 } }
        }

    }

    CommonComponents.TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    property bool audioErrorNotified: false
    property int pendingVolumeSteps: 0

    readonly property string muteCommand:
        "(command -v omarchy-swayosd-client >/dev/null 2>&1 && omarchy-swayosd-client --output-volume mute-toggle) || " +
        "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle || " +
        "pamixer -t"

    function volumeCommand(steps) { return AudioWidgetLogic.volumeCommand(rootMod, {}, steps) }

    function runPendingVolumeCommand() { return AudioWidgetLogic.runPendingVolumeCommand(rootMod, {volumeRunner: volumeRunner}) }

    function queueVolumeStep(step) { return AudioWidgetLogic.queueVolumeStep(rootMod, {}, step) }

    function notifyAudioError(action, exitCode) { return AudioWidgetLogic.notifyAudioError(rootMod, {audioErrNotify: audioErrNotify}, action, exitCode) }

    Process { id: audioErrNotify }
    Process {
        id: muteRunner
        command: ["bash", "-c", rootMod.muteCommand]
        onExited: (code) => {
            rootMod.notifyAudioError("Mute", code)
            audio.refresh()
        }
    }
    Process {
        id: volumeRunner
        property string action: ""
        onExited: (code) => {
            rootMod.notifyAudioError(action, code)
            audio.refresh()
            rootMod.runPendingVolumeCommand()
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited: { tip.hide() }
        onWheel: (e) => {
            rootMod.queueVolumeStep(e.angleDelta.y > 0 ? 1 : -1)
        }
        onClicked: (e) => {
            tip.hide()
            if (e.button === Qt.RightButton) { if (!muteRunner.running) muteRunner.running = true }
            else                             { rootMod.root.volVisible = !rootMod.root.volVisible }
        }
    }
}
