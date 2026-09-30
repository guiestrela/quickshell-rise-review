import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    readonly property bool silenced: root.notifSilenced

    visible: silenced
    implicitWidth: silenced ? 20 : 0
    implicitHeight: 28


    readonly property string tooltipText: "Notifications silenced"

    IconText {
        anchors.centerIn: parent
        text: "\uE7F6"   // notifications_off
        color: root.seal
        font.pixelSize: 14
    }

    Process {
        id: toggleProc
        command: ["bash", "-c", "root=${OMARCHY_PATH:-/usr/share/omarchy}; if command -v omarchy-shell >/dev/null 2>&1 && [[ -f $root/shell/plugins/notifications/manifest.json ]] && OMARCHY_PATH=$root omarchy-shell notifications ping 2>/dev/null | grep -Fxq ok; then exec omarchy-shell notifications toggleDnd; fi; if command -v omarchy-toggle-notification-silencing >/dev/null 2>&1; then exec omarchy-toggle-notification-silencing; fi; exec omarchy toggle notification silencing"]
        onExited: root.refreshStatusIndicators()
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  { tip.hide() }
        onClicked: {
            tip.hide()
            toggleProc.running = false; toggleProc.running = true
        }
    }
}
