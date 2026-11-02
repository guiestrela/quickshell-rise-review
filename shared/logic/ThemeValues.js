// Common behavior for variant-specific presentations.
.pragma library

function shuffleWallpapers(riseOwner, riseEnvironment) {
    var riseState = riseOwner;
 riseEnvironment.wallpaperManagerService.shuffleAll(false) }

function pinWallpaper(riseOwner, riseEnvironment, path) {
    var riseState = riseOwner;
 riseEnvironment.wallpaperManagerService.pinAll(path) }

function evenW(riseOwner, riseEnvironment, w) {
    var riseState = riseOwner;
 return 2 * Math.round(w / 2) }

function openImagePicker(riseOwner, riseEnvironment, mode, screen) {
    var riseState = riseOwner;

        if (riseState.imagePickerVisible && riseState.imagePickerMode !== mode)
            riseState.imagePickerVisible = false
        if (screen && screen.name !== "") riseState.activatePopupScreen(screen)
        else riseState.activateFocusedPopupScreen()
        riseState.mediaBrowserVisible = false
        riseState.imagePickerMode = mode
        riseState.imagePickerVisible = true
    }

function toggleImagePicker(riseOwner, riseEnvironment, mode, screen) {
    var riseState = riseOwner;

        if (riseState.imagePickerVisible && riseState.imagePickerMode === mode) {
            riseState.imagePickerVisible = false
            return
        }

        riseState.openImagePicker(mode, screen)
    }

function openMediaBrowser(riseOwner, riseEnvironment, mode) {
    var riseState = riseOwner;

        riseState.activateFocusedPopupScreen()
        riseState.imagePickerVisible = false
        riseState.mediaBrowserMode = mode
        riseState.mediaBrowserVisible = true
    }

function aiPct(riseOwner, riseEnvironment, v) {
    var riseState = riseOwner;
 return Math.max(0, Math.min(100, Math.round((parseFloat(v) || 0) * 100))) }

function aiResetCodexUsage(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        riseState.aiCxHas = false; riseState.aiCxFresh = false
        riseState.aiCxPct5h = 0; riseState.aiCxPct7d = 0
        riseState.aiCxPlan = ""; riseState.aiCxTokens = ""; riseState.aiCxRate = ""; riseState.aiCxToday = 0
        riseState.aiCxReset5hTs = 0; riseState.aiCxReset7dTs = 0
        riseState.aiCxBuckets = []; riseState.aiCxWindows = []
        riseState.aiCxPrimaryPct = 0; riseState.aiCxPrimaryLabel = ""; riseState.aiCxPrimaryResetTs = 0
        riseState.aiCxQuotaPct = 0; riseState.aiCxQuotaLabel = ""
        riseState.aiCxLimitStatus = ""; riseState.aiCxLimitReachedType = ""
    }

function aiPad2(riseOwner, riseEnvironment, n) {
    var riseState = riseOwner;
 return n < 10 ? "0" + n : "" + n }

function aiResetCopilotUsage(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        riseState.aiCpHas = false; riseState.aiCpFresh = false
        riseState.aiCpPct = 0; riseState.aiCpLabel = ""
        riseState.aiCpResetTs = 0; riseState.aiCpPlan = ""; riseState.aiCpSku = ""
        riseState.aiCpUnlimited = false
        riseState.aiCpCreditsUsed = 0; riseState.aiCpCreditsEntitlement = 0
        riseState.aiCpLimitReachedType = ""; riseState.aiCpStatus = ""
    }

function refreshAiUsage(riseOwner, riseEnvironment, selectedOnly) {
    var riseState = riseOwner;

        riseState.aiClockTick++
        var only = selectedOnly === true
        if (!only || riseState.aiTool === "claude") {
            riseEnvironment.aiReadClaude.running = false; riseEnvironment.aiReadClaude.running = true
        }
        if (!only || riseState.aiTool === "codex") {
            riseEnvironment.aiReadCodex.running = false;  riseEnvironment.aiReadCodex.running = true
        }
        if (!only || riseState.aiTool === "opencode") {
            riseEnvironment.aiReadOpenCode.running = false; riseEnvironment.aiReadOpenCode.running = true
        }
        if (!only || riseState.aiTool === "copilot") {
            riseEnvironment.aiReadCopilot.running = false; riseEnvironment.aiReadCopilot.running = true
        }
    }

function barTemperatureSourceValid(riseOwner, riseEnvironment, source) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.barTemperatureSourceValid(source) }

function barTemperatureSourceLabel(riseOwner, riseEnvironment, source) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.barTemperatureSourceLabel(source) }

function barTemperatureSourceAvailable(riseOwner, riseEnvironment, source) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.barTemperatureSourceAvailable(source) }

function parseSystemCpu(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.parseSystemCpu(text) }

function parseCpuInfo(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.parseCpuInfo(text) }

function parseSystemLoad(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.parseSystemLoad(text) }

function parseCpuDetail(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.parseCpuDetail(text) }

function parseCpuTopProcesses(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.parseCpuTopProcesses(text) }

function parseSystemMem(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.parseSystemMem(text) }

function parseMemoryHardware(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.parseMemoryHardware(text) }

function parseGpuTelemetry(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.parseGpuTelemetry(text) }

function parseThermalTelemetry(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.parseThermalTelemetry(text) }

function parseStorageInventory(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.parseStorageInventory(text) }

function parseStorageTelemetry(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;
 return riseEnvironment.systemTelemetry.parseStorageTelemetry(text) }

function refreshNordVpnStatus(riseOwner, riseEnvironment) {
    var riseState = riseOwner;
 riseEnvironment.nordVpnController.refresh() }

function reconcileSlowStatusIndicators(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        riseState.refreshRecordingStatus()
    }

function launcherLogoIconFont(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        return id === "omarchy" ? "omarchy" : riseState.mono
    }

function archGateRescan(riseOwner, riseEnvironment) {
    var riseState = riseOwner;
 riseEnvironment.archGate.rerun() }

function closeArchUpdatesPanel(riseOwner, riseEnvironment) {
    var riseState = riseOwner;
 riseState.archVisible = false }

function openTrayMenu(riseOwner, riseEnvironment, handle, x, title, icon) {
    var riseState = riseOwner;

        if (!handle) return
        riseState.trayMenuHandle = handle
        riseState.trayMenuTitle = String(title || "App Menu")
        riseState.trayMenuIcon = String(icon || "")
        riseState.setPanelAnchor("trayMenu", x)
        riseState.trayMenuVisible = true
    }

function trayIsHidden(riseOwner, riseEnvironment, item) {
    var riseState = riseOwner;

        return riseState.trayPinned.indexOf(item.id) < 0
    }
