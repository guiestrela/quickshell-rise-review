import QtQuick
import QtQuick.Window
import Quickshell

Window {
    id: host
    visible: true
    width: 800
    height: 500
    property bool vpnVisible: false
    property bool networkVisible: false
    property var activePopupScreen: Quickshell.screens[0]
    property real networkBarX: width / 2
    property real vpnBarX: width / 2
    property string barPosition: "top"
    property int pillRadius: 8
    property color bg: "#181818"
    property color pillBorder: "#444444"
    property int pillBorderW: 1
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
    property int tileRadius: 5
    property color color01: "#ff6666"
    property var calls: []
    property var controller: ({
        vpnState: "Connected", vpnCountry: "US", vpnConnected: true, vpnBusy: false,
        vpnSettings: ({ firewall: "enabled", "kill-switch": "disabled", "threat-protection-lite": "disabled", "auto-connect": "enabled", technology: "NordLynx", protocol: "udp" }),
        vpnActionMessage: "", vpnMessage: "",
        connectVpn: function() { host.calls.push(["connectVpn"]) },
        disconnectVpn: function() { host.calls.push(["disconnectVpn"]) },
        connectVpnCountry: function(country) { host.calls.push(["connectVpnCountry", country]) },
        pauseVpn: function(duration) { host.calls.push(["pauseVpn", duration]) },
        setVpnSetting: function(key) { host.calls.push(["setVpnSetting", key]) }
    })
    property var panel: null
    function findNamed(item, name) {
        if (item.objectName === name) return item
        var descendants = item.children || []
        for (var i = 0; i < descendants.length; ++i) {
            var found = findNamed(descendants[i], name)
            if (found) return found
        }
        return null
    }
    function fire(name) {
        var target = host.panel.testTargets[name] || ({"vpn-toggle": host.panel.testToggleHandler, "vpn-country": host.panel.testCountryInput, "vpn-go": host.panel.testGoHandler, "vpn-protocol": host.panel.testProtocolHandler, "vpn-close": host.panel.testCloseHandler})[name]
        if (!target || !target.enabled) throw new Error("missing/disabled handler target: " + name)
        target.clicked(null)
    }
    function expectCalls(expected, label) {
        if (JSON.stringify(host.calls) !== JSON.stringify(expected)) {
            throw new Error(label + " expected " + JSON.stringify(expected) + " got " + JSON.stringify(host.calls))
        }
        host.calls = []
    }
    Component.onCompleted: {
        var component = Qt.createComponent("file:///home/guiestrela/Work/omarchy/quickshell-rise-review/versions/V1/panels/NordVPNPanel.qml")
        if (component.status !== Component.Ready) {
            console.error("QR04N_PANEL_FAIL component", component.errorString())
            Qt.exit(1)
            return
        }
        host.panel = component.createObject(host, {"root": host, "controller": host.controller})
    }
    Timer {
        interval: 350; running: true
        onTriggered: {
            try {
                host.vpnVisible = true
                checkOpen.start()
            } catch (e) { console.error("QR04N_PANEL_FAIL", e); Qt.exit(1) }
        }
    }
    Timer {
        id: checkOpen
        interval: 250
        onTriggered: {
            try {
                if (!host.panel || !host.panel.visible || host.networkVisible) throw new Error("panel did not open independently")
                host.fire("vpn-toggle")
                host.expectCalls([["disconnectVpn"]], "connected toggle")
                host.controller = Object.assign({}, host.controller, { vpnConnected: false, vpnState: "Disconnected" })
                host.panel.controller = host.controller
                host.fire("vpn-toggle")
                host.expectCalls([["connectVpn"]], "disconnected toggle")

                host.panel.countryTarget = "Canada"
                host.fire("vpn-go")
                host.expectCalls([["connectVpnCountry", "Canada"]], "country go")
                var country = host.panel.testCountryInput
                if (!country) throw new Error("country input missing")
                country.text = "Japan"
                host.panel.countryTarget = "Japan"
                country.accepted()
                host.expectCalls([["connectVpnCountry", "Japan"]], "country Enter/accepted")

                var settings = ["firewall", "kill-switch", "threat-protection-lite", "auto-connect", "technology"]
                for (var i = 0; i < settings.length; ++i) {
                    host.fire("vpn-setting-" + settings[i])
                    host.expectCalls([["setVpnSetting", settings[i]]], "setting " + settings[i])
                }
                host.fire("vpn-protocol")
                host.expectCalls([["setVpnSetting", "protocol"]], "protocol")

                var pauses = ["5m", "15m", "30m", "1h", "24h"]
                for (var j = 0; j < pauses.length; ++j) {
                    host.panel.testPauseSelectorHandler.clicked(null)
                    host.fire("vpn-pause-" + pauses[j])
                    host.expectCalls([], "select duration without action " + pauses[j])
                    host.panel.testPauseApplyHandler.clicked(null)
                    host.expectCalls([["pauseVpn", pauses[j]]], "pause " + pauses[j])
                }

                host.vpnVisible = true
                host.fire("vpn-close")
                verifyClose.start()
            } catch (e) { console.error("QR04N_PANEL_FAIL handlers", e); Qt.exit(1) }
        }
    }
    Timer {
        id: verifyClose
        interval: 250
        onTriggered: {
            if (host.vpnVisible || host.networkVisible || host.panel.visible) { console.error("QR04N_PANEL_FAIL independent close"); Qt.exit(1); return }
            console.log("QR04N_PANEL_QML_PASS isolated signal-handler coverage: toggle x2, country go/accepted, 5 settings, protocol, 5 pauses, close")
            Qt.exit(0)
        }
    }
}
