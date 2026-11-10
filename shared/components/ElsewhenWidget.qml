pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: widget
    required property var root
    required property color contentColor
    property var screen: null
    property real slotWidth: 28
    property real iconPixelSize: 14
    property string tooltipText: "World clock"
    property Component backgroundComponent

    Loader {
        anchors.centerIn: parent
        width: parent.width
        height: widget.root.pillH
        sourceComponent: widget.backgroundComponent
    }

    implicitWidth: widget.root.modElsewhen ? widget.slotWidth : 0
    implicitHeight: 28
    visible: implicitWidth > 0

    UiText {
        anchors.centerIn: parent
        text: "󰇧"
        font.family: widget.root.mono
        font.pixelSize: widget.iconPixelSize
        color: widget.contentColor
        objectName: "elsewhen-glyph"
    }

    TooltipMixin {
        id: tip
        root: widget.root
        owner: widget
        text: widget.tooltipText
    }

    MouseArea {
        anchors.fill: parent
        enabled: widget.visible
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: function(mouse) {
            tip.hide()
            if (mouse.button === Qt.LeftButton)
                if (widget.root.toggleElsewhen) widget.root.toggleElsewhen(widget.screen, widget)
                else widget.root.elsewhenVisible = !widget.root.elsewhenVisible
            else
                widget.root.refreshElsewhen()
        }
    }
}
