import QtQuick

Item {
    id: control
    required property var root
    property var screen: null
    property alias testMouseArea: clickArea
    visible: control.root.modWallpapers
    implicitWidth: control.root.modWallpapers ? 36 : 0
    implicitHeight: 28
    readonly property color contentColor: root.widgetContentColor("G20", root.widgetIconColor)
    readonly property string tooltipText: "Wallpaper manager · click to open · middle-click for next on all displays"
    function handleButton(button) {
        tip.hide()
        if (button === Qt.MiddleButton) control.root.wallpaperManagerServiceApi.nextAll()
        else control.root.toggleWallpaperManager(control.screen, control)
    }

    IconText {
        anchors.centerIn: parent
        text: "wallpaper"
        color: control.root.wallpaperManagerVisible
            && !control.root.widgetHasFill("G20")
            ? control.root.seal : control.contentColor
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 150 } }
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
