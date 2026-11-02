// Common behavior for variant-specific presentations.
.pragma library

function dismiss(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (!riseEnvironment.wallpaperDialog.busy) riseOwner.root.wallpaperManagerVisible = false
    }

function currentWallpaperMatches(riseOwner, riseEnvironment, path, display) {
    var riseState = riseOwner;

        var service = riseOwner.root.wallpaperManagerServiceApi
        if (!service || service.scanInFlight || (service.scanJobs && service.scanJobs.length > 0)) return false
        if (display !== "all") return String(service.pathFor(display) || "") === path
        var screens = service.liveScreens || []
        return screens.length > 0 && screens.every(function(screen) {
            return String(service.pathFor(String(screen.name)) || "") === path
        })
    }

function selectedWallpaperCanApply(riseOwner, riseEnvironment) {
    var service = riseOwner.root.wallpaperManagerServiceApi
    var path = riseOwner.selectedWallpaperFile
    if (path === "" || !riseOwner.isMediaFileInFolder(path, riseOwner.profile.folder)
            || !service || service.scanInFlight)
        return false
    var display = String(riseOwner.root.wallpaperManagerDisplay || "all")
    var paths = display === "all" ? service.pool : service.poolFor(display)
    return paths && paths.indexOf(path) >= 0
}

function selectedWallpaperStatus(riseOwner, riseEnvironment) {
    if (riseOwner.selectedWallpaperError !== "") return riseOwner.selectedWallpaperError
    if (riseOwner.profile.folder === "") return "Choose a folder first."
    var service = riseOwner.root.wallpaperManagerServiceApi
    if (riseOwner.selectedWallpaperFile === "")
        return service.scanInFlight ? "Scanning the selected folder…" : "No file selected."
    var name = riseOwner.selectedWallpaperFile.substring(riseOwner.selectedWallpaperFile.lastIndexOf("/") + 1)
    if (riseOwner.selectedWallpaperApplying) return "Applying: " + name
    if (service.scanInFlight) return "Scanning: " + name
    if (!selectedWallpaperCanApply(riseOwner, riseEnvironment)) return "File unavailable for this display."
    return (riseOwner.selectedWallpaperApplied ? "Applied: " : "Selected: ") + name
}

function applySelectedWallpaper(riseOwner, riseEnvironment) {
    if (!selectedWallpaperCanApply(riseOwner, riseEnvironment)) return false
    var path = riseOwner.selectedWallpaperFile
    var display = String(riseOwner.root.wallpaperManagerDisplay || "all")
    riseOwner.selectedWallpaperApplying = true
    riseOwner.selectedWallpaperApplied = false
    riseOwner.selectedWallpaperScanStarted = false
    riseOwner.selectedWallpaperError = ""
    riseOwner.root.setWallpaperProfile({mode: "single", pinned: path}, display)
    var savedProfile = riseOwner.root.wallpaperProfileFor(display)
    if (!savedProfile || String(savedProfile.pinned || "") !== path) {
        riseOwner.selectedWallpaperApplying = false
        riseOwner.selectedWallpaperScanStarted = false
        riseOwner.selectedWallpaperError = "The selected file was not saved for this display."
        return false
    }
    riseOwner.verifySelectedWallpaperApplication()
    return riseOwner.selectedWallpaperApplying || riseOwner.selectedWallpaperApplied
}

function resetSelectedWallpaperState(riseOwner, riseEnvironment) {
    riseOwner.selectedWallpaperFile = ""
    riseOwner.selectedWallpaperApplying = false
    riseOwner.selectedWallpaperApplied = false
    riseOwner.selectedWallpaperScanStarted = false
    riseOwner.selectedWallpaperError = ""
}

function handleWallpaperProfileChanged(riseOwner, riseEnvironment) {
    if (riseOwner.selectedWallpaperFile !== ""
            && !riseOwner.isMediaFileInFolder(riseOwner.selectedWallpaperFile, riseOwner.profile.folder))
        resetSelectedWallpaperState(riseOwner, riseEnvironment)
    riseOwner.verifySelectedWallpaperApplication()
}

function handleScanInFlightChanged(riseOwner, riseEnvironment) {
    var service = riseOwner.root.wallpaperManagerServiceApi
    if (service && (service.scanInFlight || (service.scanJobs && service.scanJobs.length > 0)))
        riseOwner.selectedWallpaperScanStarted = true
    riseOwner.verifySelectedWallpaperApplication()
}

function handleWallpaperServiceChanged(riseOwner, riseEnvironment) {
    riseOwner.verifySelectedWallpaperApplication()
}

