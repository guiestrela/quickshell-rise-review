pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared
import "." as Native

Shared.OneDriveWidget {
    id: widget
    contentColor: widget.root.seal
    slotWidth: 28
    iconPixelSize: 11
    showStatusBadge: false
    backgroundComponent: widget.root.barVertical === true ? null : pillBackground
    Component {
        id: pillBackground
        Rectangle {
            width: parent.width
            anchors.fill: parent
            radius: widget.root.pillRadius
            color: widget.root.fillIdle
            border.color: widget.root.pillBorder
            border.width: widget.root.pillBorderW
            Native.PillShadow { theme: widget.root }
        }
    }
}
