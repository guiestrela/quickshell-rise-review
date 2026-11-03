pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.ClaudeWidget {
    id: widget
    verticalCompact: false
    showUsageLabel: !widget.root.iconOnly("G7")
    baseColor: widget.root.widgetContentColor("G7", widget.root.widgetIconColor)
    fillColor: widget.baseColor
    usageColor: widget.baseColor
}
