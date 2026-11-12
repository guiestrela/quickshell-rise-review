import Quickshell
import Quickshell.Io
import QtQuick
import "../shared/services" as Services
import "../shared/panels" as Panels

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int phaseTicks: 0
    property string helperPath: Quickshell.env("RISE_ELSEWHEN_TEST_HELPER")
    property bool failProbe: false
    property bool failCatalog: false

    QtObject {
        id: fakeTheme
        property color bg: "#1d2021"
        property color ink: "#ebdbb2"
        property color seal: "#d79921"
        property color sep: "#504945"
        property color fillIdle: "#282828"
        property color fillHover: "#3c3836"
        property color sumi: "#928374"
        property string mono: "monospace"
    }

    Panels.ElsewhenPanelContent {
        id: content
        x: 0
        y: 0
        width: 380
        height: 620
        root: fakeTheme
        service: service
    }

    Services.ElsewhenService {
        id: service
        settingsPath: Quickshell.env("RISE_ELSEWHEN_SETTINGS_PATH")
        autoRefresh: false
    }

    Services.ElsewhenProcessAdapter {
        id: adapter
        service: service
        commandFactory: ({
            probe: function(ids) {
                var command = [test.helperPath, test.failProbe ? "probe-fail" : "probe"]
                for (var i = 0; i < ids.length; i++) command.push(ids[i])
                return command
            },
            catalog: function() { return [test.helperPath, test.failCatalog ? "catalog-fail" : "catalog"] },
            geocode: function(query) {
                var action = query === "springfield" ? "geocode"
                    : query === "boston" ? "geocode-slow"
                    : query === "chicago" ? "geocode-latest" : "geocode-fail"
                return [test.helperPath, action, query]
            },
            timezone: function(zone) { return [test.helperPath, "timezone", zone] },
            profiles: function(handles) { return [test.helperPath, "profiles"].concat(handles) }
        })
    }

    function fail(message) {
        console.error("ELSEWHEN_ADAPTER_FAIL " + message)
        Qt.quit()
    }

    Timer {
        interval: 20
        repeat: true
        running: true
        onTriggered: {
            test.ticks++
            if (test.ticks > 250) {
                test.fail("bounded fixture timeout, phase=" + test.phase)
                return
            }
            if (test.phase === 0 && service.settingsReady && service.staticDataReady) {
                service.active = true
                if (!service.requestCatalog() || !service.refresh()) {
                    test.fail("service did not dispatch catalog and offset requests")
                    return
                }
                test.phase = 1
            } else if (test.phase === 1 && !service.catalogRunning && !service.probeRunning) {
                if (service.zoneCatalogText.indexOf("Europe/Paris") < 0
                        || service.probe["Asia/Tokyo"].offsetMinutes !== 540
                        || service.localZone !== "Etc/UTC") {
                    test.fail("real Process adapter did not return injected catalog/probe data")
                    return
                }
                if (!service.requestTimezoneChange("Europe/Paris")) {
                    test.fail("successful time-zone action was not dispatched")
                    return
                }
                test.phase = 2
            } else if (test.phase === 2 && !service.timezoneRunning) {
                if (service.localZone !== "Europe/Paris" || service.timezoneError !== "") {
                    test.fail("successful helper result was not returned to the service")
                    return
                }
                if (!service.requestTimezoneChange("Invalid/Zone")) {
                    test.fail("failing time-zone action was not dispatched to the inert helper")
                    return
                }
                test.phase = 3
            } else if (test.phase === 3 && !service.timezoneRunning) {
                if (service.localZone !== "Europe/Paris"
                        || service.timezoneError.indexOf("fixture denied requested zone") < 0) {
                    test.fail("failed helper result was not visible or changed the current zone")
                    return
                }
                test.failCatalog = true
                if (!service.requestCatalog()) {
                    test.fail("catalog failure case was not dispatched")
                    return
                }
                test.phase = 4
            } else if (test.phase === 4 && !service.catalogRunning) {
                if (service.catalogError.indexOf("fixture denied catalog") < 0) {
                    test.fail("catalog stderr was not returned to the service")
                    return
                }
                test.failCatalog = false
                test.failProbe = true
                if (!service.refresh()) {
                    test.fail("probe failure case was not dispatched")
                    return
                }
                test.phase = 5
            } else if (test.phase === 5 && !service.probeRunning) {
                if (service.lastError.indexOf("fixture denied probe") < 0) {
                    test.fail("probe stderr was not returned to the service")
                    return
                }
                content.zoneSearchInput.text = "Springfield"
                test.phase = 6
            } else if (test.phase === 6 && service.placeSearchText === "springfield"
                       && !service.placeSearchRunning) {
                if (service.placeSearchError !== "" || service.geocodeOptions.length !== 1
                        || service.geocodeOptions[0].label !== "Springfield"
                        || service.geocodeOptions[0].lat !== 39.78
                        || content.searchResults.length !== 1
                        || content.searchResults[0].lat !== 39.78) {
                    test.fail("inert UI-to-service geocoder result did not reach the selectable panel results")
                    return
                }
                content.zoneSearchInput.text = "Nowhere"
                test.phase = 7
            } else if (test.phase === 7 && service.placeSearchText === "nowhere"
                       && !service.placeSearchRunning) {
                if (service.placeSearchError.indexOf("fixture denied geocode") < 0
                        || service.geocodeOptions.length !== 0) {
                    test.fail("geocoder stderr was not returned to the service")
                    return
                }
                if (!service.requestPlaceSearch("Boston")) {
                    test.fail("slow place-search request was not dispatched")
                    return
                }
                test.phaseTicks = 0
                test.phase = 8
            } else if (test.phase === 8) {
                test.phaseTicks++
                if (test.phaseTicks >= 2) {
                    if (!service.requestPlaceSearch("Chicago")) {
                        test.fail("replacement place-search request was not dispatched")
                        return
                    }
                    test.phaseTicks = 0
                    test.phase = 9
                }
            } else if (test.phase === 9) {
                test.phaseTicks++
                if (test.phaseTicks === 8 && !service.placeSearchRunning) {
                    test.fail("stale process completion cleared the replacement request's busy state")
                    return
                }
                if (test.phaseTicks >= 32) {
                    if (service.placeSearchRunning || service.placeSearchError !== ""
                            || service.geocodeOptions.length !== 1
                            || service.geocodeOptions[0].label !== "Chicago") {
                        test.fail("replacement geocoder result was not the only accepted response: "
                                  + JSON.stringify({ running: service.placeSearchRunning,
                                      error: service.placeSearchError, options: service.geocodeOptions }))
                        return
                    }
                    if (!service.setCities([{ label: "Tokyo", id: "Asia/Tokyo", people: ["@OctoCat"] }])
                            || !service.profilesRunning) {
                        test.fail("profile process was not dispatched for a newly saved GitHub handle")
                        return
                    }
                    test.phase = 10
                }
            } else if (test.phase === 10 && !service.profilesRunning) {
                if (!service.profiles.octocat || service.profiles.octocat.name !== "Octo Cat"
                        || service.profiles.octocat.avatar !== "" || service.profilesError !== "") {
                    test.fail("profile process output did not enrich the cached handle")
                    return
                }
                service.active = false
                console.log("ELSEWHEN_ADAPTER_PASS real Process lifecycle, inert success, failure, replacement and profile results")
                Qt.quit()
            }
        }
    }
}
