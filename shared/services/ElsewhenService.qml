import QtQuick
import Quickshell
import Quickshell.Io
import "../integrations/elsewhen/Model.js" as Model

Item {
    id: service
    visible: false
    width: 0
    height: 0

    property string settingsPath: ""
    property bool active: false
    property bool autoRefresh: true
    property bool settingsReady: false
    property var preferenceData: ({
        schemaVersion: 1,
        cities: [],
        zones: Model.DEFAULT_ZONES,
        hour24: false,
        offsetMode: "home",
        globeEnabled: true,
        smoothMotion: true
    })
    property var probe: ({})
    property var weather: ({})
    property bool weatherRunning: false
    property int weatherSerial: 0
    property string localZone: ""
    property int localOffsetMinutes: -(new Date().getTimezoneOffset())
    property string lastError: ""
    property int requestSerial: 0
    property double nowMs: Date.now()
    property bool probeRunning: false
    property bool probeQueued: false
    property var worldData: []
    property var cityData: []
    property bool worldDataReady: false
    property bool cityDataReady: false
    property string zoneCatalogText: ""
    property string catalogError: ""
    property bool catalogRunning: false
    property int catalogSerial: 0
    property var geocodeOptions: []
    property string placeSearchText: ""
    property string placeSearchError: ""
    property bool placeSearchRunning: false
    property int placeSearchSerial: 0
    property bool timezoneRunning: false
    property int timezoneSerial: 0
    property string pendingTimezoneZone: ""
    property string timezoneError: ""

    readonly property bool staticDataReady: worldDataReady && cityDataReady
    readonly property bool clockTimerRunning: clockTimer.running
    readonly property bool hour24: preferenceData.hour24 === true
    readonly property var cities: Model.parseCities(preferenceData.cities, preferenceData.zones)
    readonly property var clockRows: Model.rows(cities, probe, nowMs, localOffsetMinutes, hour24)
    readonly property var zoneOptions: Model.zoneOptions(zoneCatalogText, cities)
    readonly property var probeIds: {
        var ids = []
        for (var i = 0; i < cities.length; i++) {
            if (ids.indexOf(cities[i].id) < 0) ids.push(cities[i].id)
        }
        if (localZone !== "" && ids.indexOf(localZone) < 0) ids.push(localZone)
        return ids
    }

    signal probeRequested(var ids, int serial)
    signal catalogRequested(int serial)
    signal placeSearchRequested(string query, int serial)
    signal timezoneChangeRequested(string zone, int serial)
    signal weatherRequested(var keys, var points, int serial)
    signal timezoneChanged(string zone)
    signal cancelRequested()
    signal settingsLoaded()

    function persistPreferences(next) {
        if (!settingsReady || settingsPath === "") {
            lastError = "Elsewhen settings are not writable"
            return false
        }
        var saved = Object.assign({}, next)
        saved.schemaVersion = 1
        preferenceData = saved
        preferences.setText(JSON.stringify(saved))
        return true
    }

    function updateSetting(name, value) {
        var writable = ["cities", "zones", "hour24", "offsetMode", "globeEnabled", "smoothMotion", "homeZone", "units"]
        if (writable.indexOf(name) < 0) {
            lastError = "Unsupported Elsewhen setting: " + name
            return false
        }
        var next = Object.assign({}, preferenceData)
        next[name] = value
        return persistPreferences(next)
    }

    function setCities(nextCities) {
        if (!Array.isArray(nextCities)) return false
        var next = Object.assign({}, preferenceData)
        next.cities = Model.serializeCities(nextCities)
        delete next.zones
        return persistPreferences(next)
    }

    function addCity(id, label, place) {
        var current = cities
        var next = Model.addZone(current, id, label, place)
        return next === current ? false : setCities(next)
    }

    function removeCity(index) {
        var current = cities
        var next = Model.removeZoneAt(current, index)
        return next === current ? false : setCities(next)
    }

    function moveCity(from, to) {
        var current = cities
        var next = Model.moveZone(current, from, to)
        return next === current ? false : setCities(next)
    }

    function requestTimezoneChange(zone) {
        var targetZone = String(zone || "").trim()
        var parsed = Model.parseZones(targetZone)
        if (!active || !settingsReady || timezoneRunning || parsed.length !== 1 || parsed[0].id !== targetZone) {
            timezoneError = "A valid open-panel time-zone change is required"
            return false
        }
        timezoneError = ""
        pendingTimezoneZone = targetZone
        timezoneRunning = true
        timezoneSerial++
        timezoneChangeRequested(targetZone, timezoneSerial)
        return true
    }

    function acceptTimezoneChange(exitCode, serial, errorText) {
        if (!timezoneRunning || (serial !== undefined && serial !== timezoneSerial)) return false
        timezoneRunning = false
        if (exitCode !== 0) {
            var message = String(errorText || "").trim()
            timezoneError = message !== "" ? message : "Time-zone change failed (exit " + exitCode + ")"
            pendingTimezoneZone = ""
            return false
        }
        localZone = pendingTimezoneZone
        if (probe[localZone]) localOffsetMinutes = probe[localZone].offsetMinutes
        var changedZone = localZone
        pendingTimezoneZone = ""
        timezoneError = ""
        timezoneChanged(changedZone)
        return true
    }

    function requestCatalog() {
        if (!active || !settingsReady || catalogRunning) return false
        catalogError = ""
        catalogRunning = true
        catalogSerial++
        catalogRequested(catalogSerial)
        return true
    }

    function acceptZoneCatalog(output, exitCode, serial, errorText) {
        if (serial !== undefined && serial !== catalogSerial) return false
        catalogRunning = false
        if (exitCode !== 0) {
            var message = String(errorText || "").trim()
            catalogError = message !== "" ? message : "Time-zone catalog query failed (exit " + exitCode + ")"
            return false
        }
        zoneCatalogText = String(output || "")
        catalogError = ""
        return true
    }

    function searchZones(query, limit) {
        return Model.searchZones(zoneOptions, query, limit)
    }

    function requestPlaceSearch(text) {
        var query = Model.placeQuery(text)
        if (query === "") {
            placeSearchSerial++
            placeSearchText = ""
            placeSearchRunning = false
            geocodeOptions = []
            placeSearchError = ""
            return false
        }
        if (query === placeSearchText && (placeSearchRunning || (geocodeOptions.length > 0 && placeSearchError === "")))
            return false
        placeSearchText = query
        geocodeOptions = []
        placeSearchError = ""
        placeSearchSerial++
        if (!active || !settingsReady) return false
        placeSearchRunning = true
        placeSearchRequested(query, placeSearchSerial)
        return true
    }

    function acceptPlaceSearch(output, exitCode, serial, errorText) {
        if (!placeSearchRunning || (serial !== undefined && serial !== placeSearchSerial)) return false
        placeSearchRunning = false
        if (exitCode !== 0) {
            var message = String(errorText || "").trim()
            placeSearchError = message !== "" ? message : "Place search failed (exit " + exitCode + ")"
            geocodeOptions = []
            return false
        }
        geocodeOptions = Model.placeOptions(String(output || ""))
        placeSearchError = ""
        return true
    }

    function searchLocations(query, limit) {
        var maxResults = Math.max(0, Number(limit) || 8)
        var queryKey = Model.placeQuery(query)
        var hasCurrentPlaces = queryKey !== "" && queryKey === placeSearchText
        var offlineLimit = hasCurrentPlaces && maxResults > 3 ? Math.max(3, maxResults - 5) : maxResults
        var offline = searchZones(query, offlineLimit)
        var places = hasCurrentPlaces ? geocodeOptions : []
        return Model.mergePlaces(offline, places, cities, maxResults)
    }

    function refresh() {
        if (!active || !settingsReady) return false
        if (probeRunning) {
            probeQueued = true
            return false
        }
        lastError = ""
        probeRunning = true
        requestSerial++
        probeRequested(probeIds, requestSerial)
        return true
    }

    function requestWeather(keys, points) {
        if (!active || !Array.isArray(keys) || !Array.isArray(points) || keys.length === 0 || keys.length > 20 || keys.length !== points.length || weatherRunning) return false
        for (var i = 0; i < points.length; i++) {
            if (!points[i] || !isFinite(Number(points[i].lat)) || !isFinite(Number(points[i].lon))
                    || Number(points[i].lat) < -90 || Number(points[i].lat) > 90
                    || Number(points[i].lon) < -180 || Number(points[i].lon) > 180) return false
        }
        weatherRunning = true
        weatherSerial++
        weatherRequested(keys.slice(), points.slice(), weatherSerial)
        return true
    }

    function acceptWeather(output, exitCode, keys, points, serial) {
        if (!weatherRunning || serial !== weatherSerial) return false
        weatherRunning = false
        if (exitCode !== 0) return false
        var fresh = Model.parseForecast(output, keys, Date.now(), points)
        weather = Object.assign({}, weather, fresh)
        return true
    }

    function finishProbeCycle() {
        if (probeQueued && active) {
            probeQueued = false
            Qt.callLater(function() { service.refresh() })
        } else {
            probeQueued = false
        }
    }

    function acceptProbe(output, exitCode, serial, errorText) {
        if (!probeRunning || (serial !== undefined && serial !== requestSerial)) return false
        probeRunning = false
        if (exitCode !== 0) {
            var message = String(errorText || "").trim()
            lastError = message !== "" ? message : "Time-zone probe failed (exit " + exitCode + ")"
            finishProbeCycle()
            return false
        }
        probe = Model.parseProbe(output)
        var detected = Model.localZoneFromProbe(output)
        if (detected !== "") {
            localZone = detected
            if (probe[detected]) localOffsetMinutes = probe[detected].offsetMinutes
        }
        lastError = ""
        nowMs = Date.now()
        finishProbeCycle()
        return true
    }

    onActiveChanged: {
        if (active) {
            if (autoRefresh && settingsReady) {
                requestCatalog()
                refresh()
            }
            if (settingsReady && placeSearchText !== "" && !placeSearchRunning) requestPlaceSearch(placeSearchText)
        } else {
            clockTimer.stop()
            if (probeRunning || catalogRunning || placeSearchRunning || timezoneRunning) cancelRequested()
            if (probeRunning) requestSerial++
            if (catalogRunning) catalogSerial++
            if (placeSearchRunning) placeSearchSerial++
            if (timezoneRunning) timezoneSerial++
            probeRunning = false
            probeQueued = false
            catalogRunning = false
            placeSearchRunning = false
            timezoneRunning = false
            if (weatherRunning) weatherSerial++
            weatherRunning = false
            pendingTimezoneZone = ""
        }
    }
    onSettingsReadyChanged: if (settingsReady && active) {
        if (autoRefresh) {
            requestCatalog()
            refresh()
        }
        if (placeSearchText !== "" && !placeSearchRunning) requestPlaceSearch(placeSearchText)
    }

    FileView {
        id: worldFile
        path: Qt.resolvedUrl("../integrations/elsewhen/world.json")
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                var data = JSON.parse(text())
                if (Array.isArray(data)) service.worldData = data
                else service.lastError = "Bundled globe data has an invalid shape"
            } catch (error) {
                service.lastError = "Bundled globe data could not be read"
            }
            service.worldDataReady = true
        }
    }

    FileView {
        id: citiesFile
        path: Qt.resolvedUrl("../integrations/elsewhen/cities.json")
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                var data = JSON.parse(text())
                if (Array.isArray(data)) service.cityData = data
                else service.lastError = "Bundled city data has an invalid shape"
            } catch (error) {
                service.lastError = "Bundled city data could not be read"
            }
            service.cityDataReady = true
        }
    }

    FileView {
        id: preferences
        path: service.settingsPath
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                var parsed = JSON.parse(text())
                if (parsed && typeof parsed === "object" && !Array.isArray(parsed))
                    service.preferenceData = Object.assign({}, service.preferenceData, parsed)
            } catch (error) {
                service.lastError = "Invalid Elsewhen settings; defaults retained"
            }
            service.settingsReady = true
            service.settingsLoaded()
        }
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) {
                // First run: persist defaults atomically; unlock the service only
                // after FileView confirms that the file was actually saved.
                preferences.setText(JSON.stringify(service.preferenceData))
            } else {
                service.lastError = "Elsewhen settings could not be loaded (" + error + ")"
            }
        }
        onSaved: {
            service.settingsReady = true
            service.lastError = ""
            service.settingsLoaded()
        }
        onSaveFailed: function(error) {
            service.lastError = "Elsewhen settings could not be saved (" + error + ")"
        }
    }

    Timer {
        id: clockTimer
        interval: 1000
        repeat: true
        running: service.active
        onTriggered: service.nowMs = Date.now()
    }

    Timer {
        interval: 300000
        repeat: true
        running: service.active && service.autoRefresh
        onTriggered: service.refresh()
    }
}
