import QtQuick

Item {
    id: rootMod
    required property var root
    readonly property color contentColor: rootMod.root.widgetContentColor("G16", rootMod.root.widgetIconColor)

    readonly property int temperature: rootMod.root.barTemperatureC
    readonly property string sourceLabel: rootMod.root.barTemperatureSourceLabel(rootMod.root.barTemperatureSource)
    readonly property string tooltipText: sourceLabel + " · " + temperature + "°C"

    visible: implicitWidth > 0.5
    implicitWidth: rootMod.root.modCpuTemperature && rootMod.root.barTemperatureAvailable
        ? row.implicitWidth + 18
        : 0
    implicitHeight: 28
    opacity: rootMod.root.modCpuTemperature && rootMod.root.barTemperatureAvailable ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: "" // Font Awesome thermometer-half (Nerd Font)
            color: rootMod.contentColor
            font.family: rootMod.root.mono
            font.pixelSize: 13
            font.weight: Font.Light
            font.hintingPreference: Font.PreferFullHinting
        }

        UiText {
            visible: !rootMod.root.iconOnly("G16")
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.temperature + "°"
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
        onClicked: { tip.hide(); rootMod.root.thermalVisible = !rootMod.root.thermalVisible }
    }
}
