import QtQuick
import "../../../shared/components" as Shared

Item {
    id: module
    required property var root
    readonly property bool vertical: root.barVertical
    implicitWidth: !root.modIndicators ? 0 : (vertical ? 28 : Math.max(16, indicators.implicitWidth))
    implicitHeight: !root.modIndicators ? 0 : (vertical ? Math.max(28, indicators.implicitHeight) : 28)
    visible: root.modIndicators

    HoverHandler { id: reveal }

    Shared.IndicatorsWidget {
        id: indicators
        objectName: "indicators-active-group"
        width: indicators.implicitWidth
        height: indicators.implicitHeight
        anchors.centerIn: parent
        root: module.root
        coordinator: module.root.omarchyIndicators
        contentColor: module.root.widgetContentColor("G23", module.root.widgetIconColor)
        vertical: module.vertical
        revealInactive: reveal.hovered
    }

    Text {
        objectName: "indicators-empty-marker"
        anchors.centerIn: parent
        text: ">"
        textFormat: Text.PlainText
        transformOrigin: Item.Center
        rotation: module.vertical ? 90 : 0
        font.family: module.root.mono
        font.pixelSize: 13
        color: module.root.widgetContentColor("G23", module.root.widgetIconColor)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: module.root.modIndicators && !indicators.hasActive && !indicators.revealed
    }
}
