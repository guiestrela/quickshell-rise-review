import QtQuick
import Quickshell.Io
import "../integrations/elsewhen/Model.js" as Model

Item {
    id: adapter
    visible: false
    width: 0
    height: 0

    required property var service
    required property var owner
    required property var content

    function focusOwnerScreen() {
        if (owner && typeof owner.activateFocusedPopupScreen === "function")
            owner.activateFocusedPopupScreen()
    }

    function openPanel() {
        if (!owner) return
        focusOwnerScreen()
        owner.elsewhenVisible = true
    }

    function closePanel() {
        if (owner) owner.elsewhenVisible = false
    }

    function togglePanel() {
        if (!owner) return
        var opening = !owner.elsewhenVisible
        if (opening) focusOwnerScreen()
        owner.elsewhenVisible = opening
    }

    function addCity(zone, label) {
        service.addCity(zone, label)
        return Model.serializeZones(service.cities)
    }

    function removeCity(zone) {
        var next = Model.removeZone(service.cities || [], String(zone || ""))
        if (next !== service.cities) service.setCities(next)
        return Model.serializeZones(service.cities)
    }

    function setPeople(city, people) {
        var wanted = String(city || "").trim().toLowerCase()
        var cities = service.cities || []
        for (var i = 0; i < cities.length; i++) {
            if (String(cities[i].label || "").trim().toLowerCase() !== wanted) continue
            var next = Model.setPeopleAt(cities, i, Model.parsePeople(people))
            if (next !== cities && !service.setCities(next)) return service.lastError
            return JSON.stringify((service.cities[i] || {}).people || [])
        }
        return "no city named " + city
    }

    function setHere(city) {
        var localZone = String(service.localZone || "")
        if (localZone === "") return "zone not known yet"
        var current = Model.resolveHere(
            service.preferenceData.here,
            service.preferenceData.homeCity || "",
            localZone
        )
        var next = Model.hereAfterPick(
            service.cities,
            current,
            { label: String(city || ""), id: localZone },
            localZone
        )
        if (!next) return "invalid city name"
        if (!service.setHere(next.here, next.zones)) return service.lastError
        var result = Model.resolveHere(
            service.preferenceData.here,
            service.preferenceData.homeCity || "",
            localZone
        )
        return result ? result.label : ""
    }

    IpcHandler {
        target: "quickshell-rise.elsewhen"

        // `show` is reserved by `qs ipc show`; `open` is its callable equivalent.
        function open(): void { adapter.openPanel() }
        function close(): void { adapter.closePanel() }
        function hide(): void { adapter.closePanel() }
        function toggle(): void { adapter.togglePanel() }
        function refresh(): string { adapter.service.refresh(); return "ok" }

        function globe(): string {
            if (!adapter.service.preferenceData || adapter.service.preferenceData.globeEnabled === false)
                return "disabled"
            if (!adapter.content || typeof adapter.content.toggleGlobeExpanded !== "function")
                return "unavailable"
            adapter.content.toggleGlobeExpanded()
            return adapter.content.globeExpanded ? "globe" : "list"
        }

        function times(): string {
            adapter.service.nowMs = Date.now()
            adapter.service.localOffsetMinutes = -(new Date().getTimezoneOffset())
            return JSON.stringify(adapter.service.clockRows)
        }

        function add(zone: string, label: string): string { return adapter.addCity(zone, label) }
        function remove(zone: string): string { return adapter.removeCity(zone) }
        function who(city: string, people: string): string { return adapter.setPeople(city, people) }
        function here(city: string): string { return adapter.setHere(city) }
    }
}
