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

function glyphForCode(riseOwner, riseEnvironment, code, night) {
    var riseState = riseOwner;

        const n = parseInt(code) || 0
        if (n === 113) return night ? String.fromCodePoint(0xe32b) : String.fromCodePoint(0xe30d)
        if (n === 116) return night ? String.fromCodePoint(0xe32e) : String.fromCodePoint(0xe302)
        if (n === 119 || n === 122) return String.fromCodePoint(0xe33d)
        if (n === 143 || n === 248 || n === 260) return String.fromCodePoint(0xe313)
        if (n === 176 || n === 263 || n === 266 || n === 293 || n === 296 || n === 353) return night ? String.fromCodePoint(0xe333) : String.fromCodePoint(0xe308)
        if (n === 179 || n === 227 || n === 230 || n === 323 || n === 326 || n === 368) return night ? String.fromCodePoint(0xe327) : String.fromCodePoint(0xe30a)
        if (n === 182 || n === 185 || n === 281 || n === 284 || n === 311 || n === 314 || n === 317 || n === 320 || n === 350 || n === 362 || n === 365 || n === 374 || n === 377) return String.fromCodePoint(0xe3ad)
        if (n === 200 || n === 386 || n === 389 || n === 392 || n === 395) return String.fromCodePoint(0xe31d)
        if (n === 299 || n === 302 || n === 305 || n === 308 || n === 356 || n === 359) return String.fromCodePoint(0xe318)
        if (n === 329 || n === 332 || n === 335 || n === 338 || n === 371) return String.fromCodePoint(0xe31a)
        return String.fromCodePoint(0xe33d)
    }
