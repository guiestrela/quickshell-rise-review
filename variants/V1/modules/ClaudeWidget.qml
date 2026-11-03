pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared
import "." as Native

Shared.ClaudeWidget {
    id: widget
    verticalCompact: widget.root.barVertical === true || widget.root.compactAi
    showUsageLabel: !widget.verticalCompact
    baseColor: widget.root.ink
    fillColor: widget.root.seal
    usageColor: widget.blocked ? widget.root.seal : Qt.rgba(widget.root.ink.r, widget.root.ink.g, widget.root.ink.b, 0.85)
    backgroundComponent: widget.root.barVertical === true ? null : pillBackground
    Component {
        id: pillBackground
        Rectangle {
            anchors.fill: parent
            radius: widget.root.pillRadius
            color: widget.root.pill
            border.color: widget.root.pillBorder
            border.width: widget.root.pillBorderW
            Native.PillShadow { theme: widget.root }
        }
    }
}
