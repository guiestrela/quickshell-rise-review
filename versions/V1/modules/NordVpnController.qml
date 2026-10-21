import QtQuick
import Quickshell.Io
import "NordVpnProtocol.js" as VpnProtocol

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
    property var countryOptions: []
    property string countriesState: "Unavailable"
    property int statusQueryCount: 0
    property int settingsQueryCount: 0
    readonly property bool vpnConnected: vpnState === "Connected"
    readonly property bool vpnBusy: actionProcess.running
        || vpnState === "Connecting" || vpnState === "Disconnecting"
    readonly property bool canMutate: enabled
        && (vpnState === "Connected" || vpnState === "Disconnected") && !vpnBusy
    property string _queryKind: "status"
    property int _settingsGeneration: 0
    property var _selectionRequest: null
    property int _selectionEpoch: 0
    property bool _selectionPending: false
    property string selectionReader: decodeURIComponent(String(Qt.resolvedUrl("../../../scripts/rise-nordvpn-selection")).replace(/^(file|qs):\/\//, ""))

    function refreshSelectionReadback() {
        if (!enabled || !vpnSettings["selection-notice"]
                || vpnSettings["protocol-api"] !== "unified") {
            _selectionPending = false
            return false
        }
        if (!_selectionRequest || _selectionRequest.generation !== _settingsGeneration
                || _selectionRequest.epoch !== _selectionEpoch)
            _selectionPending = true
        return _drainSelectionReadback()
    }
    function _drainSelectionReadback() {
        // Retain ownership through the deferred completion, not just process exit.
        if (_selectionRequest || selectionProbe.running || !_selectionPending) return false
        _selectionPending = false
        if (!enabled || !vpnSettings["selection-notice"]
                || vpnSettings["protocol-api"] !== "unified") return false
        _selectionRequest = { generation: _settingsGeneration, epoch: _selectionEpoch }
        selectionProbe.command = ["python3", selectionReader]
        selectionProbe.running = true
        return true
    }

    function _selectionOutputFinished(text) {
        var request = _selectionRequest
        if (!request) return
        request.output = String(text || "")
        request.outputFinished = true
        _completeSelectionReadback(request)
    }
    function _completeSelectionReadback(request) {
        // Exit and collector completion may arrive in either order. Keep the
        // slot owned until both arrive, then snapshot before deferring delivery.
        if (!request || !request.exited || !request.outputFinished || request.scheduled) return
        request.scheduled = true
        var text = request.output
        var exitCode = request.exitCode
        Qt.callLater(function() {
            if (controller._selectionRequest !== request) return
            if (controller.enabled && exitCode === 0
                    && request.epoch === controller._selectionEpoch
                    && request.generation === controller._settingsGeneration
                    && text.length <= 4096) {
                try {
                    controller.vpnSettings = VpnProtocol.applyDaemonSelection(controller.vpnSettings, JSON.parse(text))
                } catch (error) { /* Keep the explicit unknown state. */ }
            }
            controller._selectionRequest = null
            controller._drainSelectionReadback()
        })
    }

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
    function refreshCountries() {
        if (!enabled || countriesProcess.running) return false
        countriesState = "Loading"
        countriesProcess.running = true
        return true
    }
    function setAutoConnect(isEnabled, country) {
        if (!canMutate || countriesState !== "Ready") return false
        var selected = String(country || "").trim()
        if (isEnabled && countryOptions.indexOf(selected) < 0) return false
        var argv = isEnabled
            ? [cli, "set", "autoconnect", "enabled", selected]
            : [cli, "set", "autoconnect", "disabled"]
        vpnActionMessage = "Updating auto-connect…"
        return _runAction(argv)
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
        if (!/^[A-Za-z][A-Za-z_ -]{0,63}$/.test(target)
                || countriesState !== "Ready" || countryOptions.indexOf(target) < 0 || !canMutate) {
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
        // NordVPN returns an error for ALREADY_SET. Avoid a redundant write;
        // DNS order is immaterial to its own equality check as well.
        var configured = String(vpnSettings.dns || "").trim().split(/[\s,]+/).filter(function(value) { return value.length > 0 })
        if (configured.slice().sort().join(",") === servers.slice().sort().join(",")) {
            vpnActionMessage = "DNS already configured: " + servers.join(", ")
            return true
        }
        vpnActionMessage = "Updating DNS servers…"
        return _runAction([cli, "set", "dns"].concat(servers))
    }
    function resetDnsServers() {
        if (!canMutate) return false
        vpnMessage = ""
        if (/^(disabled|off|default)$/i.test(String(vpnSettings.dns || "").trim())) {
            vpnActionMessage = "Custom DNS is already disabled"
            return true
        }
        vpnActionMessage = "Resetting DNS…"
        return _runAction([cli, "set", "dns", "off"])
    }
    function setVpnSetting(key, requestedValue) {
        if (!canMutate) return false
        var allowed = {
            firewall: ["firewall", "firewall"],
            "kill-switch": ["killswitch", "kill-switch"],
            "auto-connect": ["autoconnect", "auto-connect"],
            technology: ["technology", "technology"],
            protocol: ["protocol", "protocol"],
            "threat-protection-lite": ["protection", "protection"],
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
        var value
        if (key === "technology") {
            value = String(requestedValue || "").toUpperCase()
            if (["OPENVPN", "NORDLYNX", "NORDWHISPER"].indexOf(value) < 0) return false
        } else if (key === "protocol") {
            value = String(requestedValue || "").toUpperCase()
            if (value !== "TCP" && value !== "UDP") return false
        } else {
            value = /^(enabled|on|yes|true)$/.test(current) ? "off" : "on"
        }
        // NordVPN refuses Routing OFF while Meshnet is enabled, but its CLI
        // can return exit 0 for that dependency warning. Never claim success.
        if (key === "routing" && value === "off"
                && /^(enabled|on|yes|true)$/i.test(String(vpnSettings.meshnet || ""))) {
            vpnMessage = "Routing is required by Meshnet. Turn Meshnet off first to disable Routing. Disabling Routing stops VPN traffic routing."
            vpnActionMessage = "Routing unchanged: Meshnet is enabled"
            return false
        }
        if (key === "post-quantum-vpn" && value === "on") {
            if (/^(enabled|on|yes|true)$/i.test(String(vpnSettings.meshnet || ""))) {
                vpnMessage = "Post-quantum VPN is incompatible with Meshnet. Turn Meshnet off first; no settings were changed."
                vpnActionMessage = "Post-quantum VPN unchanged: Meshnet is enabled"
                return false
            }
            if (String(vpnSettings.technology || "").toUpperCase() !== "NORDLYNX") {
                vpnMessage = "Post-quantum VPN requires NordLynx. Select NordLynx first; no settings were changed."
                vpnActionMessage = "Post-quantum VPN unchanged: NordLynx is required"
                return false
            }
        }
        // NordVPN 6 removed `set technology`; all choices use unified protocol.
        if ((key === "technology" || key === "protocol") && vpnSettings["protocol-api"] === "unified") {
            if (vpnSettings["selection-notice"] || vpnSettings["selection-write-notice"]) {
                vpnMessage = String(vpnSettings["selection-notice"] || vpnSettings["selection-write-notice"])
                vpnActionMessage = vpnSettings["selection-notice"]
                    ? "Protocol unchanged: current selection unavailable"
                    : "Protocol unchanged: writes blocked by CLI/daemon version mismatch"
                return false
            }
            var unified = key === "protocol" ? (value === "TCP" ? "openvpn_tcp" : "openvpn_udp")
                : value === "NORDLYNX" ? "nordlynx"
                : value === "NORDWHISPER" ? "nordwhisper"
                : String(vpnSettings.protocol || "").toUpperCase() === "TCP" ? "openvpn_tcp" : "openvpn_udp"
            vpnMessage = ""
            vpnActionMessage = "Setting VPN protocol to " + unified + "…"
            return _runAction([cli, "set", "protocol", unified])
        }
        vpnMessage = ""
        vpnActionMessage = key === "technology" ? "Setting VPN technology to " + value + "…"
            : key === "protocol" ? "Setting OpenVPN protocol to " + value + "…"
            : key === "threat-protection-lite" ? "Updating Real-time Protection…"
            : "Updating " + key + "…"
        return _runAction([cli, "set", allowed[key][0], value])
    }
    function _runAction(argv) {
        if (!enabled || actionProcess.running) return false
        vpnMessage = ""
        actionProcess.command = argv
        actionProcess.running = true
        return true
    }

    onEnabledChanged: {
            if (!enabled) {
                _selectionEpoch += 1
                _selectionPending = false
                if (selectionProbe.running) selectionProbe.running = false
                if (queryProcess.running) queryProcess.running = false
                if (countriesProcess.running) countriesProcess.running = false
                countriesState = "Unavailable"
                countryOptions = []
                vpnState = "Unknown"
                vpnCountry = ""
                vpnServer = ""
            } else {
                refreshCountries()
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
                        if (match) {
                            var settingKey = match[1].trim().toLowerCase().replace(/\s+/g, "-")
                            if (settingKey === "real-time-protection" || settingKey === "protection")
                                settingKey = "threat-protection-lite"
                            parsed[settingKey] = match[2].trim()
                        }
                    }
                    controller._settingsGeneration += 1
                    controller.vpnSettings = VpnProtocol.normalizeSettings(parsed)
                    controller.refreshSelectionReadback()
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
                // Status polling is not an action result; retain errors until
                // the next user action rather than erasing their explanation.
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
        id: selectionProbe
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: controller._selectionOutputFinished(String(this.text || ""))
        }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(exitCode) {
            var request = controller._selectionRequest
            if (!request) return
            request.exitCode = exitCode
            request.exited = true
            controller._completeSelectionReadback(request)
        }
    }

    Process {
        id: actionProcess
        command: [controller.cli, "status"]
        running: false
        stdout: StdioCollector { id: actionStdout; waitForEnd: true }
        stderr: StdioCollector { id: actionStderr; waitForEnd: true }
        onExited: function(exitCode) {
            // stdout carries dependency warnings even when NordVPN exits 0.
            // Wait until collectors drain, and preserve the actual CLI response.
            Qt.callLater(function() {
                var response = String(actionStdout.text || "")
                    .replace(/\x1b\[[0-?]*[ -\/]*[@-~]/g, "").replace(/\r/g, "").trim()
                var error = String(actionStderr.text || "")
                    .replace(/\x1b\[[0-?]*[ -\/]*[@-~]/g, "").replace(/\r/g, "").trim()
                controller.vpnMessage = exitCode !== 0
                    ? error || response || "NordVPN command failed" : error
                controller.vpnActionMessage = exitCode === 0
                    ? response || "NordVPN command completed"
                    : "NordVPN command failed"
                refreshTimer.restart()
                settingsTimer.restart()
            })
        }
    }

    Process {
        id: countriesProcess
        command: [controller.cli, "countries"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
        var lines = String(this.text || "").split("\n")
                var unique = []
                for (var i = 0; i < lines.length && unique.length < 300; i++) {
                    var name = lines[i].trim()
                    if (/^[A-Za-z0-9_ -]{1,64}$/.test(name) && unique.indexOf(name) < 0)
                        unique.push(name)
                }
                controller.countryOptions = unique
                controller.countriesState = unique.length ? "Ready" : "Empty"
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                controller.countryOptions = []
                controller.countriesState = "Error"
            }
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
