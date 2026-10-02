import QtQuick
import Quickshell
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: vpnPanel
    required property var root
    required property var controller
    screen: vpnPanel.root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rise-nordvpn"

    readonly property int barBottom: 35
    readonly property int gap: 8
    property string countryTarget: ""
    property string autoCountryTarget: ""
    property bool countryChooserExpanded: false
    property bool autoCountryChooserExpanded: false
    readonly property var countryOptions: controller.countryOptions || []
    readonly property alias testCountrySelectHandler: countrySelectMouse
    readonly property alias testAutoConnectHandler: autoConnectMouse
    readonly property alias testAutoCountrySelectHandler: autoCountrySelectMouse
    readonly property var pauseDurations: ["5m", "15m", "30m", "1h", "24h"]
    property string selectedPauseDuration: "15m"
    property bool pauseSelectorExpanded: false
    readonly property bool pauseAvailable: controller.canMutate
    property alias testPauseSelectorHandler: pauseSelectorMouse
    property alias testPauseApplyHandler: pauseApplyMouse
    property alias testToggleHandler: toggleMouse
    property alias testGoHandler: countryApplyMouse
    property alias testCloseHandler: closeMouse
    property alias testProtocolHandler: protocolMouse
    property var testTargets: ({})
    property real reveal: vpnPanel.root.vpnVisible ? 1 : 0
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: vpnPanel.root.vpnVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Behavior on reveal { NumberAnimation { duration: vpnPanel.root.vpnVisible ? 160 : 120; easing.type: Easing.OutCubic } }

    Connections {
        target: vpnPanel.root
        function onVpnVisibleChanged() {
            if (!vpnPanel.root.vpnVisible) vpnPanel.pauseSelectorExpanded = false
        }
    }
    function closePanel() { pauseSelectorExpanded = false; countryChooserExpanded = false; autoCountryChooserExpanded = false; vpnPanel.root.vpnVisible = false }
    function selectCountry(country) {
        if (countryOptions.indexOf(String(country)) < 0) return false
        countryTarget = String(country)
        countryChooserExpanded = false
        return true
    }
    function selectAutoCountry(country) {
        if (countryOptions.indexOf(String(country)) < 0) return false
        autoCountryTarget = String(country)
        autoCountryChooserExpanded = false
        return true
    }
    function applyAutoConnect() {
        return controller.setAutoConnect(autoConnectEnabled, autoCountryTarget)
    }
    property bool autoConnectEnabled: /^(enabled|on|yes|true)$/i.test(String(controller.vpnSettings["auto-connect"] || ""))
    function toggleConnection() { if (controller.vpnConnected) disconnect(); else connect() }
    function connect() { controller.connectVpn() }
    function disconnect() { controller.disconnectVpn() }
    function connectCountry() { controller.connectVpnCountry(countryTarget) }
    function pause(duration) { controller.pauseVpn(duration) }
    function changeSetting(key) { controller.setVpnSetting(key) }
    function changeTechnology(technology) { controller.setVpnSetting("technology", technology) }
    function changeProtocol(protocol) { controller.setVpnSetting("protocol", protocol) }
    function applyDns() { controller.setDnsServers(dnsInput.text) }
    function resetDns() { controller.resetDnsServers() }

    MouseArea { anchors.fill: parent; onClicked: vpnPanel.closePanel() }
    Rectangle {
        id: card
        width: Math.min(420, parent.width - 16)
        height: Math.min(col.implicitHeight + 36, parent.height - 32)
        radius: vpnPanel.reveal > 0.001 ? vpnPanel.root.pillRadius : 0
        color: vpnPanel.root.bg
        border.color: vpnPanel.root.pillBorder
        border.width: vpnPanel.root.pillBorderW
        PillShadow { theme: root }
        x: Math.round(Math.max(6, Math.min(root.vpnBarX - width / 2, parent.width - width - 6)))
        y: vpnPanel.root.barPosition === "bottom" ? (parent.height - vpnPanel.barBottom - vpnPanel.gap - height) : (vpnPanel.barBottom + vpnPanel.gap)
        opacity: vpnPanel.reveal
        focus: vpnPanel.root.vpnVisible
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
                UiText { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "NordVPN"; color: vpnPanel.root.ink; font.family: vpnPanel.root.mono; font.pixelSize: 13; font.letterSpacing: 2; font.weight: Font.Medium }
                UiText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "✕"; color: closeMouse.containsMouse ? vpnPanel.root.seal : vpnPanel.root.sumi; font.pixelSize: 12
                    MouseArea { objectName: "vpn-close"; id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: vpnPanel.closePanel() }
                }
            }
            Rectangle { width: parent.width; height: 1; color: vpnPanel.root.sep }
            Item {
                width: parent.width; height: 30
                UiText { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "STATUS"; color: vpnPanel.root.sumiHi; font.family: vpnPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
                UiText { anchors.right: connectionSwitch.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: controller.vpnState + (controller.vpnCountry ? " · " + controller.vpnCountry : ""); color: controller.vpnConnected ? vpnPanel.root.seal : vpnPanel.root.sumi; font.family: vpnPanel.root.mono; font.pixelSize: 10; elide: Text.ElideRight }
                Rectangle { id: connectionSwitch; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 50; height: 22; radius: height / 2; color: controller.vpnConnected ? vpnPanel.root.fillActive : toggleMouse.containsMouse && toggleMouse.enabled ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle; border.color: controller.vpnConnected || (toggleMouse.containsMouse && toggleMouse.enabled) ? vpnPanel.root.seal : vpnPanel.root.sep; border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    UiText { anchors.centerIn: parent; text: controller.vpnConnected ? "ON" : "OFF"; color: controller.vpnConnected ? vpnPanel.root.seal : vpnPanel.root.sumi; font.family: vpnPanel.root.mono; font.pixelSize: 10 }
                    MouseArea { id: toggleMouse; objectName: "vpn-toggle"; anchors.fill: parent; hoverEnabled: true; enabled: controller.canMutate; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: vpnPanel.toggleConnection() }
                }
            }
            UiText { text: "COUNTRY · " + (controller.countriesState === "Loading" ? "Loading…" : controller.countriesState === "Error" ? "Unavailable" : controller.countriesState === "Empty" ? "No countries" : "Select, then connect"); color: vpnPanel.root.sumiHi; font.family: vpnPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 0.5 }
            Row {
                width: parent.width; spacing: 6
                Rectangle {
                    width: parent.width - 54; height: 28; radius: vpnPanel.root.tileRadius
                    color: countrySelectMouse.containsMouse ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle
                    border.color: countryChooserExpanded ? vpnPanel.root.seal : vpnPanel.root.sep
                    UiText { anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: vpnPanel.countryTarget || "Choose country"; color: vpnPanel.root.ink; font.family: vpnPanel.root.mono; font.pixelSize: 10; elide: Text.ElideRight }
                    UiText { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: countryChooserExpanded ? "▴" : "▾"; color: vpnPanel.root.sumiHi; font.pixelSize: 10 }
                    MouseArea { id: countrySelectMouse; objectName: "vpn-country-select"; anchors.fill: parent; hoverEnabled: true; enabled: controller.countriesState === "Ready"; onClicked: vpnPanel.countryChooserExpanded = !vpnPanel.countryChooserExpanded }
                }
                Rectangle {
                    width: 48; height: 28; radius: vpnPanel.root.tileRadius; color: countryApplyMouse.containsMouse ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle; border.color: vpnPanel.root.sep
                    UiText { anchors.centerIn: parent; text: "Connect"; color: vpnPanel.root.seal; font.family: vpnPanel.root.mono; font.pixelSize: 8 }
                    MouseArea { id: countryApplyMouse; objectName: "vpn-country-connect"; anchors.fill: parent; hoverEnabled: true; enabled: controller.canMutate && vpnPanel.countryTarget !== ""; onClicked: vpnPanel.connectCountry() }
                }
            }
            ListView {
                objectName: "vpn-country-options"
                width: parent.width; height: vpnPanel.countryChooserExpanded ? Math.min(contentHeight, 112) : 0
                visible: vpnPanel.countryChooserExpanded; clip: true; model: vpnPanel.countryOptions; boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    required property string modelData
                    width: ListView.view.width; height: 26; color: countryOptionMouse.containsMouse ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle
                    UiText { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.replace(/_/g, " "); color: vpnPanel.root.ink; font.family: vpnPanel.root.mono; font.pixelSize: 10 }
                    MouseArea { id: countryOptionMouse; objectName: "vpn-country-option-" + modelData; anchors.fill: parent; hoverEnabled: true; onClicked: vpnPanel.selectCountry(modelData) }
                }
            }
            UiText { text: "SETTINGS"; color: vpnPanel.root.sumiHi; font.family: vpnPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
            UiText { text: "TECHNOLOGY · " + String(controller.vpnSettings.technology || "Checking…").toUpperCase(); color: vpnPanel.root.sumiHi; font.family: vpnPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 0.5 }
            Row {
                width: parent.width; spacing: 6
                Repeater {
                    model: ["OPENVPN", "NORDLYNX", "NORDWHISPER"]
                    delegate: Rectangle {
                        required property string modelData
                        width: (parent.width - 12) / 3; height: 28; radius: vpnPanel.root.tileRadius
                        readonly property bool selected: String(controller.vpnSettings.technology || "").toUpperCase() === modelData
                        color: selected ? vpnPanel.root.fillActive : technologyMouse.containsMouse && technologyMouse.enabled ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle
                        border.color: selected || (technologyMouse.containsMouse && technologyMouse.enabled) ? vpnPanel.root.seal : vpnPanel.root.sep
                        UiText { anchors.centerIn: parent; text: modelData; color: parent.selected ? vpnPanel.root.seal : vpnPanel.root.ink; font.family: vpnPanel.root.mono; font.pixelSize: 8; elide: Text.ElideRight }
                        MouseArea { id: technologyMouse; objectName: "vpn-technology-" + modelData.toLowerCase(); Component.onCompleted: vpnPanel.testTargets[objectName] = technologyMouse; anchors.fill: parent; hoverEnabled: true; enabled: controller.canMutate; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: vpnPanel.changeTechnology(modelData) }
                    }
                }
            }
            UiText { text: "PROTOCOL · OPENVPN TRANSPORT"; color: vpnPanel.root.sumiHi; font.family: vpnPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 0.5 }
            UiText { width: parent.width; text: "UDP is faster · TCP can be more reliable on restricted networks"; color: vpnPanel.root.sumi; font.family: vpnPanel.root.mono; font.pixelSize: 9; wrapMode: Text.Wrap }
            Row {
                width: parent.width; spacing: 6
                Rectangle {
                    width: (parent.width - 6) / 2; height: 28; radius: vpnPanel.root.tileRadius
                    readonly property bool selected: String(controller.vpnSettings.protocol || "UDP").toUpperCase() === "UDP"
                    color: selected ? vpnPanel.root.fillActive : protocolMouse.containsMouse && protocolMouse.enabled ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle
                    border.color: selected || (protocolMouse.containsMouse && protocolMouse.enabled) ? vpnPanel.root.seal : vpnPanel.root.sep
                    UiText { anchors.centerIn: parent; text: "UDP"; color: parent.selected ? vpnPanel.root.seal : vpnPanel.root.ink; font.family: vpnPanel.root.mono; font.pixelSize: 10 }
                    MouseArea { id: protocolMouse; objectName: "vpn-protocol"; anchors.fill: parent; hoverEnabled: true; enabled: controller.canMutate; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: vpnPanel.changeProtocol("UDP") }
                }
                Rectangle {
                    width: (parent.width - 6) / 2; height: 28; radius: vpnPanel.root.tileRadius
                    readonly property bool selected: String(controller.vpnSettings.protocol || "UDP").toUpperCase() === "TCP"
                    color: selected ? vpnPanel.root.fillActive : tcpProtocolMouse.containsMouse && tcpProtocolMouse.enabled ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle
                    border.color: selected || (tcpProtocolMouse.containsMouse && tcpProtocolMouse.enabled) ? vpnPanel.root.seal : vpnPanel.root.sep
                    UiText { anchors.centerIn: parent; text: "TCP"; color: parent.selected ? vpnPanel.root.seal : vpnPanel.root.ink; font.family: vpnPanel.root.mono; font.pixelSize: 10 }
                    MouseArea { id: tcpProtocolMouse; objectName: "vpn-protocol-tcp"; anchors.fill: parent; hoverEnabled: true; enabled: controller.canMutate; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: vpnPanel.changeProtocol("TCP") }
                }
            }
            Rectangle { width: parent.width; height: 1; color: vpnPanel.root.sep }
            UiText { text: "AUTO-CONNECT"; color: vpnPanel.root.sumiHi; font.family: vpnPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
            Row {
                width: parent.width; spacing: 6
                Rectangle {
                    width: parent.width - 112; height: 28; radius: vpnPanel.root.tileRadius
                    color: autoCountrySelectMouse.containsMouse ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle
                    border.color: autoCountryChooserExpanded ? vpnPanel.root.seal : vpnPanel.root.sep
                    UiText { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: vpnPanel.autoCountryTarget || "Choose country"; color: vpnPanel.root.ink; font.family: vpnPanel.root.mono; font.pixelSize: 9; elide: Text.ElideRight }
                    MouseArea { id: autoCountrySelectMouse; objectName: "vpn-autoconnect-country-select"; anchors.fill: parent; hoverEnabled: true; enabled: controller.countriesState === "Ready"; onClicked: vpnPanel.autoCountryChooserExpanded = !vpnPanel.autoCountryChooserExpanded }
                }
                Rectangle {
                    width: 48; height: 28; radius: vpnPanel.root.tileRadius; color: autoConnectMouse.containsMouse ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle; border.color: vpnPanel.autoConnectEnabled ? vpnPanel.root.seal : vpnPanel.root.sep
                    UiText { anchors.centerIn: parent; text: vpnPanel.autoConnectEnabled ? "ON" : "OFF"; color: vpnPanel.autoConnectEnabled ? vpnPanel.root.seal : vpnPanel.root.sumi; font.family: vpnPanel.root.mono; font.pixelSize: 10 }
                    MouseArea { id: autoConnectMouse; objectName: "vpn-autoconnect-toggle"; anchors.fill: parent; hoverEnabled: true; enabled: controller.canMutate; onClicked: vpnPanel.autoConnectEnabled = !vpnPanel.autoConnectEnabled }
                }
                Rectangle {
                    width: 54; height: 28; radius: vpnPanel.root.tileRadius; color: autoConnectApplyMouse.containsMouse ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle; border.color: vpnPanel.root.sep
                    UiText { anchors.centerIn: parent; text: "Apply"; color: vpnPanel.root.seal; font.family: vpnPanel.root.mono; font.pixelSize: 9 }
                    MouseArea { id: autoConnectApplyMouse; objectName: "vpn-autoconnect-apply"; anchors.fill: parent; hoverEnabled: true; enabled: controller.canMutate && (!vpnPanel.autoConnectEnabled || vpnPanel.autoCountryTarget !== ""); onClicked: vpnPanel.applyAutoConnect() }
                }
            }
            ListView {
                objectName: "vpn-autoconnect-country-options"
                width: parent.width - 112; height: vpnPanel.autoCountryChooserExpanded ? Math.min(contentHeight, 96) : 0
                visible: vpnPanel.autoCountryChooserExpanded; clip: true; model: vpnPanel.countryOptions; boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    required property string modelData
                    width: ListView.view.width; height: 24; color: autoCountryOptionMouse.containsMouse ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle
                    UiText { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.replace(/_/g, " "); color: vpnPanel.root.ink; font.family: vpnPanel.root.mono; font.pixelSize: 9 }
                    MouseArea { id: autoCountryOptionMouse; objectName: "vpn-autoconnect-country-" + modelData; anchors.fill: parent; hoverEnabled: true; onClicked: vpnPanel.selectAutoCountry(modelData) }
                }
            }
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
                        UiText { anchors.left: parent.left; anchors.right: switchTrack.left; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: parent.enabledSetting ? vpnPanel.root.ink : vpnPanel.root.sumi; font.family: vpnPanel.root.mono; font.pixelSize: 10; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                        Rectangle { id: switchTrack; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 50; height: 22; radius: height / 2; color: parent.enabledSetting ? vpnPanel.root.fillActive : settingMouse.containsMouse && settingMouse.enabled ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle; border.color: parent.enabledSetting || (settingMouse.containsMouse && settingMouse.enabled) ? vpnPanel.root.seal : vpnPanel.root.sep; border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            UiText { anchors.centerIn: parent; text: parent.parent.enabledSetting ? "ON" : "OFF"; color: parent.parent.enabledSetting ? vpnPanel.root.seal : vpnPanel.root.sumi; font.family: vpnPanel.root.mono; font.pixelSize: 10 }
                        }
                        MouseArea { objectName: "vpn-setting-" + modelData.key; id: settingMouse; Component.onCompleted: vpnPanel.testTargets[objectName] = settingMouse; anchors.fill: parent; hoverEnabled: true; enabled: controller.vpnState !== "Unavailable" && modelData.key !== "dns"; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: vpnPanel.changeSetting(modelData.key) }
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: vpnPanel.root.sep }
            UiText { text: "SECURITY"; color: vpnPanel.root.sumiHi; font.family: vpnPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
            UiText { width: parent.width; text: "Real-time Protection uses NordVPN DNS and may reset custom DNS."; color: vpnPanel.root.sumi; font.family: vpnPanel.root.mono; font.pixelSize: 9; wrapMode: Text.Wrap }
            Grid {
                width: parent.width; columns: 2; rowSpacing: 5; columnSpacing: 10
                Repeater {
                    model: [{key:"firewall",label:"Firewall"},{key:"kill-switch",label:"Kill Switch"},{key:"threat-protection-lite",label:"Real-time Protection"}]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 10) / 2; height: 42; color: "transparent"
                        readonly property bool enabledSetting: /^(enabled|on|yes|true)$/i.test(String(controller.vpnSettings[modelData.key] || ""))
                        UiText { anchors.left: parent.left; anchors.right: switchTrack.left; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: parent.enabledSetting ? vpnPanel.root.ink : vpnPanel.root.sumi; font.family: vpnPanel.root.mono; font.pixelSize: 10; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                        Rectangle { id: switchTrack; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 50; height: 22; radius: height / 2; color: parent.enabledSetting ? vpnPanel.root.fillActive : settingMouse.containsMouse && settingMouse.enabled ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle; border.color: parent.enabledSetting || (settingMouse.containsMouse && settingMouse.enabled) ? vpnPanel.root.seal : vpnPanel.root.sep; border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            UiText { anchors.centerIn: parent; text: parent.parent.enabledSetting ? "ON" : "OFF"; color: parent.parent.enabledSetting ? vpnPanel.root.seal : vpnPanel.root.sumi; font.family: vpnPanel.root.mono; font.pixelSize: 10 }
                        }
                        MouseArea { objectName: "vpn-setting-" + modelData.key; id: settingMouse; Component.onCompleted: vpnPanel.testTargets[objectName] = settingMouse; anchors.fill: parent; hoverEnabled: true; enabled: controller.canMutate; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: vpnPanel.changeSetting(modelData.key) }
                    }
                }
            }
            UiText { text: "PAUSE VPN"; color: vpnPanel.root.sumiHi; font.family: vpnPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
            Row {
                width: parent.width; spacing: 6
                Rectangle {
                    id: pauseSelector
                    width: parent.width - 78; height: 28; radius: vpnPanel.root.tileRadius
                    color: pauseSelectorMouse.containsMouse && vpnPanel.pauseAvailable ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle
                    border.color: vpnPanel.pauseSelectorExpanded ? vpnPanel.root.seal : vpnPanel.root.sep; border.width: 1
                    opacity: vpnPanel.pauseAvailable ? 1 : 0.5
                    UiText { anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: vpnPanel.selectedPauseDuration; color: vpnPanel.root.ink; font.family: vpnPanel.root.mono; font.pixelSize: 10 }
                    UiText { anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: vpnPanel.pauseSelectorExpanded ? "▴" : "▾"; color: vpnPanel.root.sumiHi; font.pixelSize: 10 }
                    MouseArea {
                        id: pauseSelectorMouse; objectName: "vpn-pause-selector"; anchors.fill: parent; hoverEnabled: true
                        enabled: vpnPanel.pauseAvailable; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: { if (vpnPanel.pauseAvailable) vpnPanel.pauseSelectorExpanded = !vpnPanel.pauseSelectorExpanded }
                    }
                }
                Rectangle {
                    width: 72; height: 28; radius: vpnPanel.root.tileRadius
                    color: pauseApplyMouse.containsMouse && vpnPanel.pauseAvailable ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle
                    border.color: pauseApplyMouse.containsMouse && vpnPanel.pauseAvailable ? vpnPanel.root.seal : vpnPanel.root.sep; border.width: 1
                    opacity: vpnPanel.pauseAvailable ? 1 : 0.5
                    UiText { anchors.centerIn: parent; text: "pause"; color: vpnPanel.root.seal; font.family: vpnPanel.root.mono; font.pixelSize: 10 }
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
                        width: parent.width; height: 28; radius: vpnPanel.root.tileRadius
                        color: pauseOptionMouse.containsMouse || vpnPanel.selectedPauseDuration === modelData ? vpnPanel.root.fillHover : vpnPanel.root.fillIdle
                        border.color: vpnPanel.selectedPauseDuration === modelData ? vpnPanel.root.seal : vpnPanel.root.sep; border.width: 1
                        UiText { anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: modelData; color: vpnPanel.selectedPauseDuration === modelData ? vpnPanel.root.seal : vpnPanel.root.ink; font.family: vpnPanel.root.mono; font.pixelSize: 10 }
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
            UiText { width: parent.width; visible: controller.vpnActionMessage !== ""; text: controller.vpnActionMessage; color: vpnPanel.root.sumi; font.family: vpnPanel.root.mono; font.pixelSize: 8; elide: Text.ElideRight }
            UiText { width: parent.width; visible: controller.vpnMessage !== ""; text: controller.vpnMessage; color: vpnPanel.root.color01; font.family: vpnPanel.root.mono; font.pixelSize: 9; wrapMode: Text.Wrap }
        }
        }
    }
}
