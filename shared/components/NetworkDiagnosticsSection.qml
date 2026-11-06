pragma ComponentBehavior: Bound
import QtQuick
import "../services" as Services

Column {
    id: section
    required property var theme
    property bool panelOpen: false
    property string networkMode: "none"
    property string connectivity: "unknown"
    readonly property string displayedConnectivity: connectivity === "limited"
        && diagnostics.lastInternetPingMs >= 0 ? "full" : connectivity
    property real buttonRadius: theme.tileRadius
    readonly property alias controller: diagnostics
    spacing: 6
    visible: networkMode !== "none" || diagnostics.bandBusy || displayedConnectivity === "portal" || displayedConnectivity === "limited"
    Services.NetworkDiagnostics {
        id: diagnostics
        panelOpen: section.panelOpen
        networkMode: section.networkMode
        connectivity: section.displayedConnectivity
        onPortalOpening: section.theme.networkVisible = false
    }
    function latency(value) { return value >= 0 ? value.toFixed(1) + " ms" : "—" }
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool selected: false
        signal activated()
        height: 28
        radius: section.buttonRadius
        color: selected ? section.theme.fillActive : mouse.containsMouse ? section.theme.fillHover : section.theme.fillIdle
        border.width: 1
        border.color: selected ? section.theme.seal : section.theme.sep
        opacity: enabled ? 1 : 0.45
        UiText {
            anchors.centerIn: parent
            text: chip.label; textFormat: Text.PlainText
            font.family: section.theme.mono; font.pixelSize: 10
            color: chip.selected ? section.theme.seal : section.theme.ink
        }
        MouseArea {
            id: mouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: chip.activated()
        }
    }
    UiText {
        width: parent.width
        visible: section.displayedConnectivity === "portal" || section.displayedConnectivity === "limited"
        text: section.displayedConnectivity === "portal" ? "Sign in to this network to access the internet" : "Limited internet connectivity"
        textFormat: Text.PlainText; wrapMode: Text.WordWrap
        font.family: section.theme.mono; font.pixelSize: 11; color: section.theme.seal
    }
    Chip {
        objectName: "network-portal-login"
        width: parent.width; visible: section.displayedConnectivity === "portal"
        label: "Sign in to network"
        onActivated: diagnostics.openPortal()
    }
    UiText {
        text: "CONNECTION DIAGNOSTICS"
        font.family: section.theme.mono; font.pixelSize: 10; font.letterSpacing: 1
        color: section.theme.sumiHi
    }
    UiText {
        objectName: "network-latency-summary"
        width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
        text: diagnostics.diagnosticError || ("Router " + section.latency(diagnostics.routerMs)
            + " · Internet " + section.latency(diagnostics.internetMs)
            + "\nPacket loss " + (diagnostics.packetLoss >= 0 ? diagnostics.packetLoss + "%" : "—") + " · last 24 samples")
        font.family: section.theme.mono; font.pixelSize: 10; color: section.theme.ink
    }
    Column {
        width: parent.width; spacing: 6; visible: diagnostics.canSelectBand
        UiText {
            text: "WI-FI BAND" + (diagnostics.currentBand ? " · " + diagnostics.currentBand + " GHz" : "")
            font.family: section.theme.mono; font.pixelSize: 10; color: section.theme.sumiHi
        }
        Row {
            width: parent.width; spacing: 4
            Repeater {
                model: ["auto"].concat(diagnostics.availableBands)
                Chip {
                    required property string modelData
                    width: (parent.width - 4 * diagnostics.availableBands.length) / (diagnostics.availableBands.length + 1)
                    label: modelData === "auto" ? "Auto" : modelData + " GHz"
                    selected: modelData === (diagnostics.pendingBand || diagnostics.selectedBand)
                    enabled: !diagnostics.bandBusy
                    onActivated: diagnostics.setBand(modelData)
                }
            }
        }
        UiText {
            width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
            text: diagnostics.bandBusy ? "Changing band… reconnecting Wi-Fi" : "Changing band reconnects Wi-Fi"
            font.family: section.theme.mono; font.pixelSize: 10; color: section.theme.sumiHi
        }
    }
    UiText {
        width: parent.width; visible: text !== ""
        text: diagnostics.bandError; textFormat: Text.PlainText; wrapMode: Text.WordWrap
        font.family: section.theme.mono; font.pixelSize: 10; color: section.theme.seal
    }
}