function verifySelectedWallpaperApplication(riseOwner, riseEnvironment) {
    var wasApplying = riseOwner.selectedWallpaperApplying
    if (!wasApplying && !riseOwner.selectedWallpaperApplied) return
    var path = riseOwner.selectedWallpaperFile
    var display = String(riseOwner.root.wallpaperManagerDisplay || "all")
    var currentProfile = riseOwner.root.wallpaperProfileFor(display)
    if (!currentProfile || String(currentProfile.pinned || "") !== path) {
        riseOwner.selectedWallpaperApplying = false
        riseOwner.selectedWallpaperApplied = false
        riseOwner.selectedWallpaperScanStarted = false
        riseOwner.selectedWallpaperError = wasApplying ? "The selected file was not saved for this display." : ""
        return
    }
    var service = riseOwner.root.wallpaperManagerServiceApi
    if (!service || service.scanInFlight || (service.scanJobs && service.scanJobs.length > 0)) return
    var names = display === "all" ? (service.liveScreens || []).map(function(screen) { return String(screen.name) }) : [display]
    var scanErrors = service.scanErrors || {}
    var errors = names.map(function(name) { return String(scanErrors[name] || "") }).filter(function(message) { return message !== "" })
    if (errors.length > 0) {
        riseOwner.selectedWallpaperApplying = false
        riseOwner.selectedWallpaperApplied = false
        riseOwner.selectedWallpaperScanStarted = false
        riseOwner.selectedWallpaperError = errors[0]
        return
    }
    if (!riseOwner.currentWallpaperMatches(path, display)) {
        if (wasApplying && !riseOwner.selectedWallpaperScanStarted) return
        riseOwner.selectedWallpaperApplying = false
        riseOwner.selectedWallpaperApplied = false
        riseOwner.selectedWallpaperScanStarted = false
        riseOwner.selectedWallpaperError = wasApplying ? "The wallpaper service did not confirm the selected file." : ""
        return
    }
    riseOwner.selectedWallpaperApplying = false
    riseOwner.selectedWallpaperApplied = true
    riseOwner.selectedWallpaperScanStarted = false
    riseOwner.selectedWallpaperError = ""
}

function folderPickerStartUrl(riseOwner, riseEnvironment, folderPath) {
    var riseState = riseOwner;

        const raw = String(folderPath || "")
        if (raw === "") return "file:///home"
        const normalized = raw.replace(/\/+$/, "")
        if (normalized === "") return "file:///"
        const separator = normalized.lastIndexOf("/")
        const parent = separator <= 0 ? "/" : normalized.slice(0, separator)
        return "file://" + parent.split("/").map(encodeURIComponent).join("/")
    }

function folderPickerSelectionUrl(riseOwner, riseEnvironment, folderPath) {
    var riseState = riseOwner;

        const raw = String(folderPath || "")
        if (raw === "") return ""
        return "file://" + raw.split("/").map(encodeURIComponent).join("/")
    }

function localPathFromFileUrl(riseOwner, riseEnvironment, fileUrl) {
    var riseState = riseOwner;

        const raw = String(fileUrl || "")
        if (!raw.startsWith("file:///")) return ""
        try { return decodeURIComponent(raw.slice("file://".length)) }
        catch (error) { return "" }
    }

function isMediaFileInFolder(riseOwner, riseEnvironment, filePath, folderPath) {
    var riseState = riseOwner;

        const folder = String(folderPath || "").replace(/\/+$/, "")
        const path = String(filePath || "")
        return folder !== "" && path.indexOf(folder + "/") === 0
            && /\.(jpg|jpeg|png|webp|bmp|gif|mp4|webm|mkv|mov|avi)$/i.test(path)
    }

function stageWallpaperFile(riseOwner, riseEnvironment, fileUrl) {
    var riseState = riseOwner;

        const path = riseOwner.localPathFromFileUrl(fileUrl)
        if (!riseOwner.isMediaFileInFolder(path, riseOwner.profile.folder)) {
            riseOwner.selectedWallpaperFile = ""
            riseOwner.selectedWallpaperApplying = false
            riseOwner.selectedWallpaperApplied = false
            riseOwner.selectedWallpaperScanStarted = false
            riseOwner.selectedWallpaperError = "Choose an image or video inside the configured folder."
            return false
        }
        riseOwner.selectedWallpaperFile = path
        riseOwner.selectedWallpaperApplying = false
        riseOwner.selectedWallpaperApplied = false
        riseOwner.selectedWallpaperScanStarted = false
        riseOwner.selectedWallpaperError = ""
        return true
    }

function applyWallpaperSelection(riseOwner, riseEnvironment, kind, fileUrl, display) {
    var riseState = riseOwner;

        var path = riseOwner.localPathFromFileUrl(fileUrl)
        var service = riseOwner.root.wallpaperManagerServiceApi
        if (!service || !path.startsWith("/") || /[\u0000-\u001f\u007f-\u009f]/.test(path)
                || (kind !== "folder" && kind !== "file")
                || (kind === "file" && !/\.(jpg|jpeg|png|webp|bmp|gif|mp4|webm|mkv|mov|avi)$/i.test(path))) {
            riseOwner.selectedWallpaperError = "Choose a local folder, image or video."
            return false
        }
        var screens = service.liveScreens || []
        var names = display === "all" ? ["all"].concat(screens.map(function(screen) { return String(screen.name) })) : [display]
        if (display === "all" && screens.length === 0) {
            riseOwner.selectedWallpaperError = "No connected displays are available."
            return false
        }
        var folder = kind === "folder" ? path : path.substring(0, path.lastIndexOf("/")) || "/"
        var patch = {folder: folder, mode: kind === "file" ? "single" : "shuffle", pinned: kind === "file" ? path : ""}
        riseOwner.selectedWallpaperFile = ""
        riseOwner.selectedWallpaperApplying = false
        riseOwner.selectedWallpaperApplied = false
        riseOwner.selectedWallpaperScanStarted = false
        riseOwner.selectedWallpaperError = ""
        for (var i = 0; i < names.length; i++) riseOwner.root.setWallpaperProfile(patch, names[i])
        if (kind === "file") {
            riseOwner.selectedWallpaperFile = path
            riseOwner.selectedWallpaperApplying = true
            riseOwner.selectedWallpaperScanStarted = service.scanInFlight || (service.scanJobs && service.scanJobs.length > 0)
            riseOwner.verifySelectedWallpaperApplication()
        }
        return riseOwner.selectedWallpaperError === ""
    }
