.pragma library

// Same configured location and provider as WeatherPanel; no sender URLs.
function weatherUrl(settings) {
    var lat = settings.latitude, lon = settings.longitude
    if (typeof lat === "number" && isFinite(lat) && Math.abs(lat) <= 90
            && typeof lon === "number" && isFinite(lon) && Math.abs(lon) <= 180)
        return "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,weather_code,is_day&timezone=auto"
    var name = typeof settings.name === "string" ? settings.name.trim().slice(0, 80) : ""
    return "https://wttr.in" + (name ? "/" + encodeURIComponent(name) : "") + "?format=j1"
}

function wttrCode(n) {
    if (n === 0) return 113
    if (n === 1 || n === 2) return 116
    if (n === 3) return 119
    if (n === 45 || n === 48) return 143
    if (n >= 51 && n <= 57) return 266
    if (n >= 61 && n <= 67 || n >= 80 && n <= 82) return 308
    if (n >= 71 && n <= 77 || n >= 85 && n <= 86) return 338
    if (n >= 95 && n <= 99) return 389
    throw new Error("Unsupported weather condition")
}

function description(n) {
    if (n === 0) return "Clear sky"
    if (n === 1 || n === 2) return "Partly cloudy"
    if (n === 3) return "Overcast"
    if (n === 45 || n === 48) return "Fog"
    if (n >= 51 && n <= 67 || n >= 80 && n <= 82) return "Rain"
    if (n >= 71 && n <= 77 || n >= 85 && n <= 86) return "Snow"
    return "Thunderstorm"
}

function normalize(data, settings) {
    if (!data || typeof data !== "object") throw new Error("Invalid weather response")
    if (!data.current) return data
    var current = data.current
    if (typeof current.temperature_2m !== "number" || !isFinite(current.temperature_2m)
            || typeof current.weather_code !== "number" || !isFinite(current.weather_code))
        throw new Error("Missing current weather data")
    var code = current.weather_code
    return {
        current_condition: [{ weatherCode: wttrCode(code), temp_C: String(Math.round(current.temperature_2m)),
            weatherDesc: [{ value: description(code) }] }],
        nearest_area: [{ areaName: [{ value: typeof settings.name === "string" ? settings.name : "" }] }],
        isNight: current.is_day === 0
    }
}

// Shared day/night glyphs for the current weather and forecast.
function glyphForCode(code, night) {
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
