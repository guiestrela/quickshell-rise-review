pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared
import "." as Native

Shared.WallpaperWidget {
    id: widget
    openColor: widget.root.widgetContentColor("G20", widget.root.widgetIconColor)
    nextColor: widget.root.widgetContentColor("G20", widget.root.widgetIconColor)
    backgroundComponent: pillBackground
    Component {
        id: pillBackground
        Rectangle {
            anchors.fill: parent
            radius: widget.root.pillRadius
            color: widget.root.pill
            border.color: "transparent"
            border.width: widget.root.pillBorderW
            Native.PillShadow { theme: widget.root }
        }
    }
}
