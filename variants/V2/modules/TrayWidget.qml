pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.TrayWidget {
    id: widget
    reserveHiddenColumns: true
    contentColor: widget.root.widgetContentColor("G3", widget.root.ink)
    badgeColor: widget.root.widgetHasFill("G3") ? widget.contentColor : widget.root.seal
    badgeTextColor: widget.root.widgetHasFill("G3") ? widget.root.widgetAssignedColor("G3") : widget.root.paper
    verticalLayout: widget.root.barVertical
    cellWidth: widget.root.v2ActionIconCellWidth
    toggleWidth: widget.root.v2ActionIconCellWidth
    cellSpacing: widget.root.v2IconClusterSpacing
}
