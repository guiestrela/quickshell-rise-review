import QtQuick
import QtQuick.Window
import Quickshell

Window {
    id: host
    visible: true
    width: 900
    height: 600
    property bool vpnVisible: false
    property bool networkVisible: false
    property bool modNordVpn: true
    property bool modNetwork: false
    property string nordVpnStatus: "Unknown"
    property var activePopupScreen: Quickshell.screens[0]
    property string activePopupScreenName: activePopupScreen ? activePopupScreen.name : ""
    property real vpnBarX: 90
    property real networkBarX: 700
    property string barPosition: "top"
    property int pillRadius: 8
    property int pillBorderW: 1
    property int tileRadius: 5
    property color bg: "#181818"
    property color pillBorder: "#444444"
    property bool styleShadow: false
    property color pillShadow: "#000000"
    property color seal: "#d75f5f"
    property color sumi: "#888888"
    property color sumiHi: "#bbbbbb"
    property color ink: "#eeeeee"
    property color paper: "#ffffff"
    property color sep: "#444444"
    property color fillIdle: "#222222"
    property color fillHover: "#333333"
    property string mono: "monospace"
    property color color01: "#ff6666"
    property var controller: null
    property var widget: null
    property var panel: null
    property int step: 0
    Binding { target: host; property: "nordVpnStatus"; value: host.controller ? host.controller.vpnState : "Unknown" }

    function setPanelAnchor(name, x, screenName) {
        if (name !== "vpn" || !screenName) throw new Error("wrong independent VPN anchor")
        host.vpnBarX = x
    }
    function createAt(url, props) {
        var component = Qt.createComponent(url)
        if (component.status !== Component.Ready) throw new Error(component.errorString())
        var obj = component.createObject(host, props)
        if (!obj) throw new Error("could not instantiate " + url)
        return obj
    }
    function verify(condition, message) { if (!condition) throw new Error(message) }
    function nextAction() {
        var actions = [
            function() { return host.controller.connectVpn() },
            function() { return host.controller.disconnectVpn() },
            function() { return host.controller.connectVpnCountry("Canada") },
            function() { return host.controller.pauseVpn("15m") },
            function() { return host.controller.setVpnSetting("firewall") },
            function() { return host.controller.setVpnSetting("kill-switch") },
            function() { return host.controller.setVpnSetting("threat-protection-lite") },
            function() { return host.controller.setVpnSetting("auto-connect") },
            function() { return host.controller.setVpnSetting("technology") },
            function() { return host.controller.setVpnSetting("protocol") }
        ]
        if (host.step >= actions.length) {
            verify(!host.controller.connectVpnCountry("../bad"), "invalid country was accepted")
            verify(!host.controller.pauseVpn("99h"), "invalid pause duration was accepted")
            verify(!host.controller.setVpnSetting("arbitrary"), "non-allowlisted setting was accepted")
            console.log("QR04N_V2_WIRING_QML_PASS real widget/panel/controller; stub-only argv; invalid inputs rejected")
            Qt.exit(0)
            return
        }
        verify(actions[host.step](), "valid action rejected at step " + host.step)
        checkBusy.start()
    }

    Component.onCompleted: {
        try {
            var controllerUrl = "file:///home/guiestrela/Work/omarchy/quickshell-rise-review/versions/V1/variants/V2/modules/NordVpnController.qml"
            controller = createAt(controllerUrl, { "cli": "/home/guiestrela/Work/omarchy/quickshell-rise-review/tests/fixtures/nordvpn-cli-recording-stub.sh", "refreshInterval": 60000, "enabled": true })
            widget = createAt("file:///home/guiestrela/Work/omarchy/quickshell-rise-review/versions/V1/variants/V2/modules/NordVPNWidget.qml", { "root": host, "width": 150, "height": 28 })
            panel = createAt("file:///home/guiestrela/Work/omarchy/quickshell-rise-review/versions/V1/variants/V2/panels/NordVPNPanel.qml", { "root": host, "controller": controller })
            begin.start()
        } catch (e) { console.error("QR04N_V2_WIRING_FAIL setup", e); Qt.exit(1) }
    }
    Timer {
        id: begin
        interval: 1800
        onTriggered: {
            try {
                if (Quickshell.env("QR04N_STATUS_MODE") === "unavailable") {
                    host.verify(host.controller.vpnState === "Unavailable", "failed stub status was not exposed as unavailable")
                    host.verify(host.widget.nordVpnStatusText === "NordVPN N/A", "unavailable widget state is wrong")
                    host.verify(!host.controller.connectVpn(), "connect was accepted while unavailable")
                    host.verify(!host.controller.setVpnSetting("protocol"), "settings action was accepted while unavailable")
                    host.verify(host.widget.visible, "NordVPN widget was hidden while Network was disabled")
                    host.widget.testClickHandler.clicked(null)
                    host.verify(host.vpnVisible && !host.networkVisible, "VPN panel did not open with Network disabled")
                    afterOpen.start()
                    return
                }
                host.verify(host.controller.vpnState === "Connected" && host.controller.vpnCountry === "Testland", "stub status not parsed")
                host.verify(host.controller.vpnSettings.protocol === "UDP", "stub settings not parsed")
                host.verify(host.controller.statusQueryCount === 1, "expected exactly one shared status poll in this cycle")
                host.verify(host.controller.settingsQueryCount === 1, "expected one settings query in this cycle")
                host.verify(host.widget.visible, "NordVPN widget was hidden while Network was disabled")
                host.widget.testClickHandler.clicked(null)
                host.verify(host.vpnVisible && !host.networkVisible, "widget did not open exclusive VPN state")
                host.verify(host.vpnBarX > 0, "widget did not publish its own anchor")
                afterOpen.start()
            } catch (e) { console.error("QR04N_V2_WIRING_FAIL initial", e); Qt.exit(1) }
        }
    }
    Timer {
        id: afterOpen
        interval: 300
        onTriggered: {
            try {
                host.verify(host.panel.visible, "instantiated VPN panel remained hidden")
                if (Quickshell.env("QR04N_STATUS_MODE") === "unavailable") {
                    host.verify(!host.panel.testToggleHandler.enabled, "VPN action stayed enabled while unavailable")
                    host.verify(!host.panel.testGoHandler.enabled && !host.panel.testProtocolHandler.enabled, "country/protocol controls stayed enabled while unavailable")
                    console.log("QR04N_V2_UNAVAILABLE_QML_PASS unavailable status, Network disabled, own panel remains usable")
                    Qt.exit(0)
                    return
                }
                host.panel.closePanel()
                afterClose.start()
            } catch (e) { console.error("QR04N_V2_WIRING_FAIL open", e); Qt.exit(1) }
        }
    }
    Timer {
        id: afterClose
        interval: 300
        onTriggered: {
            try {
                host.verify(!host.vpnVisible && !host.networkVisible && !host.panel.visible, "VPN panel failed to close independently")
                host.widget.testClickHandler.clicked(null)
                host.verify(host.vpnVisible && !host.networkVisible, "second opening depended on Network")
                host.step = 0
                host.nextAction()
            } catch (e) { console.error("QR04N_V2_WIRING_FAIL close", e); Qt.exit(1) }
        }
    }
    Timer {
        id: checkBusy
        interval: 40
        onTriggered: {
            try {
                host.verify(host.controller.vpnBusy, "accepted action did not expose busy state")
                waitAction.start()
            } catch (e) { console.error("QR04N_V2_WIRING_FAIL busy", e); Qt.exit(1) }
        }
    }
    Timer {
        id: waitAction
        interval: 100
        repeat: true
        onTriggered: {
            if (!host.controller.vpnBusy) {
                stop()
                host.step++
                host.nextAction()
            }
        }
    }
}
