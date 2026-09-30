import QtQuick
import Quickshell
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: vpnPanel
    required property var root
    required property var controller
    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rise-nordvpn"

    readonly property int barBottom: 35
    readonly property int gap: 8
    property string countryTarget: ""
    readonly property var pauseDurations: ["5m", "15m", "30m", "1h", "24h"]
    property string selectedPauseDuration: "15m"
    property bool pauseSelectorExpanded: false
    readonly property bool pauseAvailable: controller.canMutate
    property alias testPauseSelectorHandler: pauseSelectorMouse
    property alias testPauseApplyHandler: pauseApplyMouse
    property alias testToggleHandler: toggleMouse
    property alias testCountryInput: countryInput
    property alias testGoHandler: goMouse
    property alias testCloseHandler: closeMouse
    property alias testProtocolHandler: protocolMouse
    property alias testDnsInput: dnsInput
    property alias testDnsSetHandler: dnsSetMouse
    property alias testDnsResetHandler: dnsResetMouse
    property var testTargets: ({})
    property real reveal: root.vpnVisible ? 1 : 0
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.vpnVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Behavior on reveal { NumberAnimation { duration: root.vpnVisible ? 160 : 120; easing.type: Easing.OutCubic } }

    Connections {
        target: vpnPanel.root
        function onVpnVisibleChanged() {
            if (!vpnPanel.root.vpnVisible) vpnPanel.pauseSelectorExpanded = false
        }
    }
    function closePanel() { pauseSelectorExpanded = false; root.vpnVisible = false }
    function toggleConnection() { if (controller.vpnConnected) disconnect(); else connect() }
    function connect() { controller.connectVpn() }
    function disconnect() { controller.disconnectVpn() }
    function connectCountry() { controller.connectVpnCountry(countryTarget) }
    function pause(duration) { controller.pauseVpn(duration) }
    function changeSetting(key) { controller.setVpnSetting(key) }
    function changeProtocol() { controller.setVpnSetting("protocol") }
    function applyDns() { controller.setDnsServers(dnsInput.text) }
    function resetDns() { controller.resetDnsServers() }

    MouseArea { anchors.fill: parent; onClicked: vpnPanel.closePanel() }
    Rectangle {
        id: card
        width: Math.min(420, parent.width - 16)
        height: Math.min(col.implicitHeight + 36, parent.height - 32)
        radius: vpnPanel.reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
        x: Math.round(Math.max(6, Math.min(root.vpnBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - vpnPanel.barBottom - vpnPanel.gap - height) : (vpnPanel.barBottom + vpnPanel.gap)
        opacity: vpnPanel.reveal
        focus: root.vpnVisible
        Keys.onPressed: function(event) { if (event.key === Qt.Key_Escape) { vpnPanel.closePanel(); event.accepted = true } }
        MouseArea { anchors.fill: parent; onClicked: {} }
        Flickable {
            id: panelScroll
            anchors.fill: parent
            contentWidth: width
            contentHeight: col.implicitHeight + 24
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: col
                x: 12
                y: 12
                width: panelScroll.width - 24
                spacing: 8
            Item {
                width: parent.width; height: 24
                UiText { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "NordVPN"; color: root.ink; font.family: root.mono; font.pixelSize: 13; font.letterSpacing: 2; font.weight: Font.Medium }
                UiText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "✕"; color: closeMouse.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                    MouseArea { objectName: "vpn-close"; id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: vpnPanel.closePanel() }
                }
            }
            Rectangle { width: parent.width; height: 1; color: root.sep }
            Item {
                width: parent.width; height: 30
                UiText { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "STATUS"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
                UiText { anchors.right: connectionSwitch.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: controller.vpnState + (controller.vpnCountry ? " · " + controller.vpnCountry : ""); color: controller.vpnConnected ? root.seal : root.sumi; font.family: root.mono; font.pixelSize: 10; elide: Text.ElideRight }
                Rectangle { id: connectionSwitch; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 38; height: 20; radius: 2; color: controller.vpnConnected ? root.fillHover : root.fillIdle; border.color: controller.vpnConnected ? root.seal : root.sep
                    Rectangle { width: 14; height: 14; y: 3; x: controller.vpnConnected ? 21 : 3; radius: 1; color: controller.vpnConnected ? root.seal : root.sumi }
                    MouseArea { id: toggleMouse; objectName: "vpn-toggle"; anchors.fill: parent; enabled: controller.canMutate; onClicked: vpnPanel.toggleConnection() }
                }
            }
            UiText { text: "COUNTRY"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
            Row {
                width: parent.width; spacing: 6
                TextInput {
                    id: countryInput; objectName: "vpn-country"; width: parent.width - 48; height: 28; verticalAlignment: TextInput.AlignVCenter; leftPadding: 9; rightPadding: 7
                    color: root.ink; selectionColor: root.seal; selectedTextColor: root.paper; font.family: root.mono; font.pixelSize: 10; clip: true
                    text: vpnPanel.countryTarget; onTextEdited: vpnPanel.countryTarget = text; onAccepted: vpnPanel.connectCountry()
                    Rectangle { z: -1; anchors.fill: parent; radius: root.tileRadius; color: root.fillIdle; border.color: root.sep; border.width: 1 }
                    Text { anchors.left: parent.left; anchors.leftMargin: 7; anchors.verticalCenter: parent.verticalCenter; visible: countryInput.text === "" && !countryInput.activeFocus; text: "country (optional)"; color: root.sumi; font.family: root.mono; font.pixelSize: 10 }
                }
                Rectangle {
                    width: 42; height: 25; radius: root.tileRadius; color: goMouse.containsMouse ? root.fillHover : root.fillIdle; border.color: goMouse.containsMouse ? root.seal : root.sep; border.width: 1
                    UiText { anchors.centerIn: parent; text: "go"; color: root.seal; font.family: root.mono; font.pixelSize: 10 }
                    MouseArea { objectName: "vpn-go"; id: goMouse; anchors.fill: parent; hoverEnabled: true; enabled: controller.canMutate; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: vpnPanel.connectCountry() }
                }
            }
            UiText { text: "SETTINGS"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
            UiText { text: "Technology · " + String(controller.vpnSettings.technology || "Checking…"); color: root.ink; font.family: root.mono; font.pixelSize: 11 }
            UiText { text: "Protocol · " + String(controller.vpnSettings.protocol || "Not exposed by this CLI"); color: root.sumi; font.family: root.mono; font.pixelSize: 11 }
            Rectangle { width: parent.width; height: 1; color: root.sep }
            UiText { text: "AUTO-CONNECT"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
            UiText { text: "Auto-connect: " + String(controller.vpnSettings["auto-connect"] || "Checking…"); color: root.ink; font.family: root.mono; font.pixelSize: 11 }
            Grid {
                width: parent.width; columns: 2; rowSpacing: 5; columnSpacing: 10
                Repeater {
                    model: [{key:"notify",label:"Notify"},{key:"tray",label:"Tray"},
                        {key:"meshnet",label:"Meshnet"},{key:"dns",label:"DNS"},
                        {key:"lan-discovery",label:"LAN Discovery"},{key:"routing",label:"Routing"},
                        {key:"virtual-location",label:"Virtual Location"},{key:"arp-ignore",label:"ARP Ignore"},
                        {key:"post-quantum-vpn",label:"Post-quantum VPN"}]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 10) / 2; height: 42; radius: 0
                        readonly property bool enabledSetting: /^(enabled|on|yes|true)$/i.test(String(controller.vpnSettings[modelData.key] || ""))
                        color: "transparent"
                        UiText { anchors.left: parent.left; anchors.right: switchTrack.left; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter; text: modelData.label + ": " + String(controller.vpnSettings[modelData.key] || "Checking…"); color: parent.enabledSetting ? root.ink : root.sumi; font.family: root.mono; font.pixelSize: 10; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                        Rectangle { id: switchTrack; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 36; height: 20; radius: 2; color: parent.enabledSetting ? root.fillHover : root.fillIdle; border.color: parent.enabledSetting ? root.seal : root.sep
                            Rectangle { width: 14; height: 14; y: 3; x: parent.parent.enabledSetting ? 19 : 3; radius: 1; color: parent.parent.enabledSetting ? root.seal : root.sumi }
                        }
                        MouseArea { objectName: "vpn-setting-" + modelData.key; id: settingMouse; Component.onCompleted: vpnPanel.testTargets[objectName] = settingMouse; anchors.fill: parent; hoverEnabled: true; enabled: controller.vpnState !== "Unavailable" && modelData.key !== "dns"; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: vpnPanel.changeSetting(modelData.key) }
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: root.sep }
            UiText { text: "SECURITY"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
            Grid {
                width: parent.width; columns: 2; rowSpacing: 5; columnSpacing: 10
                Repeater {
                    model: [{key:"firewall",label:"Firewall"},{key:"kill-switch",label:"Kill Switch"},{key:"threat-protection-lite",label:"Threat Protection Lite · unavailable (CLI 5.4.0)"}]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 10) / 2; height: 42; color: "transparent"
                        readonly property bool enabledSetting: /^(enabled|on|yes|true)$/i.test(String(controller.vpnSettings[modelData.key] || ""))
                        UiText { anchors.left: parent.left; anchors.right: switchTrack.left; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter; text: modelData.label + ": " + String(controller.vpnSettings[modelData.key] || "Checking…"); color: parent.enabledSetting ? root.ink : root.sumi; font.family: root.mono; font.pixelSize: 10; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                        Rectangle { id: switchTrack; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 36; height: 20; radius: 2; color: parent.enabledSetting ? root.fillHover : root.fillIdle; border.color: parent.enabledSetting ? root.seal : root.sep
                            Rectangle { width: 14; height: 14; y: 3; x: parent.parent.enabledSetting ? 19 : 3; radius: 1; color: parent.parent.enabledSetting ? root.seal : root.sumi }
                        }
                        MouseArea { objectName: "vpn-setting-" + modelData.key; id: settingMouse; Component.onCompleted: vpnPanel.testTargets[objectName] = settingMouse; anchors.fill: parent; hoverEnabled: true; enabled: controller.canMutate && modelData.key !== "threat-protection-lite"; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: vpnPanel.changeSetting(modelData.key) }
                    }
                }
            }
            UiText { text: "DNS SERVERS (IPv4)"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 8; font.letterSpacing: 0.7 }
            Row {
                width: parent.width; spacing: 4
                TextInput {
                    id: dnsInput; objectName: "vpn-dns-input"; width: parent.width - 76; height: 24
                    verticalAlignment: TextInput.AlignVCenter; leftPadding: 6; rightPadding: 6
                    color: root.ink; selectionColor: root.seal; selectedTextColor: root.paper; font.family: root.mono; font.pixelSize: 9
                    Text { anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; visible: dnsInput.text === "" && !dnsInput.activeFocus; text: "1.1.1.1, 8.8.8.8"; color: root.sumi; font.family: root.mono; font.pixelSize: 9 }
                    Rectangle { z: -1; anchors.fill: parent; radius: root.tileRadius; color: root.fillIdle; border.color: root.sep; border.width: 1 }
                }
                Rectangle {
                    width: 34; height: 24; radius: root.tileRadius; color: dnsSetMouse.containsMouse ? root.fillHover : root.fillIdle; border.color: root.sep
                    UiText { anchors.centerIn: parent; text: "set"; color: root.seal; font.family: root.mono; font.pixelSize: 9 }
                    MouseArea { id: dnsSetMouse; objectName: "vpn-dns-set"; anchors.fill: parent; hoverEnabled: true; enabled: controller.canMutate; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: vpnPanel.applyDns() }
                }
                Rectangle {
                    width: 34; height: 24; radius: root.tileRadius; color: dnsResetMouse.containsMouse ? root.fillHover : root.fillIdle; border.color: root.sep
                    UiText { anchors.centerIn: parent; text: "reset"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 8 }
                    MouseArea { id: dnsResetMouse; objectName: "vpn-dns-reset"; anchors.fill: parent; hoverEnabled: true; enabled: controller.canMutate; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: vpnPanel.resetDns() }
                }
            }
            UiText { text: "PAUSE VPN"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
            Row {
                width: parent.width; spacing: 6
                Rectangle {
                    id: pauseSelector
                    width: parent.width - 78; height: 28; radius: root.tileRadius
                    color: pauseSelectorMouse.containsMouse && vpnPanel.pauseAvailable ? root.fillHover : root.fillIdle
                    border.color: vpnPanel.pauseSelectorExpanded ? root.seal : root.sep; border.width: 1
                    opacity: vpnPanel.pauseAvailable ? 1 : 0.5
                    UiText { anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: vpnPanel.selectedPauseDuration; color: root.ink; font.family: root.mono; font.pixelSize: 10 }
                    UiText { anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: vpnPanel.pauseSelectorExpanded ? "▴" : "▾"; color: root.sumiHi; font.pixelSize: 10 }
                    MouseArea {
                        id: pauseSelectorMouse; objectName: "vpn-pause-selector"; anchors.fill: parent; hoverEnabled: true
                        enabled: vpnPanel.pauseAvailable; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: { if (vpnPanel.pauseAvailable) vpnPanel.pauseSelectorExpanded = !vpnPanel.pauseSelectorExpanded }
                    }
                }
                Rectangle {
                    width: 72; height: 28; radius: root.tileRadius
                    color: pauseApplyMouse.containsMouse && vpnPanel.pauseAvailable ? root.fillHover : root.fillIdle
                    border.color: pauseApplyMouse.containsMouse && vpnPanel.pauseAvailable ? root.seal : root.sep; border.width: 1
                    opacity: vpnPanel.pauseAvailable ? 1 : 0.5
                    UiText { anchors.centerIn: parent; text: "pause"; color: root.seal; font.family: root.mono; font.pixelSize: 10 }
                    MouseArea {
                        id: pauseApplyMouse; objectName: "vpn-pause-apply"; anchors.fill: parent; hoverEnabled: true
                        enabled: vpnPanel.pauseAvailable; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: { vpnPanel.pauseSelectorExpanded = false; vpnPanel.pause(vpnPanel.selectedPauseDuration) }
                    }
                }
            }
            Column {
                width: parent.width - 78; spacing: 3; visible: vpnPanel.pauseSelectorExpanded
                Repeater {
                    model: vpnPanel.pauseDurations
                    delegate: Rectangle {
                        required property string modelData
                        width: parent.width; height: 28; radius: root.tileRadius
                        color: pauseOptionMouse.containsMouse || vpnPanel.selectedPauseDuration === modelData ? root.fillHover : root.fillIdle
                        border.color: vpnPanel.selectedPauseDuration === modelData ? root.seal : root.sep; border.width: 1
                        UiText { anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: modelData; color: vpnPanel.selectedPauseDuration === modelData ? root.seal : root.ink; font.family: root.mono; font.pixelSize: 10 }
                        MouseArea {
                            id: pauseOptionMouse; objectName: "vpn-pause-" + modelData
                            Component.onCompleted: vpnPanel.testTargets[objectName] = pauseOptionMouse
                            anchors.fill: parent; hoverEnabled: true; enabled: vpnPanel.pauseAvailable
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (!vpnPanel.pauseAvailable) return
                                vpnPanel.selectedPauseDuration = modelData
                                vpnPanel.pauseSelectorExpanded = false
                            }
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 25; radius: root.tileRadius; color: root.fillIdle; border.color: root.sep; border.width: 1
                UiText { anchors.centerIn: parent; text: "Protocol · unavailable (CLI 5.4.0 lacks set protocol)"; color: root.sumi; font.family: root.mono; font.pixelSize: 10; elide: Text.ElideRight }
                MouseArea { objectName: "vpn-protocol"; id: protocolMouse; anchors.fill: parent; hoverEnabled: true; enabled: false; cursorShape: Qt.ArrowCursor; onClicked: vpnPanel.changeProtocol() }
            }
            UiText { width: parent.width; visible: controller.vpnActionMessage !== ""; text: controller.vpnActionMessage; color: root.sumi; font.family: root.mono; font.pixelSize: 8; elide: Text.ElideRight }
            UiText { width: parent.width; visible: controller.vpnMessage !== ""; text: controller.vpnMessage; color: root.color01; font.family: root.mono; font.pixelSize: 9; wrapMode: Text.Wrap }
        }
        }
    }
}
