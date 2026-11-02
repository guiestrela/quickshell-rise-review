import QtQuick

Item {
    id: rootMod
    required property var root
    readonly property color contentColor: rootMod.root.widgetContentColor("G18", rootMod.root.widgetIconColor)

    readonly property int percent: rootMod.root.storagePercent
    readonly property string tooltipText: "Root filesystem · " + percent + "% · "
        + rootMod.root.storageUsedGiB.toFixed(1) + "/" + rootMod.root.storageTotalGiB.toFixed(1) + " GiB"

    visible: implicitWidth > 0.5
    implicitWidth: rootMod.root.modStorage && rootMod.root.storageAvailable ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: rootMod.root.modStorage && rootMod.root.storageAvailable ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            width: 15
            text: "󰋊"
            color: rootMod.contentColor
            font.family: rootMod.root.mono
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
        }

        UiText {
            visible: !rootMod.root.iconOnly("G18")
            anchors.verticalCenter: parent.verticalCenter
            text: String(Math.min(100, rootMod.percent)).padStart(2, "0") + "%"
            color: rootMod.contentColor
            font.family: rootMod.root.mono
            font.pixelSize: 12
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: { tip.hide(); rootMod.root.storageVisible = !rootMod.root.storageVisible }
    }
}
