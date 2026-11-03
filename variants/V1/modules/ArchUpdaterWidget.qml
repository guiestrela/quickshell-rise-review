pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.ArchUpdaterWidget {
    id: widget
    iconColor: widget.refreshing ? widget.root.sumi : (widget.hasNotice ? widget.root.seal : Qt.rgba(widget.root.ink.r, widget.root.ink.g, widget.root.ink.b, 0.4))
    badgeColor: widget.root.seal
    badgeTextColor: widget.root.paper
}
