pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.MprisWidget {
    id: widget
    fullMode: widget.root.mprisBarStyle === "full"
    contentColor: widget.root.widgetContentColor("G9", widget.root.ink)
    accentColor: widget.root.widgetHasFill("G9") ? widget.contentColor : widget.root.seal
    titleColor: widget.contentColor
    verticalFullHeight: 144
    showMarquee: true
}
