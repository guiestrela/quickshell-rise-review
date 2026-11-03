pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared
import "." as Native

Shared.BluetoothWidget {
    id: widget
    showPrefix: !(widget.root.barVertical === true || widget.root.compactBluetooth)
    showCount: widget.root.barVertical !== true
    rowSpacing: 5
    iconColor: widget.connected ? widget.root.seal : Qt.rgba(widget.root.ink.r, widget.root.ink.g, widget.root.ink.b, widget.btOn ? 0.7 : 0.3)
    countColor: widget.root.seal
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
