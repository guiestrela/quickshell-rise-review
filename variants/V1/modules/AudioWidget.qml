import QtQuick
import "../../../shared/logic/AudioWidgetLogic.js" as AudioWidgetLogic
import Quickshell.Io
import "../../../shared/services" as CommonServices
import "../../../shared/components" as CommonComponents

Item {
    id: rootMod
    required property var root
    readonly property bool verticalCompact: root.barVertical === true || root.compactVolume

    CommonServices.AudioData { id: audio; poll: true }
    readonly property int    volume:   audio.volume
    readonly property bool   muted:    audio.muted
    readonly property string compactVolumeIcon: "graphic_eq"

    readonly property string tooltipText: muted
        ? "Muted · " + volume + "%"
        : "Audio " + volume + "%"

    visible: implicitWidth > 0.5
    implicitWidth: root.modVolume ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: root.modVolume ? 1 : 0
    Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: rootMod.root.pillH
        radius: rootMod.root.pillRadius
        color: rootMod.root.pill
        border.color: rootMod.root.pillBorder
        border.width: rootMod.root.pillBorderW
        PillShadow { theme: rootMod.root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: rootMod.verticalCompact ? 4 : 5

        CommonComponents.UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !rootMod.verticalCompact
            text: "VOL"
            color: rootMod.muted
                ? Qt.rgba(rootMod.root.ink.r, rootMod.root.ink.g, rootMod.root.ink.b, 0.25)
                : Qt.rgba(rootMod.root.ink.r, rootMod.root.ink.g, rootMod.root.ink.b, 0.6)
            font.family: rootMod.root.mono
            font.pixelSize: 12
            font.letterSpacing: 0.5
        }

        // ── workspace-capsule style slider ──
        Item {
            id: slider
            visible: !rootMod.verticalCompact
            width: 34
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            readonly property real ratio: rootMod.muted ? 0 : Math.min(rootMod.volume / 100, 1)

            // track capsule
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 8
                radius: 4
                color: Qt.rgba(rootMod.root.ink.r, rootMod.root.ink.g, rootMod.root.ink.b, 0.18)
            }

            // fill capsule — seal pill like the active workspace
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(slider.ratio > 0 ? 8 : 0, parent.width * slider.ratio)
                height: 8
                radius: 4
                color: rootMod.root.seal
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }

        CommonComponents.UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: rootMod.root.barVertical !== true && (!rootMod.verticalCompact)
            text: String(rootMod.volume).padStart(2, '0') + "%"
            color: rootMod.muted
                ? Qt.rgba(rootMod.root.seal.r, rootMod.root.seal.g, rootMod.root.seal.b, 0.35)
                : rootMod.root.seal
            font.family: rootMod.root.mono
            font.pixelSize: 12
        }

        CommonComponents.IconText {
            id: compactVolumeGlyph
            anchors.verticalCenter: parent.verticalCenter
            visible: rootMod.verticalCompact
            text: rootMod.compactVolumeIcon
            color: rootMod.muted ? Qt.rgba(rootMod.root.ink.r, rootMod.root.ink.g, rootMod.root.ink.b, 0.35) : rootMod.root.seal
            font.pixelSize: 15
            font.weight: Font.Medium
            fill: 1
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        CommonComponents.UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: rootMod.root.barVertical !== true && rootMod.verticalCompact
            text: String(rootMod.volume).padStart(2, '0') + "%"
            color: rootMod.muted
                ? Qt.rgba(rootMod.root.seal.r, rootMod.root.seal.g, rootMod.root.seal.b, 0.35)
                : rootMod.root.seal
            font.family: rootMod.root.mono
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 160 } }
        }

    }

    CommonComponents.TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    property bool audioErrorNotified: false
    property int pendingVolumeSteps: 0

    readonly property string muteCommand:
        "if command -v omarchy-audio-output-volume >/dev/null 2>&1; then " +
        "omarchy-audio-output-volume mute-toggle; else " +
        "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle || pamixer -t; fi"

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
