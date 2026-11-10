import QtQuick
import Quickshell
import "../shared/services" as Services

ShellRoot {
    id: test
    property int ticks: 0
    property string failure: ""
    readonly property bool invalidCase: Quickshell.env("RISE_EXPECT_INVALID") === "1"
    readonly property bool missingParentCase: Quickshell.env("RISE_EXPECT_MISSING_PARENT") === "1"
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
            if (test.invalidCase && service.settingsReady) {
                if (!service.lastError.startsWith("Invalid Elsewhen settings"))
                    test.failure = "invalid settings did not remain visible: " + service.lastError
                else {
                    console.log("ELSEWHEN_INVALID_JSON_PASS invalid data retained until explicit user mutation")
                    Qt.quit()
                }
            } else if (test.missingParentCase && service.settingsReady) {
                if (service.lastError !== "")
                    test.failure = "missing-parent recovery reported an error: " + service.lastError
                else {
                    console.log("ELSEWHEN_MISSING_PARENT_PASS FileView created the cache directory and saved defaults")
                    Qt.quit()
                }
            } else if (!test.invalidCase && !test.missingParentCase
                    && !service.settingsReady && service.lastError !== "") {
                console.log("ELSEWHEN_WRITE_FAILURE_PASS write error surfaced without marking settings ready")
                Qt.quit()
            } else if (test.ticks > 120) {
                test.failure = "timeout waiting for settings error; ready=" + service.settingsReady
                    + " error=" + service.lastError
            }
            if (test.failure !== "") {
                console.error("ELSEWHEN_SETTINGS_ERROR_FAIL " + test.failure)
                Qt.quit()
            }
        }
    }
}
