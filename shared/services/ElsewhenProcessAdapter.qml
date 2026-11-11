import QtQuick
import Quickshell.Io
import "../integrations/elsewhen/Model.js" as Model

Item {
    id: adapter
    visible: false
    width: 0
    height: 0

    required property var service
    property var commandFactory: ({
        probe: function(ids) { return Model.probeCommand(ids, true) },
        catalog: function() { return ["timedatectl", "list-timezones"] },
        geocode: function(query) { return Model.geocodeCommand(query) },
        timezone: function(zone) { return Model.timezoneCommand(zone) }
    })
    property bool geocodeBusy: false
    property var pendingGeocode: null

    function stopAll() {
        pendingGeocode = null
        if (probeProcess.running) probeProcess.running = false
        if (catalogProcess.running) catalogProcess.running = false
        if (geocodeProcess.running) geocodeProcess.running = false
        if (timezoneProcess.running) timezoneProcess.running = false
    }

    function startProbe(ids, serial) {
        if (probeProcess.running) {
            service.acceptProbe("", 1, serial, "A time-zone probe is already running")
            return
        }
        try {
            probeProcess.requestSerial = serial
            probeProcess.command = commandFactory.probe(ids)
            probeProcess.running = true
        } catch (error) {
            service.acceptProbe("", 1, serial, String(error))
        }
    }

    function startCatalog(serial) {
        if (catalogProcess.running) {
            service.acceptZoneCatalog("", 1, serial, "A time-zone catalog query is already running")
            return
        }
        try {
            catalogProcess.requestSerial = serial
            catalogProcess.command = commandFactory.catalog()
            catalogProcess.running = true
        } catch (error) {
            service.acceptZoneCatalog("", 1, serial, String(error))
        }
    }

    function launchGeocode(query, serial) {
        try {
            geocodeProcess.requestSerial = serial
            geocodeProcess.command = commandFactory.geocode(query)
            geocodeBusy = true
            geocodeProcess.running = true
        } catch (error) {
            geocodeBusy = false
            service.acceptPlaceSearch("", 1, serial, String(error))
        }
    }

    function startGeocode(query, serial) {
        if (geocodeBusy) {
            pendingGeocode = ({ query: query, serial: serial })
            if (geocodeProcess.running) geocodeProcess.running = false
            return
        }
        launchGeocode(query, serial)
    }

    function startTimezoneChange(zone, serial) {
        if (timezoneProcess.running) {
            service.acceptTimezoneChange(1, serial, "A time-zone change is already running")
            return
        }
        try {
            timezoneProcess.requestSerial = serial
            timezoneProcess.command = commandFactory.timezone(zone)
            timezoneProcess.running = true
        } catch (error) {
            service.acceptTimezoneChange(1, serial, String(error))
        }
    }

    Connections {
        target: adapter.service
        function onProbeRequested(ids, serial) { adapter.startProbe(ids, serial) }
        function onCatalogRequested(serial) { adapter.startCatalog(serial) }
        function onPlaceSearchRequested(query, serial) { adapter.startGeocode(query, serial) }
        function onTimezoneChangeRequested(zone, serial) { adapter.startTimezoneChange(zone, serial) }
        function onCancelRequested() { adapter.stopAll() }
    }

    Process {
        id: probeProcess
        property int requestSerial: 0
        command: []
        stdout: StdioCollector { id: probeOutput; waitForEnd: true }
        stderr: StdioCollector { id: probeError; waitForEnd: true }
        onExited: function(exitCode) {
            adapter.service.acceptProbe(probeOutput.text, exitCode, requestSerial, probeError.text)
        }
    }

    Process {
        id: catalogProcess
        property int requestSerial: 0
        command: []
        stdout: StdioCollector { id: catalogOutput; waitForEnd: true }
        stderr: StdioCollector { id: catalogError; waitForEnd: true }
        onExited: function(exitCode) {
            adapter.service.acceptZoneCatalog(catalogOutput.text, exitCode, requestSerial, catalogError.text)
        }
    }

    Process {
        id: geocodeProcess
        property int requestSerial: 0
        command: []
        stdout: StdioCollector { id: geocodeOutput; waitForEnd: true }
        stderr: StdioCollector { id: geocodeError; waitForEnd: true }
        onExited: function(exitCode) {
            var completedSerial = requestSerial
            var output = geocodeOutput.text
            var error = geocodeError.text
            adapter.geocodeBusy = false
            adapter.service.acceptPlaceSearch(output, exitCode, completedSerial, error)
            if (adapter.pendingGeocode !== null) {
                const next = adapter.pendingGeocode
                adapter.pendingGeocode = null
                adapter.launchGeocode(next.query, next.serial)
            }
        }
    }

    Process {
        id: timezoneProcess
        property int requestSerial: 0
        command: []
        stdout: StdioCollector { id: timezoneOutput; waitForEnd: true }
        stderr: StdioCollector { id: timezoneError; waitForEnd: true }
        onExited: function(exitCode) {
            adapter.service.acceptTimezoneChange(exitCode, requestSerial, timezoneError.text)
        }
    }

    Component.onDestruction: stopAll()
}
