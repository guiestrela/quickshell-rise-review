import QtQuick
import Quickshell
import Quickshell.Io

// Native Omarchy helpers, one in-flight query per kind, only while open.
Item {
    id: diagnostics
    property bool panelOpen: false
    property string networkMode: "none"
    property string connectivity: "unknown"
    property string sampleInterface: ""
    property var routerSamples: []
    property var internetSamples: []
    property real routerMs: -1
    property real internetMs: -1
    property real lastInternetPingMs: -1
    property int packetLoss: -1
    property string currentBand: ""
    property string selectedBand: "auto"
    property var availableBands: []
    property string pendingBand: ""
    readonly property bool bandBusy: bandAction.running
    readonly property bool canSelectBand: (networkMode === "wifi" || bandBusy)
        && (availableBands.length > 1 || selectedBand !== "auto")
    property string bandError: ""
    property string diagnosticError: ""
    signal portalOpening()

    function fields(raw) {
        var result = {}
        for (var line of String(raw).split("\n")) {
            var tab = line.indexOf("\t")
            if (tab > 0) result[line.slice(0, tab)] = line.slice(tab + 1).trim()
        }
        return result
    }
    function average(samples) {
        var values = samples.slice(-5).filter(function(value) { return value >= 0 })
        if (!values.length) return -1
        return values.reduce(function(sum, value) { return sum + value }, 0) / values.length
    }
    function sample(value) {
        if (value === undefined || value === "") return -1
        var number = Number(value)
        return isFinite(number) && number >= 0 ? number : -1
    }
    function resetSamples() {
        routerSamples = []; internetSamples = []
        routerMs = -1; internetMs = -1; lastInternetPingMs = -1; packetLoss = -1
    }
    function acceptStatus(raw) {
        var data = fields(raw)
        var iface = String(data.iface || "")
        if (iface !== sampleInterface) { resetSamples(); sampleInterface = iface }
        if (!iface) { resetSamples(); return }
        if (data.router_ping_ms !== undefined)
            routerSamples = routerSamples.concat([sample(data.router_ping_ms)]).slice(-24)
        if (data.internet_ping_ms !== undefined) {
            lastInternetPingMs = sample(data.internet_ping_ms)
            internetSamples = internetSamples.concat([lastInternetPingMs]).slice(-24)
        }
        routerMs = average(routerSamples)
        internetMs = average(internetSamples)
        packetLoss = internetSamples.length
            ? Math.round(100 * internetSamples.filter(function(value) { return value < 0 }).length / internetSamples.length) : -1
        diagnosticError = ""
    }
    function acceptBand(raw) {
        var data = fields(raw)
        var allowed = ["2.4", "5", "6"]
        var selected = data.selected || "auto"
        if (selected !== "auto" && allowed.indexOf(selected) < 0) return false
        currentBand = allowed.indexOf(data.band) >= 0 ? data.band : ""
        selectedBand = selected
        availableBands = allowed.filter(function(band) {
            return String(data.available || "").split(/\s+/).indexOf(band) >= 0 || band === data.band
        })
        return true
    }
    function refresh() {
        if (!panelOpen) return
        if (networkMode !== "none" && !statusQuery.running) statusQuery.running = true
        if (networkMode === "wifi" && !bandAction.running && !bandQuery.running) bandQuery.running = true
    }
    function setBand(band) {
        if (!panelOpen || !canSelectBand || bandBusy || bandQuery.running
                || (band !== "auto" && availableBands.indexOf(band) < 0)) return false
        if (band === selectedBand) return false
        bandError = ""
        pendingBand = band
        bandAction.command = ["omarchy-network-band", band]
        bandAction.running = true
        return true
    }
    function openPortal() {
        if (!panelOpen || connectivity !== "portal") return false
        portalOpening()
        // Fixed official probe URL; the native helper handles redirects and
        // temporary Tailscale exit-node pause/restore during sign-in.
        Quickshell.execDetached(["omarchy-network-captive-portal", "http://ping.omacom.io/nm-check.txt"])
        return true
    }

    Process {
        id: statusQuery
        command: ["timeout", "8", "omarchy-network-status", "--verbose"]
        stdout: StdioCollector { id: statusOutput; waitForEnd: true }
        onExited: (code) => {
            if (!diagnostics.panelOpen) return
            if (code === 0) diagnostics.acceptStatus(statusOutput.text)
            else { diagnostics.resetSamples(); diagnostics.diagnosticError = "Connection diagnostics unavailable" }
        }
    }
    Process {
        id: bandQuery
        command: ["timeout", "8", "omarchy-network-band"]
        stdout: StdioCollector { id: bandOutput; waitForEnd: true }
        onExited: (code) => {
            if (!diagnostics.panelOpen || diagnostics.bandBusy) return
            if (code === 0) diagnostics.acceptBand(bandOutput.text)
            else { diagnostics.availableBands = []; diagnostics.currentBand = "" }
        }
    }
    Process {
        id: bandAction
        command: []
        // The native helper restores the prior band if reconnection fails.
        // Let that finish even when the user closes the panel.
        onExited: (code) => {
            diagnostics.pendingBand = ""
            if (code !== 0) diagnostics.bandError = "Could not change band. The native helper attempted to restore the previous connection."
            diagnostics.refresh()
        }
    }
    Timer { interval: 3000; running: diagnostics.panelOpen; repeat: true; onTriggered: diagnostics.refresh() }
    onPanelOpenChanged: {
        if (panelOpen) refresh()
        else { statusQuery.running = false; bandQuery.running = false }
    }
    onNetworkModeChanged: {
        statusQuery.running = false; bandQuery.running = false
        resetSamples(); sampleInterface = ""
        if (networkMode !== "wifi" && !bandBusy) { availableBands = []; currentBand = ""; selectedBand = "auto" }
        refresh()
    }
}
