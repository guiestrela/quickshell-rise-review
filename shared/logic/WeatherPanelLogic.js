// Common behavior for variant-specific presentations.
.pragma library

function startLocationSuggestions(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var query = riseState.pendingSuggestionQuery
        riseState.activeSuggestionQuery = query
        var country = /^(brasil|brazil)/i.test(query) ? "&countryCode=BR" : ""
        riseEnvironment.locationSuggest.command = ["curl", "-fsS", "--max-time", "5",
            "https://geocoding-api.open-meteo.com/v1/search?name="
            + encodeURIComponent(query) + "&count=8&language=pt&format=json" + country]
        riseEnvironment.locationSuggest.running = true
    }

function chooseSuggestion(riseOwner, riseEnvironment, suggestion) {
    var riseState = riseOwner;

        if (!suggestion) return
        var name = String(suggestion.name || "").trim()
        if (name !== "") riseState.setConfiguredLocation(name, suggestion.latitude, suggestion.longitude)
    }

function tConv(riseOwner, riseEnvironment, c) {
    var riseState = riseOwner;

        var n = parseFloat(c); if (isNaN(n)) return c
        return riseEnvironment.root.weatherImperial ? String(Math.round(n * 9 / 5 + 32)) : String(Math.round(n))
    }

function wConv(riseOwner, riseEnvironment, kmh) {
    var riseState = riseOwner;

        var n = parseFloat(kmh); if (isNaN(n)) return kmh
        return riseEnvironment.root.weatherImperial ? (Math.round(n * 0.621371) + " mph") : (kmh + " km/h")
    }

function glyphForCode(riseOwner, riseEnvironment, code) {
    var riseState = riseOwner;

        var n = parseInt(code) || 0
        if (n === 113) return String.fromCodePoint(0xe30d)
        if (n === 116) return String.fromCodePoint(0xe302)
        if (n === 119 || n === 122) return String.fromCodePoint(0xe33d)
        if (n === 143 || n === 248 || n === 260) return String.fromCodePoint(0xe313)
        if (n === 176 || n === 263 || n === 266 || n === 293 || n === 296 || n === 353) return String.fromCodePoint(0xe308)
        if (n === 179 || n === 227 || n === 230 || n === 323 || n === 326 || n === 368) return String.fromCodePoint(0xe30a)
        if (n === 182 || n === 185 || n === 281 || n === 284 || n === 311 || n === 314 || n === 317 || n === 320 || n === 350 || n === 362 || n === 365 || n === 374 || n === 377) return String.fromCodePoint(0xe3ad)
        if (n === 200 || n === 386 || n === 389 || n === 392 || n === 395) return String.fromCodePoint(0xe31d)
        if (n === 299 || n === 302 || n === 305 || n === 308 || n === 356 || n === 359) return String.fromCodePoint(0xe318)
        if (n === 329 || n === 332 || n === 335 || n === 338 || n === 371) return String.fromCodePoint(0xe31a)
        return String.fromCodePoint(0xe33d)
    }

function dayLabel(riseOwner, riseEnvironment, dateStr, index) {
    var riseState = riseOwner;

        if (index === 0) return "Today"
        if (index === 1) return "Tomorrow"
        var d = new Date(dateStr + "T00:00:00")
        if (isNaN(d.getTime())) return dateStr
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()]
    }

function dayRange(riseOwner, riseEnvironment, day) {
    var riseState = riseOwner;

        var unit = riseEnvironment.root.weatherImperial ? "°F" : "°C"
        return riseState.tConv(day.min) + "°/" + riseState.tConv(day.max) + unit
    }

function chanceOfRain(riseOwner, riseEnvironment, day) {
    var riseState = riseOwner;

        var hourly = day && day.hourly ? day.hourly : []
        var maxRain = 0
        for (var i = 0; i < hourly.length; i++) {
            var rain = parseFloat(hourly[i].chanceofrain)
            if (!isNaN(rain) && rain > maxRain) maxRain = rain
        }
        return maxRain
    }

function forecastCode(riseOwner, riseEnvironment, day) {
    var riseState = riseOwner;

        var hourly = day && day.hourly ? day.hourly : []
        var noon = hourly.length > 4 ? hourly[4] : (hourly.length > 0 ? hourly[0] : null)
        return noon ? (noon.weatherCode || "") : ""
    }
