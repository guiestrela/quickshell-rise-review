// Pure settings adapter for Rise's one wallpaper owner; no processes or I/O.
function safePath(path, home) {
    var value = String(path || "").trim()
    if (value === "~") value = String(home || "")
    else if (value.indexOf("~/") === 0) value = String(home || "") + value.substring(1)
    if (value.length > 4096 || value.charAt(0) !== "/"
        || /[\u0000-\u001f\u007f-\u009f]/.test(value)
        || value.split("/").indexOf("..") !== -1) return ""
    return value
}

function configFor(settings, outputName, home) {
    var entries = settings.displayConfig || ({})
    var own = settings.perDisplayConfig === true ? entries[String(outputName)] : null
    var chosen = own && typeof own === "object" ? own
        : entries.all && typeof entries.all === "object" ? entries.all : ({})
    function pick(key, fallback) {
        return chosen[key] !== undefined && chosen[key] !== null ? chosen[key] : fallback
    }
    var folder = safePath(pick("folder", settings.folder || ""), home)
    var pinned = safePath(pick("pinned", ""), home)
    if (folder === "" || pinned.indexOf(folder + "/") !== 0) pinned = ""
    return {
        folder: folder,
        recursive: pick("recursive", settings.recursive) !== false,
        mode: pick("mode", "shuffle") === "single" ? "single" : "shuffle",
        scaling: ["zoom", "fitHeight", "fitWidth", "actual"].indexOf(pick("scaling", "zoom")) !== -1
            ? pick("scaling", "zoom") : "zoom",
        pinned: pinned
    }
}

function updateDisplay(settings, outputName, patch, home) {
    var key = settings.perDisplayConfig === true ? String(outputName) : "all"
    var current = configFor(settings, outputName, home)
    var entries = Object.assign({}, settings.displayConfig || ({}))
    var changed = Object.assign({}, current)
    if (patch.folder !== undefined) {
        changed.folder = safePath(patch.folder, home)
        if (changed.folder !== current.folder) changed.pinned = ""
    }
    if (patch.mode === "single" || patch.mode === "shuffle") changed.mode = patch.mode
    if (patch.pinned !== undefined) {
        var pin = safePath(patch.pinned, home)
        if (patch.pinned === "" || (changed.folder !== "" && pin.indexOf(changed.folder + "/") === 0))
            changed.pinned = pin
    }
    entries[key] = changed
    var result = Object.assign({}, settings)
    result.displayConfig = entries
    return result
}
