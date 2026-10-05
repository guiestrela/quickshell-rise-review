import QtQuick
import Quickshell

Item {
    id: control
    required property var root
    property var screen: null
    visible: implicitWidth > 0.5
    implicitWidth: root.modDisplayManager ? icon.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: root.modDisplayManager ? 1 : 0
    readonly property string tooltipText: "Display Manager · click to configure monitors"
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Rectangle {
        objectName: "display-widget-pill"
        anchors.centerIn: parent
        width: control.width
        height: control.root.pillH
        radius: control.root.pillRadius
        color: control.root.pill
        border.color: control.root.pillBorder
        border.width: control.root.pillBorderW
        PillShadow { theme: control.root }
    }
    IconText {
        id: icon
        objectName: "display-widget-icon"
        anchors.centerIn: parent
        text: "desktop_windows"
        color: control.root.displayManagerVisible ? control.root.seal : control.root.ink
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    TooltipMixin { id: tip; root: control.root; owner: control; text: control.tooltipText }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: control.root.toggleDisplayManager(control.screen, control)
    }
}
