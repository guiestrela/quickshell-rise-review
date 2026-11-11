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
            drafts = ({})
        } else if (["confirmed", "reverted", "failed"].indexOf(data.status) >= 0) {
            rollbackToken = ""
            rollbackSeconds = 0
            if (data.status !== "confirmed") extraQueue = []
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
        stdout: StdioCollector { id: rollbackStatusOutput; waitForEnd: true }
        stderr: StdioCollector { id: rollbackStatusErrorOutput; waitForEnd: true }
        onExited: (code) => {
            if (!controller.rollbackPending || controller.confirmationBusy) return
            if (code !== 0) { controller.error = String(rollbackStatusErrorOutput.text || "Could not verify rollback state.").trim(); return }
            try { controller.updateRollback(String(rollbackStatusOutput.text)) }
            catch (e) { controller.error = String(e) }
        }
    }
    Process {
        id: confirmationProc
        stdout: StdioCollector { id: confirmationOutput; waitForEnd: true }
        stderr: StdioCollector { id: confirmationErrorOutput; waitForEnd: true }
        onExited: (code) => {
            controller.confirmationBusy = false
            if (code !== 0) { controller.error = String(confirmationErrorOutput.text || "Confirmation failed; automatic rollback remains armed.").trim(); return }
            try { controller.updateRollback(String(confirmationOutput.text)) }
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
            controller.extraQueue = []
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
    property var drafts: ({})
    property var workspaceAssignments: ({})
    property var workspaceOverrides: ({})
    property var draftWorkspaceAssignments: ({})
    property bool workspaceLoading: false
    property bool workspaceStateReady: false
    property string workspaceError: ""
    property bool workspaceCommitPending: false
    property int workspaceGeneration: 0
    property int workspaceQueryGeneration: -1
    property bool workspaceRefreshPending: false
    function workspaceOwner(number) {
        var key = String(number)
        return draftWorkspaceAssignments[key] !== undefined ? draftWorkspaceAssignments[key] : workspaceAssignments[key] || ""
    }
    function stageWorkspace(number, name) {
        var m = previewMonitor(name)
        if (busy || loading || rollbackPending || workspaceLoading || extraQueue.length || workspaceCommitPending || !workspaceStateReady
            || !Number.isInteger(number) || number < 1 || number > 10 || !safeMonitor(name)
            || !m || m.disabled || (m.mirrorOf && m.mirrorOf !== "none")) return false
        var copy = Object.assign({}, draftWorkspaceAssignments)
        if (copy[String(number)] === name) delete copy[String(number)]
        else copy[String(number)] = name
        draftWorkspaceAssignments = copy; return true
    }
    function refreshWorkspaces() {
        if (workspaceStateProc.running) { workspaceRefreshPending = true; return }
        workspaceQueryGeneration = workspaceGeneration
        workspaceRefreshPending = false
        workspaceLoading = true; workspaceError = ""
        workspaceStateProc.command = [helperPath, "--action", "workspace-state"]
        workspaceStateProc.running = true
    }
    Timer {
        interval: 15000; running: controller.workspaceLoading
        onTriggered: {
            workspaceStateProc.running = false; controller.workspaceLoading = false
            controller.workspaceRefreshPending = false
            controller.workspaceStateReady = false; controller.workspaceError = "Workspace query timed out."
        }
    }
    Process {
        id: workspaceStateProc
        stdout: StdioCollector { id: workspaceStateOutput; waitForEnd: true }
        stderr: StdioCollector { id: workspaceStateErrorOutput; waitForEnd: true }
        onExited: (code) => {
            if (!controller.workspaceLoading) return
            controller.workspaceLoading = false
            if (controller.workspaceQueryGeneration !== controller.workspaceGeneration || controller.workspaceRefreshPending) {
                Qt.callLater(function() { controller.refreshWorkspaces() }); return
            }
            if (code !== 0) { controller.workspaceStateReady = false; controller.workspaceError = "Could not read workspace assignments."; return }
            try {
                var state = JSON.parse(String(workspaceStateOutput.text))
                for (var values of [state.bindings, state.overrides]) {
                    if (!values || typeof values !== "object" || Array.isArray(values) || Object.keys(values).length > 10) throw new Error("Invalid workspace state")
                    for (var key of Object.keys(values)) if (!/^(10|[1-9])$/.test(key) || !controller.safeMonitor(values[key])) throw new Error("Invalid workspace assignment")
                }
                controller.workspaceAssignments = state.bindings
                controller.workspaceOverrides = state.overrides
                controller.workspaceStateReady = true
                if (controller.workspaceCommitPending) {
                    controller.draftWorkspaceAssignments = ({})
                    controller.workspaceCommitPending = false
                }
            } catch (e) { controller.workspaceStateReady = false; controller.workspaceError = String(e) }
        }
    }
    property var draftBrightness: ({})
    property int draftTextSizeIndex: -1
    property var extraQueue: []
    readonly property var previewMonitors: monitors.map(function(m) { return controller.previewMonitor(m.name) })
    readonly property var previewPositions: {
        var result = {}
        for (var m of previewMonitors) result[m.name] = { x: m.x, y: m.y }
        return result
    }
    readonly property bool hasDrafts: Object.keys(drafts).length > 0 || Object.keys(draftWorkspaceAssignments).length > 0 || Object.keys(draftBrightness).length > 0 || draftTextSizeIndex >= 0
    function previewMonitor(name) {
        var m = monitor(name)
        return m ? Object.assign({}, m, drafts[name] || {}) : null
    }
    function stageMonitor(name, patch) {
        if (busy || loading || rollbackPending || !safeMonitor(name) || !monitor(name)) return false
        if (!patch || typeof patch !== "object" || Array.isArray(patch)) return false
        var next = Object.assign({}, previewMonitor(name), patch)
        if (patch.mode !== undefined) {
            var mode = String(patch.mode).replace(/Hz$/, "")
            if (!/^(preferred|[1-9][0-9]{1,4}x[1-9][0-9]{1,4}(@[1-9][0-9]{0,2}(\.[0-9]{1,3})?)?)$/.test(mode)) return false
            next.mode = mode
            if (mode !== "preferred") {
                var parts = mode.split("@"), size = parts[0].split("x")
                next.width = Number(size[0]); next.height = Number(size[1])
                if (parts.length > 1) next.refreshRate = Number(parts[1])
            }
        }
        if (!next.disabled && !validSavedDisplayState(next)) { error = "Invalid display draft."; return false }
        if (next.mirrorOf && next.mirrorOf !== "none" && (!safeMonitor(next.mirrorOf) || next.mirrorOf === name || !monitor(next.mirrorOf))) return false
        var copy = Object.assign({}, drafts); copy[name] = next; drafts = copy
        error = ""; return true
    }
    function stageDisable(name) {
        var m = previewMonitor(name)
        if (!m || m.disabled || previewMonitors.filter(function(p) { return !p.disabled && (!p.mirrorOf || p.mirrorOf === "none") }).length <= 1) {
            error = "Keep at least one independent display enabled."; return false
        }
        return stageMonitor(name, { disabled: true })
    }
    function stageBrightness(name, value) {
        if (busy || loading || rollbackPending || !safeMonitor(name) || !monitor(name)) return false
        var percent = Math.round(Number(value))
        if (!isFinite(percent) || percent < 1 || percent > 100) return false
        var copy = Object.assign({}, draftBrightness); copy[name] = percent; draftBrightness = copy; return true
    }
    function stageTextSize(index) {
        if (busy || loading || rollbackPending || !Number.isInteger(index) || index < 0 || index >= textSizeStops.length) return false
        draftTextSizeIndex = index; return true
    }
    function applyDrafts() {
        if (busy || loading || rollbackPending || workspaceLoading || workspaceCommitPending || extraQueue.length) return false
        var changed = Object.keys(drafts), entries = [], saved = Object.assign({}, savedDisplayStates), remember = false
        for (var name of changed) if (!monitor(name)) { error = "Displays changed; refresh first."; return false }
        for (var m of previewMonitors) {
            entries.push({ output: m.name, mode: m.mode || (m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(3)),
                position: m.x + "x" + m.y, scale: Number(m.scale), transform: Number(m.transform),
                disabled: Boolean(m.disabled), mirror: m.mirrorOf && m.mirrorOf !== "none" ? m.mirrorOf : "" })
            var live = monitor(m.name)
            if (drafts[m.name] && m.disabled && !live.disabled) {
                var snapshot = { x: live.x, y: live.y, width: live.width, height: live.height,
                    scale: live.scale, transform: live.transform, refreshRate: live.refreshRate }
                if (!displayStateReady || !validSavedDisplayState(snapshot)) { error = "Cannot save the display return position."; return false }
                saved[m.name] = snapshot; remember = true
            }
        }
        if (remember) {
            displayStateSaved = false
            try { displayStateFile.setText(JSON.stringify(saved)) } catch (e) { error = String(e); return false }
            if (!displayStateSaved) { error = "Cannot save display return positions; nothing applied."; return false }
            savedDisplayStates = saved
        }
        var queue = []
        var workspaceDrafts = typeof draftWorkspaceAssignments === "undefined" ? {} : draftWorkspaceAssignments
        var assigned = []
        for (var key of Object.keys(workspaceDrafts).sort(function(a, b) { return Number(a) - Number(b) })) {
            var target = previewMonitor(workspaceDrafts[key])
            if (!target || target.disabled || (target.mirrorOf && target.mirrorOf !== "none")) { error = "Assign workspaces to an active independent monitor."; return false }
            assigned.push({ workspace: Number(key), monitor: workspaceDrafts[key] })
        }
        if (assigned.length) queue.push(["--action", "workspaces", "--payload", JSON.stringify(assigned)])
        for (var output of Object.keys(draftBrightness)) queue.push(["--action", "brightness", "--monitor", output, "--percent", String(draftBrightness[output])])
        if (draftTextSizeIndex >= 0) queue.push(["--action", "text-size", "--size", String(textSizeStops[draftTextSizeIndex])])
        if (changed.length && !command(["--action", "preview", "--payload", JSON.stringify({ monitors: entries, changed: changed })])) return false
        extraQueue = queue; draftBrightness = ({}); draftTextSizeIndex = -1

        if (!changed.length) queueNextSetting()
        return true
    }
    function queueNextSetting() {
        if (busy || loading || rollbackPending || !extraQueue.length) return
        var args = extraQueue[0]
        if (!command(args)) return
        extraQueue = extraQueue.slice(1)
        if (args[1] === "text-size") pendingTextSizeIndex = textSizeStops.indexOf(Number(args[3]))
    }
    Timer {
        interval: 50; repeat: true
        running: controller.extraQueue.length > 0 && !controller.rollbackPending && !controller.busy && !controller.loading
        onTriggered: controller.queueNextSetting()
    }
    property var savedDisplayStates: ({})
    property bool displayStateReady: false
    property bool displayStateSaved: false
    FileView {
        id: displayStateFile
        path: Quickshell.env("HOME") + "/.cache/quickshell-rise/display-return-states.json"
        preload: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                var data = JSON.parse(text())
                if (!data || typeof data !== "object" || Array.isArray(data) || Object.keys(data).length > 32)
                    throw new Error("Invalid saved display state")
                var valid = {}
                for (var name of Object.keys(data)) {
                    if (!controller.safeMonitor(name) || !controller.validSavedDisplayState(data[name]))
                        throw new Error("Invalid saved display geometry")
                    valid[name] = data[name]
                }
                controller.savedDisplayStates = valid
                controller.displayStateReady = true
            } catch (e) { controller.displayStateReady = false; controller.error = String(e) }
        }
        onLoadFailed: (code) => {
            controller.displayStateReady = code === FileViewError.FileNotFound
            if (!controller.displayStateReady) controller.error = "Cannot read the saved display positions."
        }
        onSaved: controller.displayStateSaved = true
        onSaveFailed: controller.displayStateSaved = false
    }
    function validSavedDisplayState(m) {
        return m && Number.isInteger(m.x) && Math.abs(m.x) <= 32767
            && Number.isInteger(m.y) && Math.abs(m.y) <= 32767
            && Number.isInteger(m.width) && m.width >= 10 && m.width <= 99999
            && Number.isInteger(m.height) && m.height >= 10 && m.height <= 99999
            && Number.isFinite(m.scale) && m.scale >= 0.1 && m.scale <= 4
            && Number.isInteger(m.transform) && m.transform >= 0 && m.transform <= 7
            && Number.isFinite(m.refreshRate) && m.refreshRate >= 1 && m.refreshRate < 1000
    }
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
    }
    onSelectedMonitorChanged: {
        brightnessAvailable = false
        if (!loading && !busy) refreshBrightness()
    }
    function refreshBrightness() {
        if (!safeMonitor(selectedMonitor) || !monitor(selectedMonitor)) { brightnessAvailable = false; return }
        if (stateProc.running) { refreshPending = true; return }
        brightnessAvailable = false
        queryTimedOut = false
        loading = true
        stateProc.command = [helperPath, "--action", "brightness-state", "--monitor", selectedMonitor]
        stateProc.running = true
    }
    function command(args) {
        if (rollbackPending) { error = "Keep or revert the pending configuration first."; return false }
        if (busy || loading) { error = "Another display operation or query is still running."; return false }
        actionTimedOut = false
        pendingTextSizeIndex = -1
        busy = true
        error = ""
        guardedAction = args[1] === "monitor" || args[1] === "disable" || args[1] === "preview"
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
        if (busy || loading || rollbackPending || !displayStateReady) {
            error = "Wait for the current operation and saved display positions."; return false
        }
        // Capture the actual applied geometry, never an un-applied drag position.
        var m = monitor(name)
        var snapshot = { x: m.x, y: m.y, width: m.width, height: m.height,
                         scale: m.scale, transform: m.transform, refreshRate: m.refreshRate }
        if (!validSavedDisplayState(snapshot)) { error = "Cannot save this display geometry safely."; return false }
        var saved = Object.assign({}, savedDisplayStates)
        saved[name] = snapshot
        displayStateSaved = false
        try { displayStateFile.setText(JSON.stringify(saved)) }
        catch (e) { error = "Cannot save the display position: " + String(e); return false }
        if (!displayStateSaved) { error = "Cannot save the display position; output was not disabled."; return false }
        savedDisplayStates = saved
        return command(["--action", "disable", "--monitor", name])
    }
    property var mirrorReturnStates: ({})
    function toggleMirror(draftOnly) {
        var m = draftOnly ? previewMonitor(selectedMonitor) : monitor(selectedMonitor)
        if (!m || busy || loading || rollbackPending) return false
        var mirrored = Boolean(m.mirrorOf && m.mirrorOf !== "none")
        var target = null
        for (var i = 0; i < monitors.length; i++) {
            var other = draftOnly ? previewMonitor(monitors[i].name) : monitors[i]
            if (other.name !== m.name && !other.disabled && (!other.mirrorOf || other.mirrorOf === "none")) {
                if (!target || other.name === m.mirrorOf) target = other
            }
        }
        if (!mirrored) {
            if (!target || m.disabled) { error = "No independent display available to mirror."; return false }
            var next = Object.assign({}, mirrorReturnStates)
            next[m.name] = Object.assign({}, m)
            mirrorReturnStates = next
            if (draftOnly) return stageMonitor(m.name, { mode: "preferred", mirrorOf: target.name })
            return applyMonitor(m.name, "preferred", Number(m.x || 0), Number(m.y || 0), Number(m.scale || 1), Number(m.transform || 0), target.name)
        }
        var original = mirrorReturnStates[m.name]
        if (!original) {
            // External mirroring has no local return snapshot: keep current mode,
            // and place the output left of every independent display, never on top.
            var left = Infinity
            for (var j = 0; j < monitors.length; j++) {
                var peer = monitors[j]
                if (peer.name !== m.name && !peer.disabled && (!peer.mirrorOf || peer.mirrorOf === "none")) left = Math.min(left, Number(peer.x || 0))
            }
            if (!target || !isFinite(left)) { error = "No safe extended layout available."; return false }
            var w = Number(Number(m.transform || 0) % 2 ? m.height : m.width) / Number(m.scale || 1)
            if (!isFinite(w) || w <= 0) { error = "Invalid display dimensions."; return false }
            original = Object.assign({}, m, {x: Math.floor(left - w), y: Number(target.y || 0)})
        }
        var mode = original.width + "x" + original.height + "@" + Number(original.refreshRate).toFixed(3)
        if (draftOnly) return stageMonitor(m.name, { mode: mode, x: Number(original.x || 0), y: Number(original.y || 0),
            scale: Number(original.scale || 1), transform: Number(original.transform || 0), mirrorOf: "none" })
        return applyMonitor(m.name, mode, Number(original.x || 0), Number(original.y || 0), Number(original.scale || 1), Number(original.transform || 0), "none")
    }
    function enableMonitor(name, draftOnly) {
        var m = monitor(name)
        if (!m) { error = "Output is no longer connected; refresh first."; return false }
        if (!displayStateReady) { error = "Wait for the saved display positions to load."; return false }
        var saved = m.disabled ? savedDisplayStates[name] : null
        if (saved) {
            if (!validSavedDisplayState(saved)) { error = "Invalid saved display geometry."; return false }
            m = saved
        }
        function bounds(output, x, y) {
            var scale = Number(output.scale), transform = Number(output.transform)
            var width = Number(output.width), height = Number(output.height)
            if (!Number.isInteger(width) || width <= 0 || !Number.isInteger(height) || height <= 0
                || !isFinite(scale) || scale < 0.1 || scale > 4
                || !Number.isInteger(transform) || transform < 0 || transform > 7
                || !isFinite(x) || !isFinite(y)) return null
            return { x:x, y:y, w:(transform % 2 ? height : width) / scale,
                     h:(transform % 2 ? width : height) / scale }
        }
        var position = saved || positions[name] || m
        var x = Number(position.x), y = Number(position.y)
        var candidate = bounds(m, x, y)
        if (!candidate) { error = "Invalid display geometry; no command was sent."; return false }
        var overlap = false, right = -Infinity
        var peers = draftOnly ? previewMonitors : monitors
        for (var i = 0; i < peers.length; i++) {
            var peer = peers[i]
            if (peer.name === name || peer.disabled || (peer.mirrorOf && peer.mirrorOf !== "none")) continue
            var rect = bounds(peer, Number(peer.x), Number(peer.y))
            if (!rect) { error = "Invalid active display geometry; refresh first."; return false }
            right = Math.max(right, rect.x + rect.w)
            if (candidate.x < rect.x + rect.w && candidate.x + candidate.w > rect.x
                && candidate.y < rect.y + rect.h && candidate.y + candidate.h > rect.y) overlap = true
        }
        // Keep a valid previous position; otherwise place beside active outputs.
        if (overlap && saved) { error = "Saved display position overlaps another monitor; free that position first."; return false }
        if (overlap) x = Math.ceil(right)
        var refreshRate = Number(m.refreshRate)
        if (!isFinite(refreshRate) || refreshRate <= 0) {
            error = "Cannot restore the display mode safely; refresh first."; return false
        }
        var mode = m.width + "x" + m.height + "@" + refreshRate.toFixed(3)
        if (draftOnly) return stageMonitor(name, { mode: mode, x: x, y: y, scale: Number(m.scale),
            transform: Number(m.transform), disabled: false, mirrorOf: "none" })
        return applyMonitor(name, mode, x, y, Number(m.scale), Number(m.transform), "none")
    }
    function saveLayout() {
        if (hasDrafts || extraQueue.length || workspaceLoading || workspaceCommitPending) { error = "Apply pending changes before saving the layout."; return false }
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
            if (primary) {
                extended.splice(extended.indexOf(primary), 1)
                extended.unshift(primary)
            }
            for (var ws = 1; ws <= 10; ws++) {
                var target = extended.length === 1 ? extended[0] : extended.length === 2 ? extended[(ws % 2 === 1) ? 0 : 1] : extended[(ws - 1) % extended.length]
                workspaces.push({ workspace: ws, monitor: target })
            }
        }
        for (var key of Object.keys(workspaceOverrides)) {
            var target = workspaceOverrides[key]
            if (extended.indexOf(target) < 0) continue
            workspaces = workspaces.filter(function(entry) { return entry.workspace !== Number(key) })
            workspaces.push({ workspace: Number(key), monitor: target })
        }
        workspaces.sort(function(a, b) { return a.workspace - b.workspace })
        return command(["--action", "save", "--payload", JSON.stringify({ monitors: entries, manageWorkspaces: theme.displayManagerAutoWorkspaces || workspaces.length > 0, workspaces: workspaces })])
    }
    function setBrightness(value) {
        var percent = Math.max(1, Math.min(100, Math.round(Number(value))))
        if (!brightnessAvailable || !safeMonitor(selectedMonitor)) { error = "Display brightness is unavailable."; return false }
        return command(["--action", "brightness", "--monitor", selectedMonitor, "--percent", String(percent)])
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
        stdout: StdioCollector { id: monitorOutput; waitForEnd: true }
        stderr: StdioCollector { id: monitorErrorOutput; waitForEnd: true }
        onExited: (code) => {
            if (controller.queryTimedOut) return
            if (code !== 0) { controller.error = String(monitorErrorOutput.text || "Could not query Hyprland monitors.").trim() }
            else {
                try {
                    var parsed = JSON.parse(String(monitorOutput.text || ""))
                    if (!Array.isArray(parsed) || parsed.length > 32) throw new Error("Invalid monitor response")
                    for (var i = 0; i < parsed.length; i++) if (!controller.safeMonitor(parsed[i].name)) throw new Error("Invalid monitor name")
                    controller.monitors = parsed
                    controller.displays = parsed.map(function(m) { return {name:m.name,enabled:!m.disabled,focused:Boolean(m.focused),width:m.width,height:m.height} })
                    controller.focusedMonitor = (parsed.filter(function(m) { return m.focused })[0] || {}).name || ""
                    if (!controller.selectedMonitor || !controller.monitor(controller.selectedMonitor)) controller.selectedMonitor = parsed.length ? parsed[0].name : ""
                    var positions = {}
                    for (var j = 0; j < parsed.length; j++) {
                        var remembered = parsed[j].disabled ? controller.savedDisplayStates[parsed[j].name] : null
                        var origin = remembered || parsed[j]
                        positions[parsed[j].name] = { x: Number(origin.x || 0), y: Number(origin.y || 0) }
                    }
                    controller.positions = positions
                    controller.refreshBrightness()
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
        stdout: StdioCollector { id: brightnessOutput; waitForEnd: true }
        onExited: (code) => {
            if (controller.queryTimedOut) return
            if (code !== 0) {
                controller.brightnessAvailable = false
                controller.displays = []
            } else {
                try {
                    var data = JSON.parse(String(brightnessOutput.text || ""))
                    if (data.monitor !== controller.selectedMonitor) {
                        controller.brightnessAvailable = false
                        controller.refreshPending = true
                    } else if (Number.isInteger(data.percent) && data.percent >= 0 && data.percent <= 100) {
                        controller.brightnessPercent = data.percent
                        controller.brightnessAvailable = true
                    } else throw new Error("Invalid brightness data")
                } catch (e) { controller.brightnessAvailable = false; controller.error = String(e) }
            }
            if (!monitorProc.running) {
                controller.loading = false
                if (controller.refreshPending) Qt.callLater(function() { controller.refresh(true) })
            }
        }
    }
    Process {
        id: actionProc
        stdout: StdioCollector { id: actionOutput; waitForEnd: true }
        stderr: StdioCollector { id: actionErrorOutput; waitForEnd: true }
        onExited: (code) => {
            if (controller.actionTimedOut) return
            controller.busy = false
            if (code !== 0) { controller.extraQueue = []; controller.error = String(actionErrorOutput.text || "Display operation failed.").trim() }
            else {
                controller.error = ""
                if (controller.guardedAction) {
                    try { controller.updateRollback(String(actionOutput.text)) }
                    catch (e) { controller.extraQueue = []; controller.error = "Change was not confirmed; safety rollback remains armed. " + String(e) }
                }
                if (controller.pendingTextSizeIndex >= 0) controller.textSizeIndex = controller.pendingTextSizeIndex
                if (!controller.guardedAction && (actionProc.command[2] === "workspaces" || actionProc.command[2] === "save")) {
                    controller.workspaceGeneration++
                    if (actionProc.command[2] === "workspaces") controller.workspaceCommitPending = true
                    controller.refreshWorkspaces()
                }
            }
            controller.guardedAction = false
            controller.pendingTextSizeIndex = -1
            controller.refresh(true)
        }
    }
}
