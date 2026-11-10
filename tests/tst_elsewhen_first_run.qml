import QtQuick
import Quickshell
import Quickshell.Io
import "../shared/services" as Services

ShellRoot {
    id: test
    property int stage: 0
    property int ticks: 0
    property bool requested: false
    property string failure: ""

    Services.ElsewhenService {
        id: service
        settingsPath: Quickshell.env("RISE_ELSEWHEN_SETTINGS_PATH")
        autoRefresh: true
        active: true
        onProbeRequested: function(ids, serial) { test.requested = true }
    }

    Timer {
        interval: 25
        repeat: true
        running: true
        onTriggered: {
            test.ticks++
            if (test.ticks > 240) {
                test.failure = "timeout waiting for settings lifecycle; ready=" + service.settingsReady
                    + " error=" + service.lastError
            } else if (test.stage === 0 && service.settingsReady) {
                if (!test.requested) {
                    test.failure = "first-run settings became ready without starting the initial probe"
                } else if (service.preferenceData.schemaVersion !== 1 || !Array.isArray(service.cities)) {
                    test.failure = "first-run defaults were not initialized"
                } else if (!service.addCity("America/New_York", "New York", { lat: 40.7128, lon: -74.006 })) {
                    test.failure = "first-run mutation was rejected; ready=" + service.settingsReady
                        + " path=" + service.settingsPath + " error=" + service.lastError
                        + " cityCount=" + service.cities.length
                } else {
                    test.stage = 1
                    test.ticks = 0
                }
            } else if (test.stage === 1 && test.ticks > 12) {
                console.log("ELSEWHEN_FIRST_RUN_PASS missing-file load, initial probe and mutation")
                Qt.quit()
            }
            if (test.failure !== "") {
                console.error("ELSEWHEN_FIRST_RUN_FAIL " + test.failure)
                Qt.quit()
            }
        }
    }
}
