import QtQuick
import Quickshell
import Quickshell.Io

// One coordinator per active variant, shared by every output. Services stay
// owned by Omarchy; only reminder/sudo status require the native helper probes.
Item {
    id: service
    required property var root
    property var shell: null
    readonly property bool available: shell !== null
    readonly property var idle: lookup("omarchy.idle")
    readonly property var notifications: lookup("omarchy.notifications")
    readonly property var nightlight: lookup("omarchy.nightlight")
    readonly property var remoteSession: lookup("omarchy.remote-session")
    readonly property bool awake: idle ? idle.stayAwake : root.stayAwake
    readonly property bool silenced: notifications ? notifications.doNotDisturb : root.notifSilenced
    readonly property bool night: nightlight ? nightlight.enabled : false
    readonly property bool remote: remoteSession ? remoteSession.active : false
    readonly property bool recording: root.screenRecording
    property bool passwordless: false
    property int reminderCount: 0
    property string reminderTooltip: "Set a reminder"
    property bool refreshPending: false
    readonly property bool hasActive: awake || silenced || night || remote
        || recording || passwordless || reminderCount > 0

    function lookup(id) {
        return shell && typeof shell.firstPartyServiceFor === "function"
            ? shell.firstPartyServiceFor(id) : null
    }

    function acceptReminder(raw) {
        var data
        try { data = JSON.parse(raw) } catch (e) { return false }
        if (!data || Array.isArray(data) || typeof data.count !== "number"
                || !isFinite(data.count) || data.count < 0
                || Math.floor(data.count) !== data.count
                || typeof data.tooltip !== "string") return false
        reminderCount = data.count
        reminderTooltip = data.tooltip
        return true
    }

    function refresh() {
        root.refreshStatusIndicators()
        root.refreshRecordingStatus()
        if (!available) return
        if (sudoStatus.running || reminderStatus.running) {
            refreshPending = true
            return
        }
        refreshPending = false
        sudoStatus.running = true
        reminderStatus.running = true
        if (remoteSession) remoteSession.refresh()
    }

    function finishRefresh() {
        if (refreshPending && !sudoStatus.running && !reminderStatus.running)
            Qt.callLater(service.refresh)
    }

    function activate(id) {
        switch (id) {
        case "StayAwake":
            if (idle) idle.setIdleEnabled(awake)
            else runFallback(["omarchy-toggle-idle"])
            break
        case "Dnd":
            if (notifications) notifications.setDoNotDisturb(!silenced)
            else runFallback(["omarchy-toggle-notification-silencing"])
            break
        case "NightLight":
            if (nightlight) nightlight.setNightlight(!night)
            break
        case "Reminder":
            Quickshell.execDetached(reminderCount > 0
                ? ["omarchy-reminder", "show"] : ["omarchy-reminder", "-i"])
            break
        case "ScreenRecording":
            Quickshell.execDetached(recording
                ? ["omarchy-capture-screenrecording", "--stop-recording"]
                : ["omarchy-menu", "toggle", "trigger.capture.screenrecord"])
            break
        case "PasswordlessSudo":
            if (passwordless) {
                if (!sudoDisable.running) sudoDisable.running = true
            } else {
                Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-sudo-passwordless"])
            }
            break
        }
    }

    function runFallback(command) {
        if (fallbackAction.running) return
        fallbackAction.command = command
        fallbackAction.running = true
    }

    // omarchy-shell falls back to qs ipc for handlers outside ShellIpc's fast
    // registry. One target here fans out through shared state to all outputs.
    IpcHandler {
        target: "omarchy.indicators"
        enabled: service.available
        function refresh(): void { service.refresh() }
    }
    Process {
        id: sudoStatus
        objectName: "sudoStatus"
        command: ["omarchy-sudo-passwordless", "--active"]
        onExited: (exitCode, exitStatus) => {
            service.passwordless = exitCode === 0 && exitStatus === 0
            Qt.callLater(service.finishRefresh)
        }
    }
    Process {
        id: reminderStatus
        objectName: "reminderStatus"
        command: ["omarchy-reminder", "show", "--json"]
        stdout: StdioCollector { id: reminderOutput; waitForEnd: true }
        onExited: (exitCode) => {
            if (exitCode === 0) service.acceptReminder(reminderOutput.text)
            Qt.callLater(service.finishRefresh)
        }
    }
    Process {
        id: sudoDisable
        objectName: "sudoDisable"
        command: ["omarchy-sudo-passwordless", "--disable"]
        onExited: (exitCode) => {
            if (exitCode !== 0)
                Quickshell.execDetached(["omarchy-notification-send", "Passwordless sudo", "Could not disable passwordless sudo"])
            service.refresh()
        }
    }
    Process {
        id: fallbackAction
        command: []
        onExited: service.refresh()
    }
    onAvailableChanged: if (available) Qt.callLater(refresh)
}
