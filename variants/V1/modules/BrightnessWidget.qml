pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared
import "." as Native

Shared.BrightnessWidget {
    id: widget
    showPrefix: !(widget.root.barVertical === true || widget.root.compactBrightness)
    showValue: true
    rowSpacing: 5
    levelColor: widget.percent >= 100 ? widget.root.seal : Qt.rgba(widget.root.ink.r, widget.root.ink.g, widget.root.ink.b, 0.85)
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
