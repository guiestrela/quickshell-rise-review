// Shared behavior; owner is the active variant, environment supplies QML services.
.pragma library

function wallpaperProfileFor(riseOwner, riseEnvironment, name) {
    var riseState = riseOwner;

        return riseEnvironment.WallpaperProfile.configFor(riseState.wallpaperManagerSettings, name, String(riseEnvironment.Quickshell.env("HOME") || ""))
    }

function setCurrentThemeName(riseOwner, riseEnvironment, rawName) {
    var riseState = riseOwner;

        var name = String(rawName || "").trim()
        if (name === "." || name === ".." || name.indexOf("/") >= 0 || name.indexOf("\\") >= 0)
            name = ""
        riseState.currentThemeName = name
    }

function reloadCurrentThemeFiles(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (!riseState.omarchyCurrentRootResolved) return
        riseEnvironment.themeReloadDebounce.restart()
    }

function barLayoutControllerScreenValid(riseOwner, riseEnvironment, screenName) {
    var riseState = riseOwner;

        if (!screenName) return false

        for (var i = 0; i < riseEnvironment.Quickshell.screens.length; i++) {
            var screen = riseEnvironment.Quickshell.screens[i]
            if (screen.name === screenName && screen.width > 0 && screen.height > 0) return true
        }
        return false
    }

function barLayoutControllerKeys(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var keys = []
        for (var screen in riseState.barLayoutControllers) {
            if (riseState.barLayoutControllerScreenValid(screen)) keys.push(screen)
        }
        keys.sort()
        return keys
    }

function refreshIdleStatus(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (!riseState._idleBackendChecked) return
        if (riseState._idleOmarchyShellSystem) {
            riseEnvironment.idleStateFile.reload()
            return
        }
        if (!riseEnvironment.idleProc.running) riseEnvironment.idleProc.running = true
    }

function refreshStatusIndicators(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        riseState.refreshIdleStatus()
        riseState.refreshNotificationStatus()
    }

function reprobeOmarchyShellBackends(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (riseEnvironment.idleBackendProc.running || riseEnvironment.notifBackendProc.running) {
            riseState._omarchyBackendReprobePending = true
            return
        }
        riseState._omarchyBackendReprobePending = false
        riseEnvironment.idleBackendProc.running = true
        riseEnvironment.notifBackendProc.running = true
    }

function finishOmarchyBackendReprobe(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (riseEnvironment.idleBackendProc.running || riseEnvironment.notifBackendProc.running) return
        if (riseState._omarchyBackendReprobePending) {
            riseEnvironment.omarchyBackendProbeDebounce.restart()
            return
        }
        riseState.scheduleOmarchyBackendRetry()
    }

function omarchyBackendRetryNeeded(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        return (riseState._idleOmarchyShellSystem && !riseState._idleOmarchyShellBackend)
            || (riseState._notifOmarchyShellSystem && !riseState._notifOmarchyShellBackend)
    }

function scheduleOmarchyBackendRetry(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (!riseState.omarchyBackendRetryNeeded()) {
            riseEnvironment.omarchyBackendRetryTimer.stop()
            riseState._omarchyBackendRetryIndex = 0
            return
        }
        if (riseEnvironment.omarchyBackendConfirmTimer.running || riseEnvironment.omarchyBackendRetryTimer.running
                || riseState._omarchyBackendRetryIndex >= riseState._omarchyBackendRetryDelays.length) return
        riseEnvironment.omarchyBackendRetryTimer.interval = riseState._omarchyBackendRetryDelays[riseState._omarchyBackendRetryIndex]
        riseState._omarchyBackendRetryIndex++
        riseEnvironment.omarchyBackendRetryTimer.restart()
    }

function resetOmarchyBackendProbes(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        riseEnvironment.omarchyBackendRetryTimer.stop()
        riseState._omarchyBackendRetryIndex = 0
        riseEnvironment.omarchyBackendProbeDebounce.restart()
        riseEnvironment.omarchyBackendConfirmTimer.restart()
    }

function parseNotificationsState(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;

        try {
            var parsed = JSON.parse(String(text || "{}"))
            if (!parsed || Array.isArray(parsed) || typeof parsed.dnd !== "boolean") return false
            riseState.notifSilenced = parsed.dnd
            return true
        } catch (e) {
            return false
        }
    }

function refreshNotificationStatus(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (!riseState._notifBackendChecked) return
        if (riseState._notifOmarchyShellSystem) {
            riseEnvironment.notificationsStateFile.reload()
            return
        }
        if (!riseEnvironment.dndProc.running) riseEnvironment.dndProc.running = true
    }

function refreshRecordingStatus(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (riseEnvironment.recordingPidProc.running) {
            riseState._recordingRefreshPending = true
            return
        }
        riseEnvironment.recordingPidProc.running = true
    }

function setScreenRecordingPid(riseOwner, riseEnvironment, pid) {
    var riseState = riseOwner;

        pid = String(pid || "").trim()
        if (pid === riseState._screenRecordingPid) return

        riseState._screenRecordingPid = pid
        if (pid === "") {
            riseState.screenRecording = false
            riseState.screenRecordingElapsed = 0
            riseState._screenRecordingBaseElapsed = 0
            riseState._screenRecordingBaseMs = 0
            riseState._screenRecordingElapsedProbePid = ""
            return
        }

        riseState.screenRecording = true
        riseState.screenRecordingElapsed = 0
        riseState._screenRecordingBaseElapsed = 0
        riseState._screenRecordingBaseMs = Date.now()
        riseState._screenRecordingElapsedProbePid = pid
        riseEnvironment.recordingElapsedProc.command = ["ps", "-o", "etimes=", "-p", pid]
        riseEnvironment.recordingElapsedProc.running = false
        riseEnvironment.recordingElapsedProc.running = true
    }

function updateScreenRecordingElapsed(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (!riseState.screenRecording || riseState._screenRecordingBaseMs <= 0) return
        riseState.screenRecordingElapsed = riseState._screenRecordingBaseElapsed + Math.floor((Date.now() - riseState._screenRecordingBaseMs) / 1000)
    }

function gotoWorkspace(riseOwner, riseEnvironment, id, monitorName) {
    var riseState = riseOwner;

        if (riseState.omarchyPerMonitorWorkspaces && monitorName) {
            var safeMonitorName = JSON.stringify(String(monitorName))
            riseEnvironment.Quickshell.execDetached([
                "hyprctl", "dispatch",
                "o.workspaces.focus(" + Number(id) + ", " + safeMonitorName + ")"
            ])
        } else if (riseState.hyprUsesLua)
            riseEnvironment.Quickshell.execDetached([
                "hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + Number(id) + " })"
            ])
        else
            riseEnvironment.Hyprland.dispatch("workspace " + id)
    }

function ipcApplyTheme(riseOwner, riseEnvironment, payload) {
    var riseState = riseOwner;

        let p;
        try { p = JSON.parse(payload); }
        catch (e) { console.warn("theme.apply: bad payload —", e); return; }
        if (!p || !p.colors) return;
        riseEnvironment.Palette.apply(riseOwner, riseEnvironment.Palette.mapKeys(p.colors));
        riseOwner.lastAppliedName = p.name || "";
    }

function ipcReloadTheme(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        riseEnvironment.paletteReader.running = false;
        riseEnvironment.paletteReader.running = true;
    }

function ipcOpenPicker(riseOwner, riseEnvironment, mode) {
    var riseState = riseOwner;

        if (mode === "theme" || mode === "wallpaper") riseState.openImagePicker(mode)
        else if (mode === "screenshots" || mode === "videos") riseState.openMediaBrowser(mode)
    }
