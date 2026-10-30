import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root
    readonly property color contentColor: rootMod.root.widgetContentColor("G8", rootMod.root.ink)

    readonly property string voiceState: rootMod.root.voxState   // idle | recording | transcribing
    readonly property string hint:  rootMod.root.voxHint
    readonly property bool   hasVoxtype: rootMod.root.voxAvailable

    readonly property string displayIcon: {
        if (voiceState === "recording")    return "\uE029"   // mic
        if (voiceState === "transcribing") return "\uE65F"   // auto_awesome
        return ""
    }

    visible: displayIcon !== ""
    implicitWidth: visible ? 20 : 0
    implicitHeight: 28


    readonly property string tooltipText: hint !== "" ? hint : (voiceState === "recording" ? "Voxtype recording" : "Voxtype transcribing")

    IconText {
        id: ico
        anchors.centerIn: parent
        text: rootMod.displayIcon
        color: rootMod.root.widgetHasFill("G8")
            ? rootMod.contentColor
            : (rootMod.voiceState === "recording" ? rootMod.root.seal : rootMod.root.ink)
        font.pixelSize: 14

        // pulse while recording
        SequentialAnimation on opacity {
            running: rootMod.voiceState === "recording"
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
        }
        onTextChanged: if (rootMod.voiceState !== "recording") opacity = 1.0
    }

    Process { id: modelProc;  command: ["bash", "-c", "omarchy-voxtype-model"] }
    Process { id: configProc; command: ["bash", "-c", "omarchy-voxtype-config"] }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited:  { tip.hide() }
        onClicked: (e) => {
            tip.hide()
            if (e.button === Qt.RightButton) { configProc.running = false; configProc.running = true }
            else                             { modelProc.running = false;  modelProc.running = true }
        }
    }
}
