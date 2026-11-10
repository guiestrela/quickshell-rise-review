import QtQuick
import "../../../shared/logic/WallpaperManagerQuickWidgetLogic.js" as WallpaperManagerQuickWidgetLogic
import "../../../shared/components" as CommonComponents

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
    function handleButton(button) { return WallpaperManagerQuickWidgetLogic.handleButton(control, {tip: tip, Qt: Qt}, button) }

    CommonComponents.IconText {
        anchors.centerIn: parent
        text: "wallpaper"
        color: control.root.wallpaperManagerVisible
            && !control.root.widgetHasFill("G20")
            ? control.root.seal : control.contentColor
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    CommonComponents.TooltipMixin { id: tip; root: control.root; owner: control; text: control.tooltipText }
    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: !control.root.barUnlocked
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: function(mouse) { control.handleButton(mouse.button) }
    }
}
