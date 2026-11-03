pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared
import "." as Native

Shared.NordVPNWidget {
    id: widget
    compactWidth: !widget.showLabel
    showLabel: !(widget.root.barVertical === true || widget.root.compactNordVpn)
    rowSpacing: widget.showLabel ? 4 : 0
    iconColor: widget.connected ? widget.root.seal : widget.root.sumi
    labelColor: widget.connected ? widget.root.seal : widget.root.sumi
    backgroundComponent: widget.root.barVertical === true ? null : pillBackground
    Component {
        id: pillBackground
        Rectangle {
            anchors.fill: parent
            radius: widget.root.pillRadius
            color: widget.root.fillIdle
            border.color: widget.root.pillBorder
            border.width: widget.root.pillBorderW
            Native.PillShadow { theme: widget.root }
        }
    }
}
