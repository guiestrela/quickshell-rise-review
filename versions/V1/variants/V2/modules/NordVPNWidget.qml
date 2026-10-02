import QtQuick

// NordVPN pill: shield glyph (Material Design, verified present in the theme
// font JetBrainsMono Nerd Font) + short state label. nordVpnStatusText and
// activate() are kept because the isolated harness asserts on them.
Item {
    id: nordVpnWidget
    required property var root

    readonly property bool connected:    root.nordVpnStatus === "Connected"
    readonly property bool disconnected: root.nordVpnStatus === "Disconnected"
    readonly property bool unavailable:   root.nordVpnStatus === "Unavailable"

    readonly property string nordVpnStatusText: {
        if (connected) return "NordVPN ON"
        if (disconnected) return "NordVPN OFF"
        if (unavailable) return "NordVPN N/A"
        return "NordVPN …"
    }

    readonly property string shortLabel: {
        if (connected) return "ON"
        if (disconnected) return "OFF"
        if (unavailable) return "N/A"
        return "VPN"
    }

    readonly property string shieldGlyph: {
        if (connected) return String.fromCodePoint(0xF0565)    // md-shield_check
        if (disconnected) return String.fromCodePoint(0xF099E)    // md-shield_off
        if (unavailable) return String.fromCodePoint(0xF0ECC)    // md-shield_alert
        return String.fromCodePoint(0xF099D)    // md-shield_lock
    }

    readonly property color shieldColor: connected ? root.seal : root.ink
    readonly property color contentColor: root.widgetContentColor("G19", shieldColor)
    readonly property color widgetFill: root.widgetFillColor("G19")
    readonly property string tooltipText: connected ? "NordVPN connected"
        : disconnected ? "NordVPN disconnected"
        : unavailable ? "NordVPN unavailable" : "NordVPN status checking"

    implicitWidth: root.modNordVpn ? row.implicitWidth + 18 : 0
    visible: implicitWidth > 0.5
    implicitHeight: 28
    property alias testClickHandler: widgetClick

    function activate() {
        var point = nordVpnWidget.mapToItem(null, nordVpnWidget.width / 2, 0)
        root.setPanelAnchor("vpn", point.x, root.activePopupScreenName)
        root.vpnVisible = true
    }

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: 22
        radius: nordVpnWidget.root.pillRadius
        color: nordVpnWidget.root.widgetHasFill("G19")
            ? nordVpnWidget.widgetFill : nordVpnWidget.root.pill
        border.color: nordVpnWidget.root.widgetBorderColor("G19")
        border.width: nordVpnWidget.root.widgetHasBorder("G19")
            ? nordVpnWidget.root.panelBorderW : 0
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: nordVpnWidget.shieldGlyph
            color: nordVpnWidget.contentColor
            font.family: nordVpnWidget.root.mono
            font.pixelSize: 13
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !nordVpnWidget.root.iconOnly("G19")
            text: nordVpnWidget.shortLabel
            color: nordVpnWidget.contentColor
            font.family: nordVpnWidget.root.mono
            font.pixelSize: 11
            font.letterSpacing: 0.5
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    MouseArea {
        id: widgetClick
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: nordVpnWidget.activate()
    }

    TooltipMixin { id: tip; root: nordVpnWidget.root; owner: nordVpnWidget; text: nordVpnWidget.tooltipText }
}
