import Quickshell
import QtQuick
import "../shared/services" as Services

ShellRoot {
    id: test
    property int ticks: 0

    Services.ElsewhenService {
        id: service
        settingsPath: Quickshell.env("RISE_ELSEWHEN_SETTINGS_PATH")
        autoRefresh: false
    }

    Timer {
        interval: 25
        repeat: true
        running: true
        onTriggered: {
            test.ticks++
            if (test.ticks > 400) {
                console.error("ELSEWHEN_REOPEN_FAIL bounded fixture timeout")
                Qt.quit()
                return
            }
            if (!service.settingsReady || !service.staticDataReady) return
            var cities = service.cities
            if (service.preferenceData.hour24 !== true || service.preferenceData.globeEnabled !== true
                    || service.preferenceData.schemaVersion !== 1 || cities.length !== 1
                    || cities[0].id !== "Europe/Paris" || cities[0].lat !== 48.8566
                    || cities[0].lon !== 2.3522) {
                console.error("ELSEWHEN_REOPEN_FAIL settings did not survive service reopen: "
                              + JSON.stringify({ prefs: service.preferenceData, cities: cities }))
                Qt.quit()
                return
            }
            console.log("ELSEWHEN_REOPEN_PASS settings loaded after a fresh service instance")
            Qt.quit()
        }
    }
}
