import QtQuick
import "../../../shared/components" as Shared

Shared.CpuTemperatureWidget {
    id: widget
    contentColor: widget.root.widgetContentColor("G16", widget.root.widgetIconColor)
    compact: widget.root.iconOnly("G16")
}
