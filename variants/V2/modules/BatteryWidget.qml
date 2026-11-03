pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.BatteryWidget {
    id: widget
    showPrefix: false
    showValue: !widget.root.iconOnly("G12")
    rowSpacing: 4
    battColor: widget.root.widgetHasFill("G12") ? widget.root.widgetContentColor("G12", widget.root.ink) : ((widget.charging || widget.full) ? widget.root.indigo : widget.root.seal)
    chargingTintColor: widget.battColor
    boltColor: widget.root.widgetHasFill("G12") ? widget.root.widgetAssignedColor("G12") : widget.root.paper
}
