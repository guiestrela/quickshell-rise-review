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
    property string lastTimezoneZone: ""
    property int lastTimezoneSerial: 0
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
                service.active = true
                if (!service.requestTimezoneChange("Europe/Paris") || test.timezoneCount !== 1
                        || test.lastTimezoneZone !== "Europe/Paris") {
                    test.fail("explicit time-zone request was not dispatched to the command boundary")
                    return
                }
                var failedTimezoneSerial = test.lastTimezoneSerial
                if (service.acceptTimezoneChange(1, failedTimezoneSerial, "inert helper denied action")
                        || service.timezoneError.indexOf("inert helper denied action") < 0
                        || service.localZone !== "Etc/UTC") {
                    test.fail("time-zone command failure was not visible or changed local state")
                    return
                }
                if (!service.requestTimezoneChange("Europe/Paris") || test.timezoneCount !== 2) {
                    test.fail("time-zone request did not recover after a failed attempt")
                    return
                }
                if (!service.acceptTimezoneChange(0, test.lastTimezoneSerial, "")
                        || service.localZone !== "Europe/Paris" || service.timezoneError !== "") {
                    test.fail("successful time-zone command result was not applied")
                    return
                }
                service.active = false
                console.log("ELSEWHEN_SERVICE_PASS lifecycle, settings, cities, probes and time-zone results")
                Qt.quit()
            }
        }
    }
}
