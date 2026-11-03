import QtQuick
import QtQuick.Window
import Quickshell

Window {
    id: host
    visible: false
    width: 800
    height: 500
    property bool vpnVisible: false
    property bool networkVisible: false
    property var activePopupScreen: Quickshell.screens[0]
    property real networkBarX: width / 2
    property real vpnBarX: width / 2
    property string barPosition: "top"
    property bool barVertical: false
    property int verticalBarWidth: 40
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
    property color fillActive: "#403030"
    property color fillIdle: "#222222"
    property color fillHover: "#333333"
    property string mono: "monospace"
    property int tileRadius: 5
    property color color01: "#ff6666"
    property var calls: []
    property QtObject controller: QtObject {
        id: fixtureController
        property string vpnState: "Connected"
        property string vpnCountry: "US"
        property bool vpnConnected: true
        property bool vpnBusy: false
        property bool canMutate: true
        property string countriesState: "Ready"
        property var countryOptions: ["Canada", "Japan"]
        property string preferredCountry: ""
        property string preferredAutoCountry: "Canada"
        property var vpnSettings: ({firewall:"enabled", "kill-switch":"disabled", "threat-protection-lite":"disabled", "auto-connect":"enabled", technology:"NORDLYNX", protocol:"UDP"})
        property string vpnActionMessage: ""
        property string vpnMessage: ""
        function connectVpn() { host.calls.push(["connectVpn"]) }
        function disconnectVpn() { host.calls.push(["disconnectVpn"]) }
        function connectVpnCountry(country) { host.calls.push(["connectVpnCountry", country]) }
        function pauseVpn(duration) { host.calls.push(["pauseVpn", duration]) }
        function setVpnSetting(key, value) { host.calls.push(value === undefined ? ["setVpnSetting", key] : ["setVpnSetting", key, value]) }
        function selectPreferredCountry(country, auto) {
            host.calls.push(["selectPreferredCountry", country, auto])
            if (auto) preferredAutoCountry = country
            else preferredCountry = country
            return true
        }
        function setAutoConnect(enabled, country) { host.calls.push(["setAutoConnect", enabled, country]); return true }
    }
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
        var target = host.panel.testTargets[name] || host.findNamed(host.panel.contentItem, name) || ({"vpn-toggle": host.panel.testToggleHandler, "vpn-go": host.panel.testGoHandler, "vpn-protocol": host.panel.testProtocolHandler, "vpn-close": host.panel.testCloseHandler})[name]
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
        var component = Qt.createComponent(Qt.resolvedUrl("../../variants/V1/panels/NordVPNPanel.qml"))
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
                fixtureController.vpnConnected = false
                fixtureController.vpnState = "Disconnected"
                host.fire("vpn-toggle")
                host.expectCalls([["connectVpn"]], "disconnected toggle")

                host.fire("vpn-country-select")
                if (!host.panel.countryChooserExpanded) throw new Error("country chooser did not open")
                host.fire("vpn-country-option-Canada")
                host.expectCalls([["selectPreferredCountry", "Canada", false]], "country selection")
                if (host.panel.countryTarget !== "Canada" || host.panel.countryChooserExpanded) throw new Error("country selection not reflected")
                host.fire("vpn-go")
                host.expectCalls([["connectVpnCountry", "Canada"]], "country connect")
                host.fire("vpn-country-select")
                host.fire("vpn-country-option-Japan")
                host.expectCalls([["selectPreferredCountry", "Japan", false]], "second country selection")
                host.fire("vpn-go")
                host.expectCalls([["connectVpnCountry", "Japan"]], "second country connect")

                for (var key of ["firewall", "kill-switch", "threat-protection-lite"]) {
                    host.fire("vpn-setting-" + key)
                    host.expectCalls([["setVpnSetting", key]], "security " + key)
                }
                host.fire("vpn-autoconnect-toggle")
                host.expectCalls([["setAutoConnect", false, "Canada"]], "auto-connect toggle")
                host.fire("vpn-autoconnect-country-select")
                host.fire("vpn-autoconnect-country-Japan")
                host.expectCalls([["selectPreferredCountry", "Japan", true]], "auto-connect country")
                host.fire("vpn-autoconnect-apply")
                host.expectCalls([["setAutoConnect", true, "Japan"]], "auto-connect apply")
                for (var technology of ["OPENVPN", "NORDLYNX", "NORDWHISPER"]) {
                    host.fire("vpn-technology-" + technology.toLowerCase())
                    host.expectCalls([["setVpnSetting", "technology", technology]], "technology " + technology)
                }
                host.fire("vpn-protocol")
                host.expectCalls([["setVpnSetting", "protocol", "UDP"]], "UDP")
                host.fire("vpn-protocol-tcp")
                host.expectCalls([["setVpnSetting", "protocol", "TCP"]], "TCP")

                fixtureController.canMutate = false
                for (var name of ["vpn-toggle", "vpn-country-connect", "vpn-autoconnect-toggle", "vpn-autoconnect-apply", "vpn-setting-firewall", "vpn-protocol", "vpn-protocol-tcp", "vpn-technology-openvpn"]) {
                    var target = host.panel.testTargets[name] || host.findNamed(host.panel.contentItem, name)
                    if (!target || target.enabled) throw new Error("busy control must be disabled: " + name)
                }
                host.expectCalls([], "disabled controls do not dispatch")
                fixtureController.canMutate = true

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
            console.log("QR04N_PANEL_QML_PASS isolated signal-handler coverage: toggle x2, country selection/connect, security, auto-connect, technology, protocol, busy controls, 5 pauses, close")
            Qt.exit(0)
        }
    }
}
