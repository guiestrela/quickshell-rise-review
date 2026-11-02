// Shared behavior; owner is the active variant, environment supplies QML services.
.pragma library

function setWallpaperShuffleSettings(riseOwner, riseEnvironment, patch) {
    var riseState = riseOwner;

        var next = Object.assign({}, riseState.wallpaperManagerSettings)
        if (patch.intervalSec !== undefined) {
            var value = Number(patch.intervalSec)
            if (!isFinite(value) || Math.floor(value) !== value || value < 0 || value > 86400) return
            next.intervalSec = value
        }
        if (patch.shuffleOnWake === true || patch.shuffleOnWake === false) next.shuffleOnWake = patch.shuffleOnWake
        if (JSON.stringify(next) === JSON.stringify(riseState.wallpaperManagerSettings)) return
        riseState.wallpaperManagerSettings = next
        riseState.saveWallpaperProfile()
    }

function setWallpaperProfile(riseOwner, riseEnvironment, patch, outputName) {
    var riseState = riseOwner;

        var name = String(outputName || riseState.wallpaperManagerDisplay)
        riseState.wallpaperManagerSettings = riseEnvironment.WallpaperProfile.updateDisplay(riseState.wallpaperManagerSettings, name, patch,
            String(riseEnvironment.Quickshell.env("HOME") || ""))
        if (!riseState.wallpaperManagerSettings.perDisplayConfig && patch.folder !== undefined)
            riseState.wallpaperManagerFolder = riseState.wallpaperManagerSettings.displayConfig.all.folder
        riseState.saveWallpaperProfile()
        riseEnvironment.wallpaperManagerService.scanFolder(name)
    }

function setWallpaperPerDisplay(riseOwner, riseEnvironment, enabled) {
    var riseState = riseOwner;

        var next = Object.assign({}, riseState.wallpaperManagerSettings, { perDisplayConfig: enabled === true })
        riseState.wallpaperManagerSettings = next
        riseState.wallpaperManagerDisplay = enabled && riseState.wallpaperOutputs.length > 0 ? String(riseState.wallpaperOutputs[0].name) : "all"
        riseState.saveWallpaperProfile()
        riseEnvironment.wallpaperManagerService.scanFolder()
    }

function saveWallpaperProfile(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        riseEnvironment.wallpaperProfileDirectory.running = false
        riseEnvironment.wallpaperProfileDirectory.running = true
    }

function nextWallpaper(riseOwner, riseEnvironment, outputName) {
    var riseState = riseOwner;
 riseEnvironment.wallpaperManagerService.nextFor(String(outputName || riseState.wallpaperManagerDisplay)) }

function setWallpaperManagerFolder(riseOwner, riseEnvironment, path) {
    var riseState = riseOwner;

        var value = String(path || "").trim().replace(/\/+$/, "")
        if (value === ".." || value.indexOf("\n") >= 0 || value.indexOf("\r") >= 0) return
        riseState.wallpaperManagerFolder = value
        riseState.pendingWallpaperFolder = value
        riseState.wallpaperFolderWritePending = true
        if (!riseEnvironment.wallpaperFolderDirectoryProc.running) riseEnvironment.wallpaperFolderDirectoryProc.running = true
    }

function toggleWallpaperManager(riseOwner, riseEnvironment, screen, anchorItem) {
    var riseState = riseOwner;

        if (riseState.wallpaperManagerVisible) { riseState.wallpaperManagerVisible = false; return }
        if (screen && screen.name !== "") riseState.activatePopupScreen(screen)
        else riseState.activateFocusedPopupScreen()
        riseState.wallpaperManagerDisplay = riseState.wallpaperManagerSettings.perDisplayConfig && riseState.activePopupScreen
            ? String(riseState.activePopupScreen.name) : "all"
        var point = anchorItem ? anchorItem.mapToGlobal(anchorItem.width / 2, anchorItem.height) : null
        riseState.wallpaperManagerAnchorX = point ? point.x - riseState.activePopupScreen.x : riseState.activePopupScreen.width / 2
        riseState.wallpaperManagerAnchorY = point ? point.y - riseState.activePopupScreen.y : 32
        riseState.closePopups("wallpaperManagerVisible")
        riseState.wallpaperManagerVisible = true
    }
