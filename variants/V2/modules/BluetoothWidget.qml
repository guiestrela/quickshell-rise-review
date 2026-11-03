pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.BluetoothWidget {
    id: widget
    contentColor: widget.root.widgetContentColor("G15", widget.root.ink)
    showPrefix: false
    showCount: !widget.root.iconOnly("G15")
    rowSpacing: 4
    iconColor: widget.connected ? (widget.root.widgetHasFill("G15") ? widget.contentColor : widget.root.seal) : Qt.rgba(widget.contentColor.r, widget.contentColor.g, widget.contentColor.b, widget.btOn ? 0.7 : 0.3)
    countColor: widget.root.widgetHasFill("G15") ? widget.contentColor : widget.root.seal
}
