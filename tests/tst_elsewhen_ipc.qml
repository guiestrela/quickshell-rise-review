import QtQuick
import Quickshell
import Quickshell.Io
import "../shared/services" as Services

Item {
    id: testRoot
    width: 1
    height: 1
    property int probeRequests: 0

    QtObject {
        id: owner
        property bool elsewhenVisible: false
        property int focusActivations: 0
        function activateFocusedPopupScreen() { focusActivations++ }
    }

    QtObject {
        id: content
        property bool globeExpanded: false
        function toggleGlobeExpanded() {
            globeExpanded = !globeExpanded
            return true
        }
    }

    Services.ElsewhenService {
        id: service
        settingsPath: Quickshell.env("RISE_ELSEWHEN_SETTINGS_PATH")
        autoRefresh: false
    }

    Services.ElsewhenIpcHandler {
        service: service
        owner: owner
        content: content
    }

    FileView {
        id: stateFile
        path: Quickshell.env("RISE_ELSEWHEN_IPC_STATE_PATH")
        atomicWrites: true
        printErrors: false
    }

    function writeState() {
        stateFile.setText(JSON.stringify({
            ready: service.settingsReady && service.staticDataReady,
            visible: owner.elsewhenVisible,
            focusActivations: owner.focusActivations,
            globeExpanded: content.globeExpanded,
            probeRequests: probeRequests,
            localZone: service.localZone,
            cities: service.cities,
            preferences: service.preferenceData
        }))
    }

    Connections {
        target: owner
        function onElsewhenVisibleChanged() { testRoot.writeState() }
    }

    Connections {
        target: content
        function onGlobeExpandedChanged() { testRoot.writeState() }
    }

    Connections {
        target: service
        function onPreferenceDataChanged() { testRoot.writeState() }
        function onProbeRequested(ids, serial) {
            testRoot.probeRequests++
            service.acceptProbe(
                "LOCAL|Etc/UTC\nEtc/UTC|UTC|+0000\nEurope/Paris|CET|+0100\nAsia/Tokyo|JST|+0900\n",
                0, serial, ""
            )
            testRoot.writeState()
        }
        function onProfilesRequested(handles, serial) {
            var rows = []
            for (var i = 0; i < handles.length; i++)
                rows.push(JSON.stringify({ handle: handles[i], login: handles[i], name: "Fixture Person", avatar: "" }))
            service.acceptProfiles(rows.join("\n"), 0, serial, "")
            testRoot.writeState()
        }
    }

    IpcHandler {
        target: "fixture.elsewhen"
        function disableGlobe(): string {
            return service.updateSetting("globeEnabled", false) ? "ok" : service.lastError
        }
        function enableGlobe(): string {
            return service.updateSetting("globeEnabled", true) ? "ok" : service.lastError
        }
        function clearLocalZone(): string {
            service.localZone = ""
            testRoot.writeState()
            return "ok"
        }
    }

    Timer {
        interval: 10
        repeat: true
        running: true
        onTriggered: {
            if (!service.settingsReady || !service.staticDataReady) return
            stop()
            service.probe = ({
                "Europe/Paris": { offsetMinutes: 60, abbr: "CET" },
                "Asia/Tokyo": { offsetMinutes: 540, abbr: "JST" }
            })
            service.localZone = "Etc/UTC"
            service.localOffsetMinutes = 0
            service.nowMs = Date.UTC(2026, 0, 1, 12, 0)
            service.active = true
            testRoot.writeState()
        }
    }

    Component.onCompleted: writeState()
}
