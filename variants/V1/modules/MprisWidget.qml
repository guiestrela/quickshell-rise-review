pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared
import "." as Native

Shared.MprisWidget {
    id: widget
    fullMode: widget.root.compactMpris
    contentColor: widget.root.ink
    accentColor: widget.root.seal
    titleColor: Qt.rgba(widget.root.ink.r, widget.root.ink.g, widget.root.ink.b, widget.playing ? 0.85 : 0.4)
    verticalFullHeight: 160
    showMarquee: widget.root.barVertical !== true
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
