pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.NordVPNWidget {
    id: widget
    contentColor: widget.root.widgetContentColor("G19", widget.connected ? widget.root.seal : widget.root.ink)
    compactWidth: false
    showLabel: !widget.root.iconOnly("G19")
    rowSpacing: 4
    iconColor: widget.connected ? widget.contentColor : Qt.rgba(widget.contentColor.r, widget.contentColor.g, widget.contentColor.b, 0.3)
    labelColor: widget.contentColor
}
