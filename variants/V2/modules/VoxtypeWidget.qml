pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.VoxtypeWidget {
    id: widget
    iconColor: widget.root.widgetHasFill("G8") ? widget.root.widgetContentColor("G8", widget.root.ink) : (widget.voiceState === "recording" ? widget.root.seal : widget.root.ink)
}
