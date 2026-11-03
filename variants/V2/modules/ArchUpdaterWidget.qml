pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.ArchUpdaterWidget {
    id: widget
    contentColor: widget.root.widgetContentColor(widget.colorGid, widget.root.ink)
    iconColor: widget.refreshing ? widget.contentColor : (widget.hasNotice && !widget.root.widgetHasFill(widget.colorGid) ? widget.root.seal : Qt.rgba(widget.contentColor.r, widget.contentColor.g, widget.contentColor.b, widget.hasNotice ? 1.0 : 0.4))
    badgeColor: widget.root.widgetHasFill(widget.colorGid) ? widget.contentColor : widget.root.seal
    badgeTextColor: widget.root.widgetHasFill(widget.colorGid) ? widget.root.widgetAssignedColor(widget.colorGid) : widget.root.paper
}
