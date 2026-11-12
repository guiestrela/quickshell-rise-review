import Quickshell
import Quickshell.Io
import QtQuick
import "../shared/services" as Services

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int phaseTicks: 0
    property int probeCount: 0
    property int cancelCount: 0
    property int timezoneCount: 0
    property int geocodeCount: 0
    property string lastGeocodeQuery: ""
    property int lastGeocodeSerial: 0
    property string lastTimezoneZone: ""
    property int lastTimezoneSerial: 0
    property int weatherCount: 0
    property var lastWeatherKeys: []
    property var lastWeatherPoints: []
    property int lastWeatherSerial: 0
    property double initialTimerMs: 0
    property bool failureObserved: false
    property var lastProbeIds: []

    Services.ElsewhenService {
        id: service
        settingsPath: Quickshell.env("RISE_ELSEWHEN_SETTINGS_PATH")
        autoRefresh: false
    }

    Connections {
        target: service
        function onProbeRequested(ids) {
            test.probeCount++
            test.lastProbeIds = ids
        }
        function onCancelRequested() { test.cancelCount++ }
        function onTimezoneChangeRequested(zone, serial) {
            test.timezoneCount++
            test.lastTimezoneZone = zone
            test.lastTimezoneSerial = serial
        }
        function onWeatherRequested(keys, points, serial) {
            test.weatherCount++
            test.lastWeatherKeys = keys
            test.lastWeatherPoints = points
            test.lastWeatherSerial = serial
        }
        function onPlaceSearchRequested(query, serial) {
            test.geocodeCount++
            test.lastGeocodeQuery = query
            test.lastGeocodeSerial = serial
        }
    }

    function fail(message) {
        console.error("ELSEWHEN_SERVICE_FAIL " + message)
        Qt.quit()
    }

    Timer {
        interval: 25
        repeat: true
        running: true
        onTriggered: {
            test.ticks++
            if (test.ticks > 200) {
                test.fail("bounded fixture timeout, phase=" + test.phase)
                return
            }
            if (test.phase === 0 && service.settingsReady && service.staticDataReady) {
                if (!service.staticDataReady || !service.worldData || service.worldData.length === 0
                        || !service.cityData || !service.cityData.some(function(city) {
                            return city[0] === "Tokyo" && city[1] === "Asia/Tokyo"
                        })) {
                    test.fail("bundled globe and city data were not loaded")
                    return
                }
                if (typeof service.acceptZoneCatalog !== "function" || typeof service.searchZones !== "function") {
                    test.fail("zone catalog and search entry points are missing")
                    return
                }
                service.acceptZoneCatalog("America/New_York\nEurope/Paris\nAsia/Tokyo\n", 0)
                var parisMatches = service.searchZones("paris", 6)
                var newYorkAvailable = service.zoneOptions.some(function(option) {
                    return option.value === "America/New_York"
                })
                var duplicateTokyo = service.zoneOptions.some(function(option) {
                    return option.value === "Asia/Tokyo" && option.label === "Tokyo"
                })
                if (parisMatches.length === 0 || parisMatches[0].value !== "Europe/Paris"
                        || !newYorkAvailable || duplicateTokyo) {
                    test.fail("zone search did not merge IANA zones, aliases, and existing cities correctly")
                    return
                }
                if (service.active || service.clockTimerRunning || test.probeCount !== 0) {
                    test.fail("service performed routine work while inactive")
                    return
                }
                test.initialTimerMs = service.nowMs
                service.active = true
                service.refresh()
                test.phase = 1
            } else if (test.phase === 1 && test.probeCount === 1) {
                if (service.nowMs <= test.initialTimerMs) return
                if (!service.probeRunning || test.lastProbeIds.indexOf("Asia/Tokyo") < 0) {
                    test.fail("refresh request did not contain the selected IANA zone")
                    return
                }
                service.acceptProbe("LOCAL|Etc/UTC\nEtc/UTC|UTC|+0000\nAsia/Tokyo|JST|+0900\n", 0)
                service.nowMs = Date.UTC(2026, 0, 1, 12, 0)
                if (service.probeRunning || service.localZone !== "Etc/UTC"
                        || service.probe["Asia/Tokyo"].offsetMinutes !== 540
                        || service.localOffsetMinutes !== 0 || !service.clockRows
                        || service.clockRows.length !== 1 || service.clockRows[0].hour !== 21) {
                    test.fail("injected successful probe did not produce deterministic clock rows: "
                              + JSON.stringify({ zone: service.localZone, localOffset: service.localOffsetMinutes,
                                  rowCount: service.clockRows ? service.clockRows.length : -1,
                                  row: service.clockRows && service.clockRows.length ? service.clockRows[0] : null }))
                    return
                }
                service.active = false
                test.phase = 2
            } else if (test.phase === 2 && !service.clockTimerRunning) {
                if (typeof service.updateSetting !== "function") {
                    test.fail("settings persistence entry point is missing")
                    return
                }
                service.updateSetting("hour24", true)
                if (service.preferenceData.hour24 !== true || !service.clockRows
                        || service.clockRows[0].time !== "21:00") {
                    test.fail("setting update did not update the in-memory clock format")
                    return
                }
                if (!service.updateSetting("homeCity", "Cebu") || service.preferenceData.homeCity !== "Cebu") {
                    test.fail("the local city override was not accepted as a setting")
                    return
                }
                test.phase = 3
                test.phaseTicks = 0
            } else if (test.phase === 3) {
                test.phaseTicks++
                if (test.phaseTicks >= 6) {
                    if (typeof service.addCity !== "function" || typeof service.moveCity !== "function"
                            || typeof service.removeCity !== "function") {
                        test.fail("city edit entry points are missing")
                        return
                    }
                    if (!service.addCity("Europe/Paris", "Paris", { lat: 48.8566, lon: 2.3522 })
                            || service.cities.length !== 2 || service.cities[1].lat !== 48.8566) {
                        test.fail("adding a city did not preserve its IANA zone and coordinates")
                        return
                    }
                    if (!service.moveCity(1, 0) || service.cities[0].id !== "Europe/Paris") {
                        test.fail("city reordering did not update the model")
                        return
                    }
                    if (!service.removeCity(1) || service.cities.length !== 1
                            || service.removeCity(0) || service.cities.length !== 1) {
                        test.fail("city removal did not preserve the required final clock")
                        return
                    }
                    test.phase = 4
                    test.phaseTicks = 0
                }
            } else if (test.phase === 4) {
                test.phaseTicks++
                if (test.phaseTicks >= 6) {
                    service.active = true
                    if (!service.refresh()) {
                        test.fail("manual refresh did not start")
                        return
                    }
                    test.phase = 5
                }
            } else if (test.phase === 5 && test.probeCount === 2) {
                if (!service.probeRunning) {
                    test.fail("probe request did not remain in flight")
                    return
                }
                service.refresh()
                if (test.probeCount !== 2 || !service.probeQueued) {
                    test.fail("in-flight refresh was not coalesced into one queued request")
                    return
                }
                var failedSerial = service.requestSerial
                if (service.acceptProbe("", 1, failedSerial) || service.lastError.indexOf("failed") < 0) {
                    test.fail("probe failure was not returned to the service")
                    return
                }
                test.failureObserved = true
                test.phase = 6
            } else if (test.phase === 6 && test.probeCount === 3) {
                if (!test.failureObserved || !service.probeRunning || service.lastError !== "") {
                    test.fail("queued retry did not start after the failed probe")
                    return
                }
                var staleSerial = service.requestSerial
                service.active = false
                if (test.cancelCount !== 1 || service.probeRunning || service.clockTimerRunning) {
                    test.fail("closing did not cancel the in-flight probe and clock timer")
                    return
                }
                if (service.acceptProbe("LOCAL|Europe/Paris\n", 0, staleSerial)) {
                    test.fail("stale probe completion was accepted after close")
                    return
                }
                if (typeof service.requestTimezoneChange !== "function"
                        || typeof service.acceptTimezoneChange !== "function") {
                    test.fail("time-zone change request and result handlers are missing")
                    return
                }
                var savedTransientZones = service.transientZones
                service.active = false
                if (typeof service.ensureProbeZone !== "function"
                        || !service.ensureProbeZone("America/Chicago")
                        || service.probeIds.indexOf("America/Chicago") < 0) {
                    test.fail("a selected untracked globe zone was not added to transient probe IDs")
                    service.transientZones = savedTransientZones
                    return
                }
                service.transientZones = savedTransientZones
                service.active = true
                var selectedHome = { name: "Paris", zone: "Europe/Paris", lat: 48.8566, lon: 2.3522 }
                if (!service.requestTimezoneChange("Europe/Paris", selectedHome, service.cities) || test.timezoneCount !== 1
                        || test.lastTimezoneZone !== "Europe/Paris") {
                    test.fail("explicit time-zone request was not dispatched to the command boundary")
                    return
                }
                var failedTimezoneSerial = test.lastTimezoneSerial
                if (service.acceptTimezoneChange(1, failedTimezoneSerial, "inert helper denied action")
                        || service.timezoneError.indexOf("inert helper denied action") < 0
                        || service.localZone !== "Etc/UTC" || service.preferenceData.here !== undefined
                        || service.pendingHereUpdate) {
                    test.fail("time-zone command failure was not visible or changed local state")
                    return
                }
                if (!service.requestTimezoneChange("Europe/Paris", selectedHome, service.cities) || test.timezoneCount !== 2) {
                    test.fail("time-zone request did not recover after a failed attempt")
                    return
                }
                if (!service.acceptTimezoneChange(0, test.lastTimezoneSerial, "")
                        || service.localZone !== "Europe/Paris" || service.timezoneError !== ""
                        || service.preferenceData.here.name !== "Paris"
                        || service.preferenceData.here.zone !== "Europe/Paris"
                        || service.preferenceData.here.lat !== 48.8566
                        || service.preferenceData.homeCity !== undefined) {
                    test.fail("successful time-zone command result was not applied")
                    return
                }
                if (typeof service.requestPlaceSearch !== "function" || typeof service.acceptPlaceSearch !== "function"
                        || typeof service.searchLocations !== "function") {
                    test.fail("place-search request and result handlers are missing")
                    return
                }
                if (!service.requestPlaceSearch("Springfield") || test.geocodeCount !== 1
                        || test.lastGeocodeQuery !== "springfield") {
                    test.fail("geocoder query was not normalized and dispatched")
                    return
                }
                var resultSerial = test.lastGeocodeSerial
                var geocodePayload = JSON.stringify({ results: [{
                    name: "Springfield", admin1: "Illinois", country_code: "US",
                    timezone: "America/Chicago", latitude: 39.78, longitude: -89.64
                }] })
                if (!service.acceptPlaceSearch(geocodePayload, 0, resultSerial, "")) {
                    test.fail("inert geocoder result was not accepted")
                    return
                }
                var places = service.searchLocations("Springfield", 8)
                if (places.length !== 1 || places[0].label !== "Springfield"
                        || places[0].region !== "Illinois, US" || places[0].value !== "America/Chicago") {
                    test.fail("geocoder place did not merge into the selectable search results: " + JSON.stringify(places))
                    return
                }
                if (!service.requestPlaceSearch("Boston") || test.geocodeCount !== 2
                        || test.lastGeocodeQuery !== "boston") {
                    test.fail("a new place query was not dispatched")
                    return
                }
                if (service.acceptPlaceSearch(geocodePayload, 0, resultSerial, "")) {
                    test.fail("stale geocoder response was accepted")
                    return
                }
                if (service.acceptPlaceSearch("", 1, test.lastGeocodeSerial, "inert geocoder denial")
                        || service.placeSearchError.indexOf("inert geocoder denial") < 0) {
                    test.fail("geocoder failure was not returned to the service")
                    return
                }
                if (!service.requestPlaceSearch("Portland")) {
                    test.fail("place-search request before hiding was not dispatched")
                    return
                }
                var hiddenSearchSerial = test.lastGeocodeSerial
                service.active = false
                if (service.placeSearchRunning) {
                    test.fail("hiding did not clear the in-flight geocoder state")
                    return
                }
                if (service.requestPlaceSearch("Salem") || service.placeSearchRunning
                        || service.placeSearchText !== "salem") {
                    test.fail("query changed while hidden did not remain queued for reactivation")
                    return
                }
                service.active = true
                if (!service.placeSearchRunning || test.geocodeCount !== 4 || test.lastGeocodeQuery !== "salem") {
                    test.fail("latest hidden query was not retried on reactivation")
                    return
                }
                if (service.acceptPlaceSearch(geocodePayload, 0, hiddenSearchSerial, "")) {
                    test.fail("pre-hide geocoder result was accepted after reactivation")
                    return
                }
                var resumedSearchSerial = test.lastGeocodeSerial
                var resumedPayload = JSON.stringify({ results: [{
                    name: "Salem", admin1: "Oregon", country_code: "US",
                    timezone: "America/Los_Angeles", latitude: 44.94, longitude: -123.04
                }] })
                if (!service.acceptPlaceSearch(resumedPayload, 0, resumedSearchSerial, "")
                        || service.geocodeOptions.length !== 1 || service.geocodeOptions[0].label !== "Salem") {
                    test.fail("reactivated geocoder result did not populate the latest query")
                    return
                }
                if (!service.requestWeather(["Tokyo|Asia/Tokyo"], [{ lat: 35.68, lon: 139.69 }])
                        || test.weatherCount !== 1 || test.lastWeatherPoints[0].lat !== 35.68) {
                    test.fail("weather request did not dispatch the city key and coordinates")
                    return
                }
                if (!service.acceptWeather(JSON.stringify({ current: { temperature_2m: 18.4, weather_code: 2 } }),
                        0, test.lastWeatherKeys, test.lastWeatherPoints, test.lastWeatherSerial)
                        || service.weather["Tokyo|Asia/Tokyo"].c !== 18.4
                        || service.weather["Tokyo|Asia/Tokyo"].w !== 2) {
                    test.fail("fixture weather result was not stored against its city")
                    return
                }
                service.active = false
                console.log("ELSEWHEN_SERVICE_PASS lifecycle, settings, cities, probes, place search, time-zone and weather results")
                Qt.quit()
            }
        }
    }
}
