pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared
import "." as Native

Shared.BatteryWidget {
    id: widget
    showPrefix: !(widget.root.barVertical === true || widget.root.compactBattery)
    showValue: true
    rowSpacing: 5
    battColor: (widget.charging || widget.full) ? widget.root.indigo : widget.root.seal
    chargingTintColor: widget.root.indigo
    boltColor: widget.root.paper
    backgroundComponent: widget.root.barVertical === true ? null : pillBackground
    Component {
        id: pillBackground
        Rectangle {
            anchors.fill: parent
            radius: widget.root.pillRadius
            color: widget.root.pill
            border.color: widget.root.pillBorder
            border.width: widget.root.pillBorderW
            Native.PillShadow { theme: widget.root }
        }
    }
}
