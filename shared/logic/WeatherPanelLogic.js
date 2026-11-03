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
