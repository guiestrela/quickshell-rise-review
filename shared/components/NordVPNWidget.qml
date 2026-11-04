import QtQuick
import "../logic/NordVPNWidgetLogic.js" as NordVPNWidgetLogic
import "../components" as CommonComponents

// NordVPN pill: shield glyph (Material Design, verified present in the theme
// font JetBrainsMono Nerd Font) + short state label. nordVpnStatusText and
// activate() are kept because the isolated harness asserts on them.
Item {
    id: nordVpnWidget
    property color contentColor: nordVpnWidget.root.ink
    required property var root
    required property bool compactWidth
    required property bool showLabel
    required property real rowSpacing
    required property color iconColor
    required property color labelColor
    property Component backgroundComponent

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

    readonly property string tooltipText: connected ? "NordVPN connected"
        : disconnected ? "NordVPN disconnected"
        : unavailable ? "NordVPN unavailable" : "NordVPN status checking"

    implicitWidth: root.modNordVpn
        ? (nordVpnWidget.compactWidth ? shield.implicitWidth : row.implicitWidth) + 18 : 0
    visible: implicitWidth > 0.5
    implicitHeight: 28
    property alias testClickHandler: widgetClick

    function activate() { return NordVPNWidgetLogic.activate(nordVpnWidget, {root: root}) }

    Loader {
        anchors.centerIn: parent
        width: Math.round(row.width) + 18
        height: nordVpnWidget.root.pillH
        sourceComponent: nordVpnWidget.backgroundComponent
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: nordVpnWidget.rowSpacing

        CommonComponents.UiText {
            id: shield
            anchors.verticalCenter: parent.verticalCenter
            text: nordVpnWidget.shieldGlyph
            color: nordVpnWidget.iconColor
            font.family: nordVpnWidget.root.mono
            font.pixelSize: 13
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Item {
            visible: nordVpnWidget.showLabel
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: nordVpnWidget.showLabel ? label.implicitWidth : 0
            implicitHeight: label.implicitHeight
            Text {
                id: label
                anchors.centerIn: parent
                visible: nordVpnWidget.showLabel
                text: nordVpnWidget.shortLabel
                color: nordVpnWidget.labelColor
                font.family: nordVpnWidget.root.mono
                font.pixelSize: 11
                font.letterSpacing: 0.5
                Behavior on color { ColorAnimation { duration: 200 } }
            }
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

    CommonComponents.TooltipMixin { id: tip; root: nordVpnWidget.root; owner: nordVpnWidget; text: nordVpnWidget.tooltipText }
}
