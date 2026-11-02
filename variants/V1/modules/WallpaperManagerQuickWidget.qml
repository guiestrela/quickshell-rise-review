import QtQuick
import "../../../shared/logic/WallpaperManagerQuickWidgetLogic.js" as WallpaperManagerQuickWidgetLogic
import "../../../shared/components" as CommonComponents

Item {
    id: control
    required property var root
    property var screen: null
    property alias testMouseArea: clickArea
    visible: control.root.modWallpapers
    implicitWidth: control.root.modWallpapers ? 38 : 0
    implicitHeight: 28
    readonly property string tooltipText: "Wallpaper manager · click to open · middle-click for next on all displays"
    function handleButton(button) { return WallpaperManagerQuickWidgetLogic.handleButton(control, {tip: tip, Qt: Qt}, button) }

    Rectangle {
        anchors.centerIn: parent
        width: control.width
        height: control.root.pillH
        radius: control.root.pillRadius
        color: control.root.pill
        border.color: control.root.pillBorder
        border.width: control.root.pillBorderW
        PillShadow { theme: control.root }
    }
    CommonComponents.IconText {
        anchors.centerIn: parent
        text: "wallpaper"
        color: control.root.wallpaperManagerVisible ? control.root.seal : control.root.ink
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    CommonComponents.TooltipMixin { id: tip; root: control.root; owner: control; text: control.tooltipText }
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
