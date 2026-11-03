pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared
import "." as Native

Shared.CpuTemperatureWidget {
    id: widget
    contentColor: widget.root.seal
    compact: widget.root.barVertical === true || widget.root.compactTemperature
    backgroundComponent: widget.root.barVertical === true ? null : pillBackground
    Component {
        id: pillBackground
        Rectangle {
            width: parent.width
            height: widget.root.pillH
            anchors.verticalCenter: parent.verticalCenter
            radius: widget.root.pillRadius
            color: widget.root.pill
            border.color: widget.root.pillBorder
            border.width: widget.root.pillBorderW
            Native.PillShadow { theme: widget.root }
        }
    }
}
