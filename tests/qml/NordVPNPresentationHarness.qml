import QtQuick
import QtQuick.Window
import Quickshell

Item {
    id: harness
    required property string variant
    property bool vpnVisible: false
    property bool networkVisible: false
    property var activePopupScreen: Quickshell.screens.length ? Quickshell.screens[0] : null
    property real vpnBarX: activePopupScreen ? activePopupScreen.width / 2 : 400
    property string barPosition: "top"
    property int barBottom: 35
    property int v2BarHeight: 33
    property int pillRadius: 8
    property int panelRadius: 14
    property int tileRadius: 5
    property int panelButtonRadius: 5
    property color bg: "#202020"
    property color pillBorder: "#505050"
    property int pillBorderW: 1
    property color panelBorder: "#505050"
    property color panelOuterBorderColor: "#606060"
    property int panelOuterBorderW: 1
    property bool styleShadow: false
    property color pillShadow: "#000000"
    property color ink: "#eeeeee"
    property color sumi: "#858585"
    property color sumiHi: "#b5b5b5"
    property color seal: "#ff5b35"
    property color sep: "#454545"
    property color fillActive: "#40251e"
    property color fillHover: "#383838"
    property color fillIdle: "#242424"
    property color color01: "#ff5b35"
    property string mono: "monospace"
    property var controller: ({
        vpnState: "Connected", vpnCountry: "Brazil", vpnConnected: true,
        canMutate: true, vpnBusy: false, countriesState: "Ready",
        countryOptions: ["Brazil", "Canada", "Japan", "United_States"],
        vpnSettings: ({
            technology: "NordLynx", protocol: "UDP", "auto-connect": "enabled",
            notify: "enabled", tray: "enabled", meshnet: "disabled", dns: "disabled",
            "lan-discovery": "enabled", routing: "enabled", "virtual-location": "enabled",
            "arp-ignore": "enabled", "post-quantum-vpn": "disabled",
            firewall: "enabled", "kill-switch": "disabled", "threat-protection-lite": "enabled"
        }),
        vpnActionMessage: "", vpnMessage: "",
        connectVpn: function() {}, disconnectVpn: function() {},
        connectVpnCountry: function(_) {}, pauseVpn: function(_) {},
        setVpnSetting: function(_, __) {}, setAutoConnect: function(_, __) {}
    })
    property var panel: null
    property bool escapeCheckArmed: false

    function setPanelInsetX(_) {}
    function loadPanel() {
        const path = variant === "V2"
            ? "file:///home/guiestrela/Work/quickshell-rise-review/versions/V1/variants/V2/panels/NordVPNPanel.qml"
            : "file:///home/guiestrela/Work/quickshell-rise-review/versions/V1/panels/NordVPNPanel.qml"
        const component = Qt.createComponent(path)
        if (component.status !== Component.Ready) throw new Error(component.errorString())
        panel = component.createObject(harness, { root: harness, controller: controller })
        if (!panel) throw new Error("NordVPN panel creation failed")
        panel.width = activePopupScreen.width
        panel.height = activePopupScreen.height
    }
    function findCard(item) {
        if (item.objectName === "nordvpn-panel-card") return item
        const children = item.children || []
        for (let i = 0; i < children.length; ++i) {
            const result = findCard(children[i])
            if (result) return result
        }
        return null
    }

    Component.onCompleted: loadPanel()
    Timer {
        interval: 700; running: true
        onTriggered: {
            harness.vpnVisible = true
            Qt.callLater(function() {
                const card = harness.findCard(harness.panel.contentItem)
                if (!card) {
                    console.error("NORDVPN_PRESENTATION_FAIL card not found")
                    Qt.exit(2); return
                }
                console.log("NORDVPN_PRESENTATION_READY", harness.variant,
                    "width=" + card.width, "height=" + card.height,
                    "x=" + card.x, "y=" + card.y)
                harness.escapeCheckArmed = true
            })
        }
    }
    Timer {
        interval: 15000; running: true
        onTriggered: {
            console.error("NORDVPN_PRESENTATION_FAIL timed out waiting for Escape")
            Qt.exit(3)
        }
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            if (harness.escapeCheckArmed && harness.panel && !harness.vpnVisible) {
                console.log("NORDVPN_PRESENTATION_ESCAPE_PASS", harness.variant)
                Qt.exit(0)
            }
        }
    }
}
