import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: controller
    required property var theme
    readonly property string helperPath: String(Quickshell.env("RISE_DISPLAY_MANAGER_APPLY") || "")
        || (Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise/scripts/rise-display-manager-apply")
    readonly property string guardPath: String(Quickshell.env("RISE_DISPLAY_MANAGER_GUARD") || "") || helperPath.replace(/[^/]+$/, "rise-display-manager-guard")
    property string rollbackToken: ""
    readonly property bool rollbackPending: rollbackToken !== ""
    property int rollbackSeconds: 0
    readonly property int confirmationSeconds: 5
    property bool guardedAction: false
    property bool confirmationBusy: false
    function confirmChanges() { resolveChanges("--confirm") }
    function revertChanges() { resolveChanges("--revert") }
    function resolveChanges(action) {
        if (!rollbackPending || confirmationBusy) return
        confirmationBusy = true
        confirmationProc.command = [guardPath, action, rollbackToken]
        confirmationProc.running = true
    }
    function updateRollback(text) {
        var data = JSON.parse(text)
        if (!data || !/^[0-9a-f]{32}$/.test(String(data.token || "")) || (rollbackPending && rollbackToken !== data.token)) throw new Error("Invalid confirmation response")
        if (data.status === "pending") {
            rollbackToken = data.token
            rollbackSeconds = Math.max(0, Math.min(confirmationSeconds, Number(data.remaining || 0)))
        } else if (["confirmed", "reverted", "failed"].indexOf(data.status) >= 0) {
            rollbackToken = ""
            rollbackSeconds = 0
            if (data.status === "reverted") error = "Previous display configuration restored."
            else if (data.status === "failed") error = "Automatic rollback failed: " + String(data.error || "Check display state.")
            else error = ""
            refresh(true)
        } else throw new Error("Invalid confirmation status")
    }
    Timer {
        interval: 1000; running: controller.rollbackPending; repeat: true
        onTriggered: {
            if (controller.rollbackSeconds > 0) controller.rollbackSeconds--
            if (!statusProc.running && !controller.confirmationBusy) {
                statusProc.command = [controller.guardPath, "--status", controller.rollbackToken]
                statusProc.running = true
            }
        }
    }
    Process {
        id: statusProc
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: (code) => {
            if (!controller.rollbackPending || controller.confirmationBusy) return
            if (code !== 0) { controller.error = String(stderr.text || "Could not verify rollback state.").trim(); return }
            try { controller.updateRollback(String(stdout.text)) }
            catch (e) { controller.error = String(e) }
        }
    }
    Process {
        id: confirmationProc
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: (code) => {
            controller.confirmationBusy = false
            if (code !== 0) { controller.error = String(stderr.text || "Confirmation failed; automatic rollback remains armed.").trim(); return }
            try { controller.updateRollback(String(stdout.text)) }
            catch (e) { controller.error = String(e) }
        }
    }
    property var monitors: []
    property var displays: []
    property string selectedMonitor: ""
    property string error: ""
    property bool busy: false
    property bool loading: false
    property int actionTimeoutMs: 15000
    property bool actionTimedOut: false
    property int queryTimeoutMs: 15000
    property bool queryTimedOut: false
    property bool refreshPending: false
    property int pendingTextSizeIndex: -1
    Timer {
        interval: Math.max(100, controller.queryTimeoutMs)
        running: controller.loading
        onTriggered: {
            controller.queryTimedOut = true
            controller.refreshPending = false
            monitorProc.running = false
            stateProc.running = false
            controller.brightnessAvailable = false
            controller.error = "Display query timed out; refresh to retry."
            controller.loading = false
        }
    }
    Timer {
        interval: Math.max(100, controller.actionTimeoutMs)
        running: controller.busy
        onTriggered: {
            controller.actionTimedOut = true
            controller.pendingTextSizeIndex = -1
            actionProc.running = false
            controller.error = "Display operation timed out; runtime state must be checked."
            controller.busy = false
            controller.refresh(true)
        }
    }
    property bool brightnessAvailable: false
    property int brightnessPercent: 0
    property string focusedMonitor: ""
    property var positions: ({})
    property int textSizeIndex: 3
    readonly property var textSizeStops: [9, 10, 11, 12, 14, 16, 20]
    readonly property var scalePresets: [1, 1.25, 1.5, 1.6, 2, 3, 4]
    readonly property var transformPresets: [0, 1, 2, 3]

    function safeMonitor(name) { return typeof name === "string" && /^[A-Za-z0-9_.:-]{1,64}$/.test(name) }
    function monitor(name) {
        for (var i = 0; i < monitors.length; i++) if (monitors[i].name === name) return monitors[i]
        return null
    }
    function refresh(preserveError) {
        if (busy || loading) { refreshPending = true; return }
        refreshPending = false
        queryTimedOut = false
        loading = true
        if (!preserveError) error = ""
        monitorProc.command = [helperPath, "--action", "monitors"]
        monitorProc.running = true
        stateProc.command = ["omarchy-monitor-state"]
        stateProc.running = true
    }
    function command(args) {
        if (rollbackPending) { error = "Keep or revert the pending configuration first."; return false }
        if (busy || loading) { error = "Another display operation or query is still running."; return false }
        actionTimedOut = false
        pendingTextSizeIndex = -1
        busy = true
        error = ""
        guardedAction = args[1] === "monitor" || args[1] === "disable"
        actionProc.command = guardedAction ? [guardPath, "--apply", JSON.stringify(args), "--seconds", String(confirmationSeconds)] : [helperPath].concat(args)
        actionProc.running = true
        return true
    }
    function applyMonitor(name, mode, x, y, scale, transform, mirror) {
        mode = String(mode).replace(/Hz$/, "")
        if (!safeMonitor(name) || !monitor(name) || mirror === name
            || (mirror !== "none" && (!safeMonitor(mirror) || !monitor(mirror)))
            || Math.abs(Number(x)) > 32767 || Math.abs(Number(y)) > 32767
            || !/^(preferred|[1-9][0-9]{1,4}x[1-9][0-9]{1,4}(@[1-9][0-9]{0,2}(\.[0-9]{1,3})?)?)$/.test(mode)
            || !isFinite(Number(scale)) || Number(scale) < 0.1 || Number(scale) > 4
            || !Number.isInteger(Number(transform)) || Number(transform) < 0 || Number(transform) > 7
            || !Number.isInteger(Number(x)) || !Number.isInteger(Number(y))) {
            error = "Invalid display configuration; no command was sent."; return false
        }
        return command(["--action", "monitor", "--monitor", name, "--mode", String(mode), "--x", String(x), "--y", String(y),
                       "--scale", String(scale), "--transform", String(transform), "--mirror", safeMonitor(mirror) ? mirror : "none"])
    }
    function disableMonitor(name) {
        if (!safeMonitor(name) || !monitor(name)) { error = "Invalid monitor name."; return false }
        if (monitor(name).disabled || monitors.filter(function(m) { return !m.disabled && (!m.mirrorOf || m.mirrorOf === "none") }).length <= 1) {
            error = "Keep at least one independent display enabled."; return false
        }
        return command(["--action", "disable", "--monitor", name])
    }
    function enableMonitor(name) { return applyMonitor(name, "preferred", 0, 0, 1, 0, "none") }
    function saveLayout() {
        var entries = []
        var extended = []
        for (var i = 0; i < monitors.length; i++) {
            var m = monitors[i]
            var pos = positions[m.name] || { x: Number(m.x || 0), y: Number(m.y || 0) }
            var mirror = m.mirrorOf && m.mirrorOf !== "none" ? String(m.mirrorOf) : ""
            if (!mirror && !m.disabled) extended.push(m.name)
            entries.push({ output: m.name, mode: m.width + "x" + m.height + "@" + Number(m.refreshRate || 60),
                           position: pos.x + "x" + pos.y, scale: Number(m.scale || 1), transform: Number(m.transform || 0), mirror: mirror, disabled: m.disabled === true })
        }
        if (!entries.length) { error = "No active monitors to save."; return false }
        var primary = selectedMonitor && extended.indexOf(selectedMonitor) >= 0 ? selectedMonitor : extended[0]
        if (primary && entries.length > 1) entries.sort(function(a, b) { return a.output === primary ? -1 : b.output === primary ? 1 : 0 })
        var workspaces = []
        if (theme.displayManagerAutoWorkspaces && extended.length) {
            if (primary) extended.splice(extended.indexOf(primary), 1), extended.unshift(primary)
            for (var ws = 1; ws <= 10; ws++) {
                var target = extended.length === 1 ? extended[0] : extended.length === 2 ? extended[(ws % 2 === 1) ? 0 : 1] : extended[(ws - 1) % extended.length]
                workspaces.push({ workspace: ws, monitor: target })
            }
        }
        return command(["--action", "save", "--payload", JSON.stringify({ monitors: entries, manageWorkspaces: theme.displayManagerAutoWorkspaces, workspaces: workspaces })])
    }
    function setBrightness(value) {
        var percent = Math.max(1, Math.min(100, Math.round(Number(value))))
        if (!brightnessAvailable || !safeMonitor(focusedMonitor)) { error = "Display brightness is unavailable."; return false }
        return command(["--action", "brightness", "--monitor", focusedMonitor, "--percent", String(percent)])
    }
    function setTextSize(index) {
        var n = Math.max(0, Math.min(textSizeStops.length - 1, Math.round(Number(index))))
        if (!command(["--action", "text-size", "--size", String(textSizeStops[n])])) return false
        pendingTextSizeIndex = n
        return true
    }
    function setPosition(name, x, y) {
        if (!safeMonitor(name) || !Number.isFinite(x) || !Number.isFinite(y)) return
        var copy = Object.assign({}, positions)
        copy[name] = { x: Math.round(x), y: Math.round(y) }
        positions = copy
    }
    function activeMonitorCount() { return monitors.length }

    Process {
        id: monitorProc
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: (code) => {
            if (controller.queryTimedOut) return
            if (code !== 0) { controller.error = String(stderr.text || "Could not query Hyprland monitors.").trim() }
            else {
                try {
                    var parsed = JSON.parse(String(stdout.text || ""))
                    if (!Array.isArray(parsed) || parsed.length > 32) throw new Error("Invalid monitor response")
                    for (var i = 0; i < parsed.length; i++) if (!controller.safeMonitor(parsed[i].name)) throw new Error("Invalid monitor name")
                    controller.monitors = parsed
                    if (!controller.selectedMonitor || !controller.monitor(controller.selectedMonitor)) controller.selectedMonitor = parsed.length ? parsed[0].name : ""
                    var positions = {}
                    for (var j = 0; j < parsed.length; j++) positions[parsed[j].name] = { x: Number(parsed[j].x || 0), y: Number(parsed[j].y || 0) }
                    controller.positions = positions
                } catch (e) { controller.error = "Invalid monitor data: " + String(e) }
            }
            if (!stateProc.running) {
                controller.loading = false
                if (controller.refreshPending) Qt.callLater(function() { controller.refresh(true) })
            }
        }
    }
    Process {
        id: stateProc
        stdout: StdioCollector { waitForEnd: true }
        onExited: (code) => {
            if (controller.queryTimedOut) return
            if (code !== 0) {
                controller.brightnessAvailable = false
                controller.displays = []
            } else {
                var lines = String(stdout.text || "").split("\n")
                var value = parseInt(String(lines[0] || "").trim(), 10)
                controller.brightnessAvailable = isFinite(value)
                controller.brightnessPercent = controller.brightnessAvailable ? Math.max(1, Math.min(100, value)) : 0
                controller.focusedMonitor = String(lines[5] || "").trim()
                try { controller.displays = JSON.parse(String(lines[7] || "[]").trim()) || [] } catch (e) { controller.displays = [] }
            }
            if (!monitorProc.running) {
                controller.loading = false
                if (controller.refreshPending) Qt.callLater(function() { controller.refresh(true) })
            }
        }
    }
    Process {
        id: actionProc
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: (code) => {
            if (controller.actionTimedOut) return
            controller.busy = false
            if (code !== 0) controller.error = String(stderr.text || "Display operation failed.").trim()
            else {
                controller.error = ""
                if (controller.guardedAction) {
                    try { controller.updateRollback(String(stdout.text)) }
                    catch (e) { controller.error = "Change was not confirmed; safety rollback remains armed. " + String(e) }
                }
                if (controller.pendingTextSizeIndex >= 0) controller.textSizeIndex = controller.pendingTextSizeIndex
            }
            controller.guardedAction = false
            controller.pendingTextSizeIndex = -1
            controller.refresh(true)
        }
    }
}
