import QtQuick
import "../../../shared/components" as Shared

Shared.StorageWidget {
    id: widget
    contentColor: widget.root.widgetContentColor("G18", widget.root.widgetIconColor)
    compact: widget.root.iconOnly("G18")
}
