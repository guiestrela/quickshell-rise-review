pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.VoxtypeWidget {
    id: widget
    iconColor: widget.voiceState === "recording" ? widget.root.seal : widget.root.ink
}
