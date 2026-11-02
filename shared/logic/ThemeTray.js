// Shared behavior; owner is the active variant, environment supplies QML services.
.pragma library

function trayDisplayName(riseOwner, riseEnvironment, item) {
    var riseState = riseOwner;

        if (!item) return "Tray App"

        var title = String(item.title || "").trim()
        if (title !== "") return title

        var tooltipTitle = String(item.tooltipTitle || "").trim()
        if (tooltipTitle !== "") return tooltipTitle

        var fallback = String(item.id || "").trim()
        var slash = fallback.lastIndexOf("/")
        if (slash >= 0 && slash < fallback.length - 1)
            fallback = fallback.substring(slash + 1)
        fallback = fallback.replace(/^org\.(kde|ayatana|freedesktop)\./i, "")
                           .replace(/[_-]+/g, " ")
        return fallback !== "" ? fallback : "Tray App"
    }

function trayDescription(riseOwner, riseEnvironment, item, displayName) {
    var riseState = riseOwner;

        if (!item) return ""

        var description = String(item.tooltipDescription || "").trim()
        var tooltipTitle = String(item.tooltipTitle || "").trim()
        var name = String(displayName || "").trim().toLowerCase()
        if (description !== "" && description.toLowerCase() !== name)
            return description
        if (tooltipTitle !== "" && tooltipTitle.toLowerCase() !== name)
            return tooltipTitle
        return ""
    }

function trayToggleHide(riseOwner, riseEnvironment, item) {
    var riseState = riseOwner;

        var key = item.id
        if (!key) return
        var i = riseState.trayPinned.indexOf(key)
        if (i >= 0) {
            var a = riseState.trayPinned.slice(0, i)
            var b = riseState.trayPinned.slice(i + 1)
            riseState.trayPinned = a.concat(b)
            riseState.trayVisible = false
        } else {
            riseState.trayPinned = riseState.trayPinned.concat([key])
        }
    }
