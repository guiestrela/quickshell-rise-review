// Common behavior for variant-specific presentations.
.pragma library

function fmtDuration(riseOwner, riseEnvironment, s) {
    var riseState = riseOwner;

        if (!s || s <= 0) return ""
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        return h > 0 ? (h + "h " + m + "m") : (m + "m")
    }
