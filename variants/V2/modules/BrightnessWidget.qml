pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.BrightnessWidget {
    id: widget
    showPrefix: false
    showValue: !widget.root.iconOnly("G13")
    rowSpacing: 4
    levelColor: widget.percent >= 100 && !widget.root.widgetHasFill("G13") ? widget.root.seal : widget.root.widgetContentColor("G13", widget.root.ink)
}
