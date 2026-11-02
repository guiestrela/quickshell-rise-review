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
