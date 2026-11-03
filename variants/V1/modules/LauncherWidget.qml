pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.LauncherWidget {
    id: widget
    contentColor: widget.root.seal
    archBrandTextColor: widget.root.barColorIsAccent ? widget.root.sealRaw : widget.root.accentHint
    frameColor: widget.root.pill
    frameBorderColor: widget.root.pillBorder
    frameBorderWidth: widget.root.pillBorderW
    frameRadius: widget.root.pillRadius
    drawShadow: widget.root.styleShadow
}
