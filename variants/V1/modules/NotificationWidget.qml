import QtQuick

Item {
    id: rootMod
    required property var root

    readonly property string tooltipText: rootMod.root.notifCount > 0
        ? (rootMod.root.notifCount + (rootMod.root.notifCount === 1 ? " notification" : " notifications"))
        : "No notifications"

    implicitWidth: 26
    implicitHeight: 28

    IconText {
        id: bellIcon
        anchors.centerIn: parent
        text: "\uE7F4"   // notifications (bell)
        font.pixelSize: 15
        color: rootMod.root.notifCount > 0
            ? rootMod.root.seal
            : Qt.rgba(rootMod.root.ink.r, rootMod.root.ink.g, rootMod.root.ink.b, 0.4)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // count badge — top-right, theme red with high-contrast text
    Rectangle {
        visible: rootMod.root.notifCount > 0
        width: Math.max(12, badgeTxt.implicitWidth + 6)
        height: 12
        radius: 6
        color: rootMod.root.seal
        anchors {
            verticalCenter: bellIcon.verticalCenter; verticalCenterOffset: -6
            horizontalCenter: bellIcon.horizontalCenter; horizontalCenterOffset: 7
        }
        Text {
            id: badgeTxt
            anchors.centerIn: parent
            text: rootMod.root.notifCount > 99 ? "99" : rootMod.root.notifCount
            color: rootMod.root.paper
            font.family: rootMod.root.mono
            font.pixelSize: 7
            font.weight: Font.Bold
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: { tip.hide() }
        onClicked: { tip.hide(); rootMod.root.notifVisible = !rootMod.root.notifVisible }
    }
}
