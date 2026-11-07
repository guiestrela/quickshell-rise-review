import QtQuick
import "../../../shared/components" as Shared

Item {
    id: module
    required property var root
    readonly property bool vertical: root.barVertical
    implicitWidth: !root.modIndicators ? 0 : (vertical ? 28 : Math.max(24, indicators.implicitWidth + 12))
    implicitHeight: !root.modIndicators ? 0 : (vertical ? Math.max(28, indicators.implicitHeight) : 28)
    visible: root.modIndicators

    HoverHandler { id: reveal }

    Rectangle {
        visible: !module.vertical && module.root.modIndicators
        anchors.centerIn: parent
        width: parent.implicitWidth
        height: module.root.pillH
        radius: module.root.pillRadius
        color: module.root.pill
        border.color: module.root.pillBorder
        border.width: module.root.pillBorderW
        PillShadow { theme: module.root }
    }

    Shared.IndicatorsWidget {
        id: indicators
        objectName: "indicators-active-group"
        width: indicators.implicitWidth
        height: indicators.implicitHeight
        anchors.centerIn: parent
        root: module.root
        coordinator: module.root.omarchyIndicators
        contentColor: module.root.seal
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
        color: module.root.seal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: module.root.modIndicators && !indicators.hasActive && !indicators.revealed
    }
}
