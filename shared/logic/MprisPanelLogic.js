// Common behavior for variant-specific presentations.
.pragma library

function fmtTime(riseOwner, riseEnvironment, s) {
    var riseState = riseOwner;

        if (!s || s < 0) return "0:00"
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" + sec : "" + sec)
    }
