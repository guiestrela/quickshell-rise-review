.pragma library

// Only the selected, current app QObject action. Never execute notification
// argv or infer a URL from text; historical identities cannot resolve liveRefs.
function invokeDefault(service, entry) {
    try {
        if (!service || !entry || entry.backend !== "omarchy"
                || typeof entry.appName !== "string" || entry.appName.length === 0
                || typeof entry.id !== "number" || entry.id <= 0 || Math.floor(entry.id) !== entry.id
                || typeof entry.timestamp !== "number" || entry.timestamp <= 0
                || Math.floor(entry.timestamp) !== entry.timestamp) return false
        var match = null
        for (var i = 0; i < service.popupModel.count; i++) {
            var row = service.popupModel.get(i)
            if (!row || row.originalId !== entry.id || row.timestamp !== entry.timestamp) continue
            if (match) return false
            match = row
        }
        if (!match || service.isRestoredRow(match) || match.execArgv
                || match.app !== entry.appName || match.summary !== entry.summary
                || match.body !== entry.body) return false
        var ref = service.liveRefs[entry.id]
        if (!ref || ref.id !== entry.id || ref.tracked !== true
                || ref.appName !== entry.appName || ref.summary !== entry.summary
                || ref.body !== entry.body) return false
        var defaults = []
        for (var a = 0; a < ref.actions.length; a++) {
            var action = ref.actions[a]
            if (action && action.identifier === "default" && typeof action.invoke === "function") defaults.push(action)
        }
        if (defaults.length !== 1) return false
        defaults[0].invoke()
        return true
    } catch (error) {
        return false  // Expired QObject: no cached callback or id-only replay.
    }
}

function invokeChromium(service, entry) {
    return !!entry && entry.appName === "Chromium" && invokeDefault(service, entry)
}

function serviceFor(theme) {
    try {
        var bar = theme.variantHost && theme.variantHost.parent
        return bar && bar.shell && typeof bar.shell.serviceFor === "function"
            ? bar.shell.serviceFor("omarchy.notifications") : null
    } catch (error) { return null }
}
