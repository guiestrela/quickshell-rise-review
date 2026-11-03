pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.TrayWidget {
    id: widget
    reserveHiddenColumns: false
    contentColor: widget.root.ink
    badgeColor: widget.root.seal
    badgeTextColor: widget.root.paper
    verticalLayout: false
    cellWidth: 18
    toggleWidth: 22
    cellSpacing: 2
}
