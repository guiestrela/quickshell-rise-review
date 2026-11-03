pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.LauncherWidget {
    id: widget
    contentColor: widget.root.widgetContentColor("G1", widget.root.seal)
    archBrandTextColor: widget.root.widgetHasFill("G1") ? widget.contentColor : (widget.root.barColorIsAccent ? widget.root.sealRaw : widget.root.accentHint)
    frameColor: "transparent"
    frameBorderColor: "transparent"
    frameBorderWidth: 0
    frameRadius: 0
    drawShadow: false
}
