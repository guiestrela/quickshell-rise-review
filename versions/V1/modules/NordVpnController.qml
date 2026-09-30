import QtQuick
import Quickshell.Io

// One V1-scoped NordVPN owner shared by every bar slot and both VPN/network
// surfaces. All CLI input is passed as argv; no shell command strings.
Item {
    id: controller

    property bool enabled: false
    property int refreshInterval: 15000
    property string cli: "nordvpn"
    property string vpnState: "Unknown"
    property string vpnCountry: ""
    property string vpnServer: ""
    property string vpnMessage: ""
    property string vpnActionMessage: ""
    property var vpnSettings: ({})
    property int statusQueryCount: 0
    property int settingsQueryCount: 0
    readonly property bool vpnConnected: vpnState === "Connected"
    readonly property bool vpnBusy: actionProcess.running
        || vpnState === "Connecting" || vpnState === "Disconnecting"
    readonly property bool canMutate: enabled
        && (vpnState === "Connected" || vpnState === "Disconnected") && !vpnBusy
    readonly property string unsupportedSettingsReason: "Not supported by NordVPN CLI 5.4.0"

    property string _queryKind: "status"

    function _startQuery(kind) {
        if (!enabled || queryProcess.running) return false
        _queryKind = kind
        queryProcess.command = [cli, kind]
        queryProcess.running = true
        if (kind === "status") statusQueryCount += 1
        else settingsQueryCount += 1
        return true
    }
    function refresh() {
        _startQuery("status")
    }
    function refreshSettings() {
        _startQuery("settings")
    }

    function connectVpn() {
        if (!canMutate) return false
        vpnMessage = ""
        vpnState = "Connecting"
        return _runAction([cli, "connect"])
    }
    function disconnectVpn() {
        if (!canMutate) return false
        vpnMessage = ""
        vpnState = "Disconnecting"
        return _runAction([cli, "disconnect"])
    }
    function connectVpnCountry(country) {
        var target = String(country || "").trim()
        if (!/^[a-zA-Z0-9][a-zA-Z0-9 -]{0,39}$/.test(target) || !canMutate) {
            vpnMessage = "Enter a valid country name or code"
            return false
        }
        vpnMessage = ""
        vpnState = "Connecting"
        return _runAction([cli, "connect", target])
    }
    function pauseVpn(duration) {
        var allowed = ["5m", "15m", "30m", "1h", "24h"]
        if (allowed.indexOf(String(duration)) < 0 || !canMutate) return false
        vpnActionMessage = "Pausing NordVPN for " + duration + "…"
        return _runAction([cli, "pause", String(duration)])
    }
    function setDnsServers(input) {
        if (!canMutate) return false
        var raw = String(input || "").trim()
        var servers = raw ? raw.split(/[\s,]+/).filter(function(value) { return value.length > 0 }) : []
        if (servers.length < 1 || servers.length > 3 || servers.some(function(address) {
            var octets = address.split(".")
            return octets.length !== 4 || octets.some(function(part) {
                return !/^(0|[1-9][0-9]{0,2})$/.test(part) || Number(part) > 255
            })
        })) {
            vpnMessage = "Enter 1–3 valid IPv4 DNS addresses"
            return false
        }
        vpnMessage = ""
        vpnActionMessage = "Updating DNS servers…"
        return _runAction([cli, "set", "dns"].concat(servers))
    }
    function resetDnsServers() {
        if (!canMutate) return false
        vpnMessage = ""
        vpnActionMessage = "Resetting DNS…"
        return _runAction([cli, "set", "dns", "off"])
    }
    function setVpnSetting(key) {
        if (!canMutate) return false
        if (key === "protocol" || key === "threat-protection-lite") {
            vpnActionMessage = unsupportedSettingsReason
            return false
        }
        var allowed = {
            firewall: ["firewall", "firewall"],
            "kill-switch": ["killswitch", "kill-switch"],
            "auto-connect": ["autoconnect", "auto-connect"],
            technology: ["technology", "technology"],
            notify: ["notify", "notify"],
            tray: ["tray", "tray"],
            meshnet: ["meshnet", "meshnet"],
            "lan-discovery": ["lan-discovery", "lan-discovery"],
            routing: ["routing", "routing"],
            "virtual-location": ["virtual-location", "virtual-location"],
            "arp-ignore": ["arp-ignore", "arp-ignore"],
            "post-quantum-vpn": ["post-quantum", "post-quantum-vpn"]
        }

        if (!Object.prototype.hasOwnProperty.call(allowed, key)) return false
        var current = String(vpnSettings[key] || "disabled").toLowerCase()
        var value = /^(enabled|on|yes|true)$/.test(current) ? "off" : "on"
        if (key === "technology") value = current.indexOf("nordlynx") >= 0 ? "OpenVPN" : "NordLynx"
        vpnActionMessage = "Updating " + key + "…"
        return _runAction([cli, "set", allowed[key][0], value])
    }
    function _runAction(argv) {
        if (!enabled || actionProcess.running) return false
        actionProcess.command = argv
        actionProcess.running = true
        return true
    }

    onEnabledChanged: {
        if (!enabled) {
            if (queryProcess.running) queryProcess.running = false
            vpnState = "Unknown"
            vpnCountry = ""
            vpnServer = ""
        }
    }

    Process {
        id: queryProcess
        command: [controller.cli, "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(this.text || "")
                if (controller._queryKind === "settings") {
                    var parsed = ({})
                    var lines = raw.split("\n")
                    for (var i = 0; i < lines.length; i++) {
                        var match = lines[i].match(/^\s*([^:]+):\s*(.*?)\s*$/)
                        if (match) parsed[match[1].trim().toLowerCase().replace(/\s+/g, "-")] = match[2].trim()
                    }
                    controller.vpnSettings = parsed
                    return
                }
                var state = raw.match(/^Status\s*:\s*(.+)$/im)
                var country = raw.match(/^Country\s*:\s*(.+)$/im)
                var server = raw.match(/^Server\s*:\s*(.+)$/im)
                if (!state) {
                    controller.vpnState = "Unknown"
                    controller.vpnCountry = ""
                    controller.vpnServer = ""
                    return
                }
                var value = state[1].trim()
                controller.vpnState = /^connected/i.test(value) ? "Connected"
                    : /connecting/i.test(value) ? "Connecting"
                    : /disconnecting/i.test(value) ? "Disconnecting" : "Disconnected"
                controller.vpnCountry = country ? country[1].trim() : ""
                controller.vpnServer = server ? server[1].trim() : ""
                if (!controller.vpnBusy) controller.vpnMessage = ""
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                if (controller._queryKind === "status") controller.vpnState = "Unavailable"
                else controller.vpnSettings = ({})
            }
        }
    }

    Process {
        id: actionProcess
        command: [controller.cli, "status"]
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                var message = String(this.text || "").trim()
                if (message) controller.vpnMessage = message
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && controller.vpnMessage === "") controller.vpnMessage = "NordVPN command failed"
            if (exitCode === 0) controller.vpnActionMessage = "NordVPN command completed"
            else controller.vpnActionMessage = "NordVPN command failed"
            refreshTimer.restart()
            settingsTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 1000
        repeat: false
        onTriggered: controller.refresh()
    }
    Timer {
        id: settingsTimer
        interval: 1100
        repeat: false
        onTriggered: controller.refreshSettings()
    }
    Timer {
        interval: Math.max(2000, controller.refreshInterval)
        running: controller.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            controller.refresh()
            settingsTimer.restart()
        }
    }
}
