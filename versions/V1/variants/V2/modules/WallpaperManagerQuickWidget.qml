import QtQuick

Item {
    id: control
    required property var root
    property var screen: null
    property alias testMouseArea: clickArea
    visible: control.root.modWallpapers
    implicitWidth: control.root.modWallpapers ? 38 : 0
    implicitHeight: 28
    readonly property color contentColor: root.widgetContentColor("G20", root.widgetIconColor)
    readonly property color widgetFill: root.widgetFillColor("G20")
    readonly property string tooltipText: "Wallpaper manager · click to open · middle-click for next on all displays"
    function handleButton(button) {
        tip.hide()
        if (button === Qt.MiddleButton) control.root.wallpaperManagerServiceApi.nextAll()
        else control.root.toggleWallpaperManager(control.screen, control)
    }

    Rectangle {
        anchors.centerIn: parent
        width: control.width
        height: control.root.pillH
        radius: control.root.pillRadius
        color: control.root.widgetHasFill("G20") ? control.widgetFill : control.root.pill
        border.color: control.root.widgetBorderColor("G20")
        border.width: control.root.widgetHasBorder("G20") ? control.root.panelBorderW : 0
    }
    Text {
        anchors.centerIn: parent
        text: "󰸉"
        color: control.root.wallpaperManagerVisible ? control.root.seal : control.contentColor
        font.family: control.root.mono
        font.pixelSize: 14
        renderType: Text.QtRendering
    }
    TooltipMixin { id: tip; root: control.root; owner: control; text: control.tooltipText }
    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: function(mouse) { control.handleButton(mouse.button) }
    }
}
