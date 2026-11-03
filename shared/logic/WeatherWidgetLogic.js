// Common behavior for variant-specific presentations.
.pragma library

function refresh(riseOwner, riseEnvironment, force) {
    var riseState = riseOwner;

        if (riseEnvironment.weatherProc.running) {
            if (force) riseOwner.refreshPending = true
            return
        }
        riseOwner.requestSettings = riseOwner.locationSettings
        riseOwner.requestGeneration = riseOwner.locationGeneration
        riseEnvironment.weatherProc.running = true
    }

function minutesForClock(riseOwner, riseEnvironment, s) {
    var riseState = riseOwner;

        const m = String(s || "").match(/^(\d{1,2}):(\d{2})\s*([AP]M)$/i)
        if (!m) return -1
        let h = parseInt(m[1]) || 0
        const min = parseInt(m[2]) || 0
        const ap = m[3].toUpperCase()
        if (ap === "PM" && h !== 12) h += 12
        if (ap === "AM" && h === 12) h = 0
        return h * 60 + min
    }

function isNight(riseOwner, riseEnvironment, sunrise, sunset) {
    var riseState = riseOwner;

        const rise = riseState.minutesForClock(sunrise)
        const set = riseState.minutesForClock(sunset)
        if (rise < 0 || set < 0) return false
        const now = new Date()
        const mins = now.getHours() * 60 + now.getMinutes()
        return mins < rise || mins >= set
    }
