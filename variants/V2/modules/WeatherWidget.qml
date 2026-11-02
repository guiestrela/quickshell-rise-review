import QtQuick
import "../../../shared/components" as Shared
Shared.WeatherWidget {
    id: widget
    contentColor: widget.root.widgetContentColor("G8", widget.root.ink)
    loadingGlyph: widget.root.barVertical ? "☁" : "·"
}
