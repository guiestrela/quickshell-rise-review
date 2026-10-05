import QtQuick
import Quickshell

Item {
    id: control
    required property var root
    property var screen: null
    visible: root.modDisplayManager
    implicitWidth: root.modDisplayManager ? 36 : 0
    implicitHeight: 28
    readonly property color contentColor: root.widgetContentColor("G21", root.widgetIconColor)
    readonly property string tooltipText: "Display Manager · click to configure monitors"

    Text {
        anchors.centerIn: parent
        text: "󰍹"
        color: control.root.displayManagerVisible && !control.root.widgetHasFill("G21") ? control.root.seal : control.contentColor
        font.family: control.root.mono
        font.pixelSize: 14
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
