pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared
import "." as Native

Shared.PowerProfileWidget {
    id: widget
    showPrefix: !(widget.root.barVertical === true || widget.root.compactPower)
    showIcon: widget.root.barVertical === true || widget.root.compactPower
    showShortName: !(widget.root.barVertical === true || widget.root.compactPower)
    rowSpacing: 5
    profileColor: widget.isPowerSaver ? widget.root.indigo : widget.root.seal
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
