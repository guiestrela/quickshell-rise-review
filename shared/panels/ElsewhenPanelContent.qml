pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../components" as SharedComponents
import "../integrations/elsewhen" as Elsewhen
import "../integrations/elsewhen/GlobeModel.js" as Globe
import "../integrations/elsewhen/Model.js" as Model

Item {
    id: panel
    objectName: "elsewhen-panel-content"
    required property var root
    required property var service
    property real scrubMinutes: 0
    property bool moonShowing: false
    property real moonDemo: -1
    property int moonShowStep: 0
    readonly property var moonShowStops: [0, 0.12, 0.25, 0.38, 0.5, 0.62, 0.75, 0.88, 1]
    readonly property real moonPhase: moonShowing && moonDemo >= 0 ? moonDemo : Globe.moonPhase(effectiveMs)
    property string searchText: ""
    property string searchMode: ""
    property int searchSelectionIndex: 0
    onSearchTextChanged: searchSelectionIndex = 0
    property string statusMessage: ""
    property real globeSpin: 0
    property real globeViewLat: 0
    property real heroSpin: 0
    property bool globeExpanded: false
    property int globeZoomDuration: 280
    property int globeZoomEasing: Easing.OutCubic
    property bool openingSpinPending: false
    property var globeSessionCities: []
    property string globeSelectionKey: ""
    property string globeSelectionLabel: ""
    property string globeSelectionZone: ""
    property real globeDragX: 0
    property real globeDragY: 0
    readonly property var contentRoot: panel
    property bool timezoneConfirmationVisible: false
    property var notificationSink: null
    property var notificationFormatter: null
    readonly property bool panelIsOpen: root.elsewhenVisible !== undefined ? root.elsewhenVisible : true
    onPanelIsOpenChanged: {
        if (!panelIsOpen) {
            openingSpinPending = false
            openingSpinFallback.stop()
            globeExpanded = false
            searchMode = ""
            searchText = ""
            zoneSearchInput.clear()
        } else {
            keyboardFocusId = ""
            keyboardFocusKey = ""
            startOpeningSpin()
        }
    }
    function notifyTimezoneChange(succeeded, zone) {
        var location = hereZone ? hereZone.label : zone
        var message = typeof notificationFormatter === "function"
            ? notificationFormatter(succeeded, location, zone)
            : succeeded ? "Now in " + location + ", and the clock is on " + zone
                         : "Couldn't move the clock to " + zone
        if (typeof notificationSink === "function") notificationSink(message)
        else if (root && typeof root.notify === "function") root.notify(message)
    }
    property int peopleEditIndex: -1
    property int draggingCityIndex: -1
    property int rowDragTargetIndex: -1
    property real rowDragPitch: 104
    readonly property var profiles: service.profiles || ({})
    readonly property double profileStamp: Number(service.profileStamp || 0)
    property string temperatureLabel: ""
    property string timezoneTarget: service.clockRows.length ? service.clockRows[0].id : service.localZone
    property string keyboardFocusId: ""
    property string keyboardFocusKey: ""
    onKeyboardFocusIdChanged: keyboardFocusKey = ""
    readonly property double effectiveMs: (service.nowMs !== undefined ? service.nowMs : Date.now()) + scrubMinutes * 60000
    readonly property bool hour24: service.preferenceData ? service.preferenceData.hour24 === true : false
    readonly property var hereZone: Model.resolveHere(service.preferenceData ? service.preferenceData.here : null,
        service.preferenceData ? service.preferenceData.homeCity : "", service.localZone)
    readonly property string hereLine: {
        var offset = service.localOffsetMinutes !== undefined
            ? service.localOffsetMinutes : -(new Date().getTimezoneOffset())
        var parts = Model.zoneParts(effectiveMs, offset)
        var localTime = Model.formatTime(parts, hour24)
            + (hour24 ? "" : " " + Model.meridiem(parts))
        var line = hereZone && hereZone.chosen
            ? "It's " + localTime + " here in " + hereZone.label
            : "It's " + localTime + " here"
        var shift = Model.formatScrubDelta(scrubMinutes)
        return line + (shift !== "" ? "  " + shift : "")
    }
    readonly property var heroRestPlace: {
        var cities = service.cities || []
        if (keyboardFocusKey !== "") {
            for (var i = 0; i < cities.length; i++)
                if (Model.factsKey(cities[i]) === keyboardFocusKey) return placeForCity(cities[i])
        }
        if (!hereZone) return null
        return placeForCity({ label: hereZone.label, id: hereZone.id, lat: hereZone.lat, lon: hereZone.lon })
    }
    readonly property real heroRestLon: heroRestPlace ? Number(heroRestPlace.lon) : 0
    readonly property var displayRows: {
        var zones = service.cities || []
        var probeData = service.probe || ({})
        if (Object.keys(probeData).length === 0) return service.clockRows || []
        var offset = service.localOffsetMinutes !== undefined ? service.localOffsetMinutes : 0
        var use24 = service.preferenceData && service.preferenceData.hour24 === true
        return Model.rows(zones, probeData, effectiveMs, offset, use24)
    }
    readonly property var globeFooterPlace: {
        var places = globePlaces()
        for (var i = 0; i < places.length; i++)
            if (places[i].key === globeSelectionKey) return places[i]
        return null
    }
    readonly property var globeFooterRow: {
        var place = globeFooterPlace
        if (!place) return null
        var offset = service.localOffsetMinutes !== undefined ? service.localOffsetMinutes : 0
        return Model.rows([{ label: place.label, id: place.id }], service.probe || ({}), effectiveMs, offset, hour24)[0]
    }
    readonly property string globeFooterClock: globeFooterRow && globeFooterRow.ready
        ? globeFooterRow.time + (globeFooterRow.meridiem ? " " + globeFooterRow.meridiem : "") : ""
    readonly property string globeFooterBadge: {
        var place = globeFooterPlace
        if (!place) return ""
        if (place.id === service.localZone && hereZone && place.label === hereZone.label) return "home"
        return place.tracked ? "tracked" : ""
    }
    readonly property bool globeFooterDaylight: globeFooterPlace
        ? Globe.isDaylight(globeFooterPlace.lat, globeFooterPlace.lon, Globe.subsolarPoint(effectiveMs)) : false
    readonly property real globeFooterMoonPhase: moonPhase
    readonly property var searchResults: typeof service.searchLocations === "function"
        ? service.searchLocations(searchText, 8) : service.searchZones(searchText, 8)
    onSearchResultsChanged: {
        if (searchSelectionIndex >= searchResults.length)
            searchSelectionIndex = Math.max(0, searchResults.length - 1)
    }
    readonly property real contentHeight: contentColumn.implicitHeight
    property alias refreshButton: refreshAction
    property alias hour24Button: hour24Action
    property alias zoneSearchInput: zoneSearchInput
    property alias cityList: cityList
    property alias searchList: searchList
    property alias addZoneButton: addZoneAction
    property alias scrollArea: flick
    property alias globeCanvas: globeCanvasItem
    property alias globeToggleButton: globeToggleAction
    property alias globeZoomButton: globeZoomAction
    property alias globeDragArea: globeDragArea
    property alias changeTimezoneButton: changeTimezoneAction
    property alias confirmTimezoneButton: confirmTimezoneAction
    onGlobeSpinChanged: globeCanvasItem.requestPaint()
    onGlobeViewLatChanged: globeCanvasItem.requestPaint()
    onGlobeExpandedChanged: globeCanvasItem.requestPaint()
    onGlobeSessionCitiesChanged: globeCanvasItem.requestPaint()
    focus: true
    Keys.priority: Keys.AfterItem
    Keys.onPressed: function(event) {
        if ((event.modifiers & (Qt.ControlModifier | Qt.MetaModifier))
                || ((event.modifiers & Qt.AltModifier) && event.key !== Qt.Key_T)) return
        if (event.key === Qt.Key_Escape) {
            handleEscape()
        } else if (zoneSearchInput.activeFocus || peopleEditIndex >= 0) {
            return
        } else if (event.key === Qt.Key_Space) {
            toggleGlobeExpanded()
        } else if (globeExpanded && (event.text === "+" || event.text === "j"
                    || event.key === Qt.Key_Plus
                    || (event.key === Qt.Key_Equal && (event.modifiers & Qt.ShiftModifier)))) {
            startJumpSearch()
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down
                || event.text === "k" || event.text === "j") {
            var moveUp = event.key === Qt.Key_Up || event.text === "k"
            moveKeyboardFocus(moveUp ? -1 : 1)
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                || event.text === "h" || event.text === "l") {
            var shiftEarlier = event.key === Qt.Key_Left || event.text === "h"
            shiftHour(shiftEarlier ? -1 : 1)
        } else if (event.key === Qt.Key_Delete || event.text === "x" || event.text === "X") {
            deleteFocusedCity()
        } else if (event.key === Qt.Key_R) {
            if (!service.refresh()) statusMessage = service.lastError
        } else if (event.key === Qt.Key_T) {
            if (event.modifiers & Qt.AltModifier) toggleUnits()
            else toggleHour24()
        } else if (event.key === Qt.Key_A || event.key === Qt.Key_Plus
                || (event.key === Qt.Key_Equal && (event.modifiers & Qt.ShiftModifier))) {
            startAddSearch()
        } else if (event.text.toLowerCase() === "w" && !globeExpanded) {
            startHereSearch()
        } else if (event.key === Qt.Key_P) {
            var targetIndex = cityIndexForFocus()
            if (targetIndex < 0) return
            startPeopleEdit(targetIndex)
        } else {
            return
        }
        event.accepted = true
    }

    function temperatureFor(rowData) {
        if (!rowData) return ""
        var point = placeForCity(rowData)
        if (!point) return ""
        var key = Model.factsKey({ label: rowData.label, id: rowData.id })
        var observation = (service.weather || ({}))[key]
        if (observation) return Model.tempLabel(observation, preferenceUnits())
        return ""
    }

    function preferenceUnits() {
        var locale = Qt.locale()
        var automatic = locale.measurementSystem === Locale.ImperialUSSystem ? "F" : "C"
        return Model.resolveUnits(service.preferenceData ? service.preferenceData.units : "", automatic)
    }

    function requestCityWeather() {
        if (!service.active || service.weatherRunning) return
        var keys = [], points = [], now = Date.now()
        var cities = service.cities || []
        for (var i = 0; i < cities.length; i++) {
            var row = cities[i], point = placeForCity(row)
            if (!point) continue
            var key = Model.factsKey(row)
            if (!Model.weatherStale(service.weather[key], now, point)) continue
            keys.push(key); points.push(point)
        }
        if (keys.length) service.requestWeather(keys, points)
    }

    function toggleUnits() {
        if (!service.updateSetting("units", preferenceUnits() === "C" ? "F" : "C")) statusMessage = service.lastError
    }

    function toggleHour24() {
        if (!service.updateSetting("hour24", !hour24)) statusMessage = service.lastError
    }

    function cityIndexForZone(zoneId) {
        var cities = service.cities || []
        for (var i = 0; i < cities.length; i++) {
            if (String(cities[i].id || "") === String(zoneId || "")) return i
        }
        return -1
    }

    function cityIndexForFocus() {
        var cities = service.cities || []
        if (keyboardFocusKey !== "") {
            for (var i = 0; i < cities.length; i++)
                if (Model.factsKey(cities[i]) === keyboardFocusKey) return i
        }
        return cityIndexForZone(keyboardFocusId || timezoneTarget)
    }

    function moveKeyboardFocus(step) {
        var cities = service.cities || []
        if (cities.length === 0) return
        var current = cityIndexForFocus()
        if (current < 0) current = step > 0 ? -1 : 0
        var next = (current + step + cities.length) % cities.length
        focusCity(next)
    }

    function focusCity(index) {
        var cities = service.cities || []
        if (index < 0 || index >= cities.length) return false
        var zoneId = String(cities[index].id || "")
        if (!zoneId) return false
        var heroFrom = Number(heroSpin)
        if (!isFinite(heroFrom)) heroFrom = 0
        keyboardFocusId = zoneId
        keyboardFocusKey = Model.factsKey(cities[index])
        timezoneTarget = zoneId
        var city = cities[index]
        var place = placeForCity(city)
        if (place) turnHeroToFocus(place, heroFrom)
        globeSelectionKey = globeCityIdentity(city)
        globeSelectionLabel = String(city.label || city.id)
        globeSelectionZone = zoneId
        faceGlobe(place)
        if (typeof service.ensureProbeZone === "function") service.ensureProbeZone(zoneId)
        var row = cityList.itemAtIndex(index)
        if (row) {
            var top = row.mapToItem(flick.contentItem, 0, 0).y
            if (top < flick.contentY) flick.contentY = top
            else if (top + row.height > flick.contentY + flick.height)
                flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, top + row.height - flick.height))
        }
        return true
    }

    function startAddSearch() {
        searchMode = "add"
        searchText = ""
        zoneSearchInput.clear()
        zoneSearchInput.forceActiveFocus()
        return true
    }

    function handleHereCaptionClick() {
        if (keyboardFocusKey !== "" || keyboardFocusId !== "") {
            if (!hereZone) return false
            var home = { label: hereZone.label, id: hereZone.id,
                lat: hereZone.lat, lon: hereZone.lon }
            var place = placeForCity(home)
            if (!place || !isFinite(Number(place.lat)) || !isFinite(Number(place.lon))) return false
            var heroFrom = Number(heroSpin)
            if (!isFinite(heroFrom)) heroFrom = 0
            keyboardFocusId = ""
            keyboardFocusKey = ""
            timezoneTarget = home.id
            globeSelectionKey = globeCityIdentity(home)
            globeSelectionLabel = home.label
            globeSelectionZone = home.id
            if (typeof service.ensureProbeZone === "function") service.ensureProbeZone(home.id)
            turnHeroToFocus(place, heroFrom)
            faceGlobe(place)
            return true
        }
        return startHereSearch()
    }

    function startHereSearch() {
        if (globeExpanded || !service.localZone) return false
        searchMode = searchMode === "here" ? "" : "here"
        searchText = ""
        zoneSearchInput.clear()
        if (searchMode === "here") zoneSearchInput.forceActiveFocus()
        else panel.forceActiveFocus()
        return true
    }

    function startJumpSearch() {
        if (!globeExpanded) return false
        searchMode = "jump"
        searchText = ""
        zoneSearchInput.clear()
        zoneSearchInput.forceActiveFocus()
        return true
    }

    function faceGlobe(place) {
        if (!place) return false
        var lat = Number(place.lat), lon = Number(place.lon)
        if (isFinite(lon)) {
            globeFocusAnimation.stop()
            globeFocusAnimation.from = globeSpin
            globeFocusAnimation.to = globeSpin + Globe.shortestTurn(globeSpin, lon)
            globeFocusAnimation.restart()
        }
        if (isFinite(lat)) {
            globeViewAnimation.stop()
            globeViewAnimation.from = globeViewLat
            globeViewAnimation.to = Math.max(-70, Math.min(70, lat))
            globeViewAnimation.restart()
        }
        return isFinite(lat) || isFinite(lon)
    }

    function toggleGlobeExpanded(slow) {
        if (!service.preferenceData || service.preferenceData.globeEnabled === false) return false
        var opening = !globeExpanded
        globeZoomDuration = service.preferenceData.smoothMotion === false ? 0
            : (opening ? 800 : 500) * (slow === true ? 3 : 1)
        globeZoomEasing = opening ? Easing.OutQuart : Easing.InOutCubic
        globeExpanded = opening
        if (globeExpanded) {
            searchMode = ""
            searchText = ""
            zoneSearchInput.clear()
            var index = keyboardFocusKey !== "" ? cityIndexForFocus() : -1
            var city = index >= 0 ? (service.cities || [])[index] : null
            var home = hereZone ? { label: hereZone.label, id: service.localZone,
                lat: hereZone.lat, lon: hereZone.lon } : null
            if (!city && home) {
                globeSelectionKey = globeCityIdentity(home)
                globeSelectionLabel = home.label
                globeSelectionZone = home.id
                timezoneTarget = home.id
                if (typeof service.ensureProbeZone === "function") service.ensureProbeZone(home.id)
            }
            var place = city ? placeForCity(city) : (home ? placeForCity(home) : null)
            faceGlobe(place)
        }
        return true
    }

    function globeCityIdentity(city) {
        var name = String(city.label || city.id || "").trim().toLowerCase()
        try {
            if (typeof name.normalize === "function")
                name = name.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
        } catch (error) {}
        return name + "|" + String(city.id || "")
    }

    function globePlaces() {
        var result = [], seen = Object.create(null), cities = service.cities || []
        function append(city, rank, tracked, trackedIndex, home) {
            if (!city || !city.id) return
            var key = globeCityIdentity(city)
            var existingIndex = seen[key]
            if (existingIndex !== undefined) {
                var existing = result[existingIndex]
                if (home) existing.home = true
                if (tracked) {
                    existing.tracked = true
                    existing.trackedIndex = trackedIndex
                    existing.rank = Math.min(existing.rank, Number(rank) || 0)
                }
                return
            }
            var point = placeForCity(city)
            if (!point || !isFinite(point.lat) || !isFinite(point.lon)) return
            seen[key] = result.length
            result.push({ label: String(city.label || city.id), id: String(city.id),
                lat: point.lat, lon: point.lon, rank: Number(rank) || 0,
                key: key, tracked: tracked, trackedIndex: trackedIndex, home: home === true })
        }
        var home = hereZone ? { label: hereZone.label, id: service.localZone,
            lat: hereZone.lat, lon: hereZone.lon } : null
        append(home, 0, false, -1, true)
        for (var i = 0; i < cities.length; i++) append(cities[i], 0, true, i)
        var catalog = service.cityData || []
        for (var j = 0; j < catalog.length; j++) {
            var item = catalog[j]
            append({ label: String(item[0]), id: String(item[1]), lat: Number(item[2]), lon: Number(item[3]) },
                item[4], false, -1)
        }
        var session = globeSessionCities || []
        for (var k = 0; k < session.length; k++) append(session[k], -1, false, -1)
        return result
    }

    function globeScene(radius) {
        var places = globePlaces(), candidates = []
        for (var i = 0; i < places.length; i++) {
            var place = places[i]
            var point = Globe.project(place.lat, place.lon, globeSpin, globeViewLat, radius)
            if (!point.visible) continue
            candidates.push({ index: i, x: point.x, y: point.y, cosc: point.cosc,
                rank: place.rank, keep: place.home || place.tracked || place.key === globeSelectionKey })
        }
        candidates.sort(function(a, b) {
            if (a.keep !== b.keep) return a.keep ? -1 : 1
            if (a.rank !== b.rank) return a.rank - b.rank
            return b.cosc - a.cosc
        })
        var plotted = Globe.declutter(candidates, Math.max(9, radius * 0.18))
        var labelCandidates = []
        for (var j = 0; j < plotted.length; j++) {
            var marker = plotted[j]
            if (marker.cosc < 0.12) continue
            labelCandidates.push({ index: marker.index, name: places[marker.index].label,
                x: marker.x, y: marker.y, rank: marker.keep ? -1 : marker.rank, cosc: marker.cosc })
        }
        var labels = Globe.layoutLabels(labelCandidates, 5.5, 12, 8, radius - 3, 5)
        return { places: places, plotted: plotted, labels: labels }
    }

    function tapGlobeAt(x, y) {
        var point = globeCanvasItem.mapFromItem(globeDragArea, x, y)
        var cx = globeCanvasItem.width / 2, cy = globeCanvasItem.height / 2
        var radius = globePaintRadius(globeCanvasItem.width, globeCanvasItem.height)
        var scene = globeScene(radius)
        var px = point.x - cx, py = point.y - cy
        var hit = -1
        for (var i = 0; i < scene.labels.length; i++) {
            var box = scene.labels[i].box
            if (px >= box.x - 3 && px <= box.x + box.w + 3
                    && py >= box.y - 3 && py <= box.y + box.h + 3) {
                hit = scene.labels[i].index
                break
            }
        }
        if (hit < 0) {
            var bestDistance = 144
            for (var j = 0; j < scene.plotted.length; j++) {
                var marker = scene.plotted[j]
                var dx = px - marker.x, dy = py - marker.y
                var distance = dx * dx + dy * dy
                if (distance <= bestDistance) { hit = marker.index; bestDistance = distance }
            }
        }
        if (hit < 0) return false

        var city = scene.places[hit]
        globeSelectionKey = city.key
        globeSelectionLabel = city.label
        globeSelectionZone = city.id
        timezoneTarget = city.id
        if (typeof service.ensureProbeZone === "function") service.ensureProbeZone(city.id)
        if (city.tracked) focusCity(city.trackedIndex)
        else faceGlobe(city)

        var homeOverride = hereZone && hereZone.chosen ? hereZone.label : ""
        var nextHome = Model.homeCityAfterTap(city.label, city.id, homeOverride, service.localZone)
        if (nextHome !== null) {
            var nextHere = nextHome === "" ? null : { name: nextHome, zone: city.id,
                lat: city.lat, lon: city.lon }
            if (!service.setHere(nextHere, service.cities)) statusMessage = service.lastError
        }
        return true
    }

    function shiftHour(step) {
        scrubHold.stop()
        scrubMinutes = Math.round(scrubMinutes) + step * 60
    }

    function deleteFocusedCity() {
        var cities = service.cities || []
        var index = cityIndexForFocus()
        if (index < 0 || cities.length < 2 || !removeCityAt(index)) return false
        return focusCity(Math.min(index, (service.cities || []).length - 1))
    }

    function handleEscape() {
        if (timezoneConfirmationVisible) timezoneConfirmationVisible = false
        else if (zoneSearchInput.activeFocus && zoneSearchInput.text.length > 0) zoneSearchInput.clear()
        else if (searchMode !== "" || zoneSearchInput.activeFocus) {
            searchMode = ""
            searchText = ""
            zoneSearchInput.clear()
            panel.forceActiveFocus()
        }
        else if (scrubMinutes !== 0) {
            scrubHold.stop()
            scrubMinutes = 0
        } else if (globeExpanded) globeExpanded = false
        else root.elsewhenVisible = false
    }

    function scrubTo(rowData, fraction) {
        if (!rowData || rowData.ready !== true) return
        var now = service.nowMs !== undefined ? service.nowMs : Date.now()
        var parts = Model.zoneParts(now, rowData.offsetMinutes)
        scrubMinutes = Model.scrubDeltaMinutes(fraction, parts.hour * 60 + parts.minute)
    }

    function beginScrub(rowData, fraction) {
        scrubHold.stop()
        scrubTo(rowData, fraction)
    }

    function endScrub() {
        if (scrubMinutes !== 0) scrubHold.restart()
    }

    function startMoonShow() {
        moonShowStep = 0
        moonShowing = true
        moonDemo = moonShowStops[0]
        moonShowTimer.restart()
    }

    function stopMoonShow() {
        moonShowTimer.stop()
        moonShowing = false
        moonDemo = -1
    }

    function startPeopleEdit(index) {
        if (!service.cities || index < 0 || index >= service.cities.length) return
        peopleEditIndex = index
        statusMessage = ""
    }

    function finishPeopleEdit(index, text) {
        if (peopleEditIndex !== index || !service.cities || index < 0 || index >= service.cities.length) return
        var nextCities = Model.setPeopleAt(service.cities, index, Model.parsePeople(text))
        peopleEditIndex = -1
        if (nextCities !== service.cities && !service.setCities(nextCities)) statusMessage = service.lastError
    }

    function cancelPeopleEdit() {
        peopleEditIndex = -1
    }

    function removeCityAt(index) {
        if (!service.removeCity(index)) {
            statusMessage = service.lastError
            return false
        }
        if (peopleEditIndex === index) peopleEditIndex = -1
        else if (peopleEditIndex > index) peopleEditIndex--
        return true
    }

    function offsetTextFor(rowData) {
        if (!rowData || rowData.ready !== true) return ""
        return service.preferenceData && service.preferenceData.offsetMode === "utc"
            ? Model.utcOffsetLabel(rowData.offsetMinutes) : (rowData.relative || "")
    }

    function toggleOffsetMode() {
        var current = service.preferenceData && service.preferenceData.offsetMode === "utc" ? "utc" : "home"
        if (!service.updateSetting("offsetMode", current === "utc" ? "home" : "utc")) {
            statusMessage = service.lastError
            return false
        }
        return true
    }

    function beginRowDrag(index, pitch) {
        if (!service.cities || index < 0 || index >= service.cities.length) return false
        draggingCityIndex = index
        rowDragTargetIndex = index
        rowDragPitch = Math.max(1, Number(pitch) || 104)
        return true
    }

    function moveRowDrag(offset) {
        if (draggingCityIndex < 0 || !service.cities || service.cities.length === 0) return
        const distance = Number(offset)
        if (!isFinite(distance)) return
        const steps = Math.round(distance / rowDragPitch)
        rowDragTargetIndex = Math.max(0, Math.min(service.cities.length - 1, draggingCityIndex + steps))
    }

    function releaseRowDrag() {
        const from = draggingCityIndex
        const to = rowDragTargetIndex
        draggingCityIndex = -1
        rowDragTargetIndex = -1
        if (from < 0 || to < 0 || from === to) return false
        if (!service.moveCity(from, to)) {
            statusMessage = service.lastError
            return false
        }
        return true
    }

    function cancelRowDrag() {
        draggingCityIndex = -1
        rowDragTargetIndex = -1
    }

    Timer {
        id: scrubHold
        interval: 1500
        repeat: false
        onTriggered: panel.scrubMinutes = 0
    }

    Timer {
        id: placeSearchDebounce
        interval: 300
        repeat: false
        onTriggered: if (typeof panel.service.requestPlaceSearch === "function")
            panel.service.requestPlaceSearch(panel.searchText)
    }

    function globePaintRadius(width, height) {
        var w = Number(width)
        var h = Number(height)
        if (!isFinite(w) || !isFinite(h) || w <= 0 || h <= 0) return 0
        return Math.min(w, h) * 0.45
    }

    component ActionButton: Rectangle {
        id: action
        property string label: ""
        property bool highlighted: false
        property bool available: true
        signal clicked()
        width: Math.max(46, label.length * 7 + 18)
        height: 28
        radius: panel.root.tileRadius !== undefined ? panel.root.tileRadius : 7
        color: action.available ? (action.highlighted ? panel.root.seal : panel.root.fillIdle) : panel.root.bg
        border.color: panel.root.sep
        border.width: 1
        opacity: action.available ? 1 : 0.45
        SharedComponents.UiText {
            anchors.centerIn: parent
            text: action.label
            color: action.highlighted ? panel.root.bg : panel.root.ink
            font.family: panel.root.mono
            font.pixelSize: 11
        }
        MouseArea {
            anchors.fill: parent
            enabled: action.available
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: action.clicked()
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: contentColumn
            width: flick.width
            spacing: 10

            Item {
                id: worldClockHeader
                objectName: "elsewhen-world-clock-header"
                width: parent.width
                readonly property bool compactLayout: width < titleRow.implicitWidth + 2 * (refreshAction.width + 8)
                height: titleArea.implicitHeight + (compactLayout ? refreshAction.height + 8 : 0)

                Column {
                    id: titleArea
                    width: worldClockHeader.compactLayout ? parent.width
                        : Math.max(0, parent.width - 2 * (refreshAction.width + 8))
                    x: worldClockHeader.compactLayout ? 0 : refreshAction.width + 8
                    y: worldClockHeader.compactLayout ? refreshAction.height + 8 : 0
                    spacing: 2

                    Item {
                        objectName: "elsewhen-here-title-target"
                        width: parent.width
                        height: hereCaption.implicitHeight

                        Elsewhen.ArcText {
                            id: hereCaption
                            objectName: "elsewhen-here-city"
                            anchors.fill: parent
                            text: panel.hereLine
                            rise: 6
                            color: panel.scrubMinutes !== 0 ? panel.root.accent : Qt.darker(panel.root.ink, 1.55)
                            fontFamily: panel.root.mono
                            pixelSize: 10
                        }
                        MouseArea {
                            objectName: "elsewhen-here-search-button"
                            anchors.fill: parent
                            enabled: panel.keyboardFocusKey !== "" || panel.keyboardFocusId !== ""
                                || (!!panel.service.localZone && !panel.globeExpanded)
                            activeFocusOnTab: enabled
                            Accessible.role: Accessible.Button
                            Accessible.name: panel.keyboardFocusKey !== "" || panel.keyboardFocusId !== ""
                                ? "Return to home time zone"
                                : panel.searchMode === "here" ? "Cancel choosing home time zone" : "Choose home time zone"
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            Keys.onReturnPressed: function(event) {
                                if (!enabled) return
                                panel.handleHereCaptionClick()
                                event.accepted = true
                            }
                            Keys.onSpacePressed: function(event) {
                                if (!enabled) return
                                panel.handleHereCaptionClick()
                                event.accepted = true
                            }
                            onClicked: panel.handleHereCaptionClick()
                        }
                    }

                    Row {
                        id: titleRow
                        objectName: "elsewhen-world-title-row"
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 28
                        spacing: 9

                        Text {
                            objectName: "elsewhen-world-title"
                            text: "World"
                            color: panel.root.ink
                            font.family: panel.root.mono
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            textFormat: Text.PlainText
                            verticalAlignment: Text.AlignVCenter
                        }

                        Item {
                            id: heroGlobeButton
                            objectName: "elsewhen-hero-globe-button"
                            width: 28
                            height: 28
                            enabled: panel.service.preferenceData.globeEnabled !== false
                            Accessible.role: Accessible.Button
                            Accessible.name: panel.globeExpanded ? "Return to world clock" : "Expand world clock globe"
                            Rectangle {
                                anchors.fill: parent
                                radius: 5
                                color: heroGlobeMouse.containsMouse ? panel.root.fillHover : "transparent"
                            }
                            Elsewhen.MiniGlobe {
                                id: heroGlobeCanvas
                                objectName: "elsewhen-hero-globe-icon"
                                anchors.fill: parent
                                anchors.margins: 3
                                spin: panel.heroSpin
                                worldData: panel.service.worldData || []
                                ink: panel.root.ink
                                land: panel.root.seal
                                rotation: Globe.AXIAL_TILT
                                opacity: panel.globeExpanded ? 0 : 1
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: panel.root.ink
                                font.pixelSize: 24
                                rotation: -Globe.AXIAL_TILT
                                opacity: panel.globeExpanded ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }
                            MouseArea {
                                id: heroGlobeMouse
                                anchors.fill: parent
                                enabled: heroGlobeButton.enabled
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    panel.toggleGlobeExpanded((mouse.modifiers & Qt.ShiftModifier) !== 0)
                                }
                            }
                        }

                        Text {
                            objectName: "elsewhen-clock-title"
                            text: "Clock"
                            color: panel.root.ink
                            font.family: panel.root.mono
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            textFormat: Text.PlainText
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                ActionButton {
                    id: refreshAction
                    label: "Refresh"
                    x: parent.width - width
                    y: worldClockHeader.compactLayout ? 0 : (parent.height - height) / 2
                    onClicked: {
                        if (!panel.service.refresh()) panel.statusMessage = panel.service.lastError
                    }
                }
            }

            ListView {
                id: cityList
                objectName: "elsewhen-city-list"
                width: parent.width
                height: panel.globeExpanded ? 0 : contentHeight
                implicitHeight: height
                visible: !panel.globeExpanded
                clip: false
                interactive: false
                model: panel.service.cities && panel.service.cities.length > 0 ? panel.service.cities : panel.service.clockRows || []
                delegate: Elsewhen.CityRow {
                    width: cityList.width
                    panel: panel.contentRoot
                }
            }

            Row {
                width: parent.width
                height: visible ? implicitHeight : 0
                visible: !panel.globeExpanded || panel.searchMode === "jump"
                z: panel.globeExpanded && panel.searchMode === "jump" ? 1 : 0
                spacing: 7
                TextField {
                    id: zoneSearchInput
                    objectName: "elsewhen-zone-search"
                    width: parent.width - 104
                    height: 32
                    placeholderText: panel.searchMode === "here" ? "Where are you?"
                        : panel.searchMode === "jump" ? "Jump to a place" : "Search time zones or places"
                    selectByMouse: true
                    color: panel.root.ink
                    placeholderTextColor: panel.root.sep
                    font.pixelSize: 11
                    onTextChanged: {
                        panel.searchText = text
                        panel.statusMessage = ""
                        placeSearchDebounce.restart()
                    }
                    onAccepted: {
                        placeSearchDebounce.stop()
                        if (panel.searchResults.length > 0) {
                            panel.addSearchResult(panel.searchResults[Model.moveSelection(
                                panel.searchSelectionIndex, 0, panel.searchResults.length)])
                        } else if (typeof panel.service.requestPlaceSearch === "function") {
                            panel.service.requestPlaceSearch(text)
                        }
                    }
                    Keys.onUpPressed: function(event) {
                        if (panel.searchResults.length > 0) {
                            panel.searchSelectionIndex = Model.moveSelection(panel.searchSelectionIndex,
                                -1, panel.searchResults.length)
                            event.accepted = true
                        }
                    }
                    Keys.onDownPressed: function(event) {
                        if (panel.searchResults.length > 0) {
                            panel.searchSelectionIndex = Model.moveSelection(panel.searchSelectionIndex,
                                1, panel.searchResults.length)
                            event.accepted = true
                        }
                    }
                    background: Rectangle {
                        radius: 6
                        color: panel.root.fillIdle
                        border.color: zoneSearchInput.activeFocus ? panel.root.seal : panel.root.sep
                        border.width: 1
                    }
                }
                ActionButton {
                    id: addZoneAction
                    label: panel.searchMode === "here" ? "Set here"
                        : panel.searchMode === "jump" ? "Jump" : "Add zone"
                    available: panel.searchResults.length > 0
                    onClicked: panel.addSearchResult(panel.searchResults[Model.moveSelection(
                        panel.searchSelectionIndex, 0, panel.searchResults.length)])
                }
            }

            ListView {
                id: searchList
                objectName: "elsewhen-search-results"
                width: parent.width
                height: visible ? contentHeight : 0
                visible: (!panel.globeExpanded || panel.searchMode === "jump")
                    && panel.searchText.trim().length >= 2 && count > 0
                currentIndex: panel.searchSelectionIndex
                highlightFollowsCurrentItem: true
                highlight: Rectangle { color: panel.root.fillHover; radius: 4 }
                clip: false
                interactive: false
                model: panel.searchResults
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: searchList.width
                    height: 32
                    color: resultMouse.containsMouse || index === panel.searchSelectionIndex
                        ? panel.root.fillHover : panel.root.fillIdle
                    radius: 4
                    SharedComponents.UiText {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label + (modelData.region ? ", " + modelData.region : "") + "  ·  " + modelData.value
                        color: panel.root.ink
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: resultMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: panel.searchSelectionIndex = index
                        onClicked: panel.addSearchResult(modelData)
                    }
                }
            }

            SharedComponents.UiText {
                objectName: "elsewhen-place-search-status"
                width: parent.width
                visible: (!panel.globeExpanded || panel.searchMode === "jump") && panel.searchText.trim().length >= 3
                    && panel.service.placeSearchText === Model.placeQuery(panel.searchText)
                    && panel.searchResults.length === 0
                    && panel.service.placeSearchRunning
                text: "Searching places…"
                color: panel.root.seal
                font.pixelSize: 10
            }

            SharedComponents.UiText {
                objectName: "elsewhen-place-search-empty"
                width: parent.width
                visible: (!panel.globeExpanded || panel.searchMode === "jump") && panel.searchText.trim().length >= 3
                    && panel.service.placeSearchText === Model.placeQuery(panel.searchText)
                    && panel.searchResults.length === 0
                    && !panel.service.placeSearchRunning
                    && !panel.service.placeSearchError
                text: "No matching time zones or places."
                color: panel.root.seal
                font.pixelSize: 10
            }

            Row {
                width: parent.width
                spacing: 7
                ActionButton {
                    id: hour24Action
                    visible: !panel.globeExpanded
                    label: panel.service.preferenceData.hour24 ? "24-hour" : "12-hour"
                    highlighted: panel.service.preferenceData.hour24 === true
                    onClicked: panel.toggleHour24()
                }
                ActionButton {
                    id: globeToggleAction
                    visible: !panel.globeExpanded
                    label: panel.service.preferenceData.globeEnabled === false ? "Show globe" : "Hide globe"
                    highlighted: panel.service.preferenceData.globeEnabled !== false
                    onClicked: panel.service.updateSetting("globeEnabled", panel.service.preferenceData.globeEnabled === false)
                }
                ActionButton {
                    id: changeTimezoneAction
                    label: "Set zone"
                    available: panel.timezoneTarget !== ""
                    onClicked: panel.timezoneConfirmationVisible = true
                }
                ActionButton {
                    id: globeZoomAction
                    objectName: "elsewhen-globe-zoom"
                    label: panel.globeExpanded ? "Back" : "Zoom"
                    highlighted: panel.globeExpanded
                    available: panel.service.preferenceData.globeEnabled !== false
                    onClicked: panel.toggleGlobeExpanded()
                }
            }

            Rectangle {
                width: parent.width
                height: panel.service.preferenceData.globeEnabled === false ? 0 : (panel.globeExpanded ? 312 : 170)
                visible: panel.service.preferenceData.globeEnabled !== false
                color: panel.root.fillIdle
                radius: 8
                border.color: panel.root.sep
                border.width: 1
                Behavior on height {
                    NumberAnimation {
                        duration: panel.globeZoomDuration
                        easing.type: panel.globeZoomEasing
                    }
                }
                Canvas {
                    id: globeCanvasItem
                    objectName: "elsewhen-globe"
                    anchors.centerIn: parent
                    width: Math.max(0, Math.min(parent.width - 12, panel.globeExpanded ? 300 : 260))
                    height: panel.globeExpanded ? 300 : 158
                    Behavior on height {
                        NumberAnimation {
                            duration: panel.globeZoomDuration
                            easing.type: panel.globeZoomEasing
                        }
                    }
                    onPaint: {
                        var ctx = getContext("2d")
                        var cx = width / 2
                        var cy = height / 2
                        var radius = panel.globePaintRadius(width, height)
                        var spin = panel.globeSpin
                        ctx.clearRect(0, 0, width, height)
                        if (radius <= 0) return
                        ctx.save()
                        ctx.beginPath()
                        ctx.arc(cx, cy, radius, 0, Math.PI * 2)
                        ctx.fillStyle = panel.root.bg.toString()
                        ctx.fill()
                        ctx.clip()
                        for (var lat = -60; lat <= 60; lat += 30) {
                            ctx.beginPath()
                            var started = false
                            for (var lon = -180; lon <= 180; lon += 4) {
                                var point = Globe.project(lat, lon, spin, panel.globeViewLat, radius)
                                if (!point.visible) { started = false; continue }
                                if (!started) { ctx.moveTo(cx + point.x, cy + point.y); started = true }
                                else ctx.lineTo(cx + point.x, cy + point.y)
                            }
                            ctx.strokeStyle = panel.root.sep.toString()
                            ctx.lineWidth = 0.45
                            ctx.stroke()
                        }
                        for (var ringIndex = 0; ringIndex < panel.service.worldData.length; ringIndex++) {
                            var ring = panel.service.worldData[ringIndex]
                            if (!Array.isArray(ring) || ring.length < 8) continue
                            var clipped = Globe.clipRingToDisc(ring, spin, panel.globeViewLat, radius * 0.98)
                            if (clipped.length < 3) continue
                            ctx.beginPath()
                            ctx.moveTo(cx + clipped[0].x, cy + clipped[0].y)
                            for (var p = 1; p < clipped.length; p++) ctx.lineTo(cx + clipped[p].x, cy + clipped[p].y)
                            ctx.closePath()
                            ctx.fillStyle = Qt.rgba(panel.root.seal.r, panel.root.seal.g, panel.root.seal.b, 0.22).toString()
                            ctx.fill()
                            ctx.strokeStyle = Qt.rgba(panel.root.seal.r, panel.root.seal.g, panel.root.seal.b, 0.55).toString()
                            ctx.lineWidth = 0.5
                            ctx.stroke()
                        }
                        var sun = Globe.subsolarPoint(panel.effectiveMs)
                        var scene = panel.globeScene(radius)
                        for (var cityIndex = 0; cityIndex < scene.plotted.length; cityIndex++) {
                            var plotted = scene.plotted[cityIndex]
                            var city = scene.places[plotted.index]
                            var point = { x: plotted.x, y: plotted.y }
                            ctx.beginPath()
                            ctx.arc(cx + point.x, cy + point.y,
                                city.key === panel.globeSelectionKey ? 3.2 : (city.tracked ? 2.6 : 1.7),
                                0, Math.PI * 2)
                            ctx.fillStyle = city.key === panel.globeSelectionKey || city.tracked
                                ? panel.root.seal.toString()
                                : (Globe.isDaylight(city.lat, city.lon, sun)
                                    ? panel.root.seal.toString() : panel.root.ink.toString())
                            ctx.fill()
                        }
                        ctx.font = "9px " + panel.root.mono
                        ctx.textBaseline = "middle"
                        ctx.fillStyle = panel.root.ink.toString()
                        for (var labelIndex = 0; labelIndex < scene.labels.length; labelIndex++) {
                            var label = scene.labels[labelIndex]
                            var box = label.box
                            ctx.fillText(scene.places[label.index].label, cx + box.x, cy + box.y + box.h / 2)
                        }
                        ctx.restore()
                        ctx.beginPath()
                        ctx.arc(cx, cy, radius, 0, Math.PI * 2)
                        ctx.strokeStyle = panel.root.seal.toString()
                        ctx.lineWidth = 1
                        ctx.stroke()
                    }
                }
                MouseArea {
                    id: globeDragArea
                    anchors.centerIn: parent
                    width: globeCanvasItem.width
                    height: globeCanvasItem.height
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.OpenHandCursor
                    property bool moved: false
                    onPressed: function(mouse) {
                        panel.globeDragX = mouse.x
                        panel.globeDragY = mouse.y
                        moved = false
                        cursorShape = Qt.ClosedHandCursor
                    }
                    onReleased: function(mouse) {
                        cursorShape = Qt.OpenHandCursor
                        if (!moved) panel.tapGlobeAt(mouse.x, mouse.y)
                    }
                    onCanceled: {
                        moved = false
                        cursorShape = Qt.OpenHandCursor
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed) return
                        var dx = mouse.x - panel.globeDragX
                        var dy = mouse.y - panel.globeDragY
                        if (Math.abs(dx) + Math.abs(dy) > 2) moved = true
                        panel.globeSpin = (panel.globeSpin + dx * 0.7 + 360) % 360
                        panel.globeViewLat = Math.max(-70, Math.min(70, panel.globeViewLat + dy * 0.35))
                        panel.globeDragX = mouse.x
                        panel.globeDragY = mouse.y
                        globeCanvasItem.requestPaint()
                    }
                }
            }

            Column {
                objectName: "elsewhen-globe-selection"
                width: parent.width
                visible: panel.globeFooterPlace !== null
                spacing: 2
                TextMetrics {
                    id: globeFooterCapHeight
                    font.family: globeFooterCity.font.family
                    font.pixelSize: globeFooterCity.font.pixelSize
                    font.weight: globeFooterCity.font.weight
                    text: "M"
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: implicitWidth
                    spacing: 7
                    Rectangle {
                        width: Math.max(6, Math.round(globeFooterCapHeight.tightBoundingRect.height) - 1)
                        height: width
                        y: globeFooterCity.baselineOffset - height
                        radius: width / 2
                        color: panel.globeFooterDaylight ? panel.root.seal : "transparent"
                        Elsewhen.MoonDot {
                            objectName: "elsewhen-globe-footer-moon"
                            anchors.fill: parent
                            visible: panel.globeFooterPlace !== null && !panel.globeFooterDaylight
                            phase: panel.globeFooterMoonPhase
                            color: panel.root.ink
                        }
                    }
                    SharedComponents.UiText {
                        id: globeFooterCity
                        objectName: "elsewhen-globe-footer-city"
                        text: panel.globeFooterPlace ? panel.globeFooterPlace.label : ""
                        color: panel.root.ink
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    SharedComponents.UiText {
                        objectName: "elsewhen-globe-footer-clock"
                        text: panel.globeFooterClock
                        visible: text !== ""
                        color: panel.root.ink
                        font.pixelSize: 11
                    }
                    SharedComponents.UiText {
                        objectName: "elsewhen-globe-footer-badge"
                        text: panel.globeFooterBadge
                        visible: text !== ""
                        color: panel.root.seal
                        font.pixelSize: 10
                    }
                }
                Item {
                    width: parent.width
                    height: 16
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: implicitWidth
                        spacing: 6
                        SharedComponents.UiText {
                            objectName: "elsewhen-globe-footer-zone"
                            text: panel.globeFooterPlace ? panel.globeFooterPlace.id : ""
                            color: globeFooterOffsetHover.hovered
                                ? Qt.darker(panel.root.ink, 1.55) : Qt.darker(panel.root.ink, 2.1)
                            font.pixelSize: 10
                        }
                        SharedComponents.UiText {
                            objectName: "elsewhen-globe-footer-offset"
                            text: panel.offsetTextFor(panel.globeFooterRow)
                            visible: text !== ""
                            color: globeFooterOffsetHover.hovered
                                ? panel.root.ink : Qt.darker(panel.root.ink, 1.55)
                            font.pixelSize: 10
                        }
                    }
                    HoverHandler {
                        id: globeFooterOffsetHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    MouseArea {
                        objectName: "elsewhen-globe-footer-offset-toggle"
                        anchors.fill: parent
                        enabled: panel.globeFooterRow && panel.globeFooterRow.ready
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: panel.toggleOffsetMode()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: panel.timezoneConfirmationVisible ? timezoneConfirmationLayout.implicitHeight + 12 : 0
                visible: height > 0
                color: panel.root.bg
                radius: 6
                Column {
                    id: timezoneConfirmationLayout
                    x: 6
                    y: 6
                    width: Math.max(0, parent.width - 12)
                    spacing: 8
                    SharedComponents.UiText {
                        objectName: "elsewhen-timezone-confirmation-message"
                        width: parent.width
                        text: "Set system zone to " + panel.timezoneTarget + "?"
                        color: panel.root.ink
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                    Flow {
                        width: parent.width
                        spacing: 8
                        ActionButton {
                            id: confirmTimezoneAction
                            label: "Confirm"
                            highlighted: true
                            onClicked: {
                                if (!panel.service.requestTimezoneChange(panel.timezoneTarget))
                                    panel.statusMessage = panel.service.timezoneError || panel.service.lastError
                                panel.timezoneConfirmationVisible = false
                            }
                        }
                        ActionButton {
                            label: "Cancel"
                            onClicked: panel.timezoneConfirmationVisible = false
                        }
                    }
                }
            }

            SharedComponents.UiText {
                width: parent.width
                visible: text !== ""
                text: String(panel.statusMessage || panel.service.lastError || panel.service.catalogError
                    || panel.service.timezoneError || panel.service.placeSearchError || "")
                color: panel.root.seal
                font.pixelSize: 10
                wrapMode: Text.Wrap
            }
        }
    }

    function placeForZone(zone) {
        for (var i = 0; i < service.cityData.length; i++)
            if (service.cityData[i][1] === zone) return service.cityData[i]
        return null
    }

    function placeForCity(city) {
        if (!city) return null
        var lat = Number(city.lat), lon = Number(city.lon)
        if (city.lat !== undefined && city.lon !== undefined && isFinite(lat) && isFinite(lon))
            return { lat: lat, lon: lon }
        var wantedLabel = String(city.label || "").trim().toLowerCase()
        for (var i = 0; i < service.cityData.length; i++) {
            var namedPlace = service.cityData[i]
            if (namedPlace[1] === city.id && String(namedPlace[0]).toLowerCase() === wantedLabel)
                return { lat: Number(namedPlace[2]), lon: Number(namedPlace[3]) }
        }
        var catalogPlace = placeForZone(city.id)
        return catalogPlace ? { lat: Number(catalogPlace[2]), lon: Number(catalogPlace[3]) } : null
    }

    function turnHeroToFocus(place, from) {
        if (!place) return false
        var target = Number(place.lon)
        var start = Number(from)
        if (!isFinite(start)) start = Number(heroSpin)
        if (!isFinite(target) || !isFinite(start)) return false
        openingSpinPending = false
        openingSpinFallback.stop()
        heroOpeningSpin.stop()
        heroFocusAnimation.stop()
        heroFocusAnimation.from = start
        heroFocusAnimation.to = start + Globe.shortestTurn(start, target)
        heroFocusAnimation.restart()
        return true
    }

    function startOpeningSpin(usePreviousEndpoints) {
        if (!panelIsOpen) return false
        if (usePreviousEndpoints) {
            openingSpinPending = false
            openingSpinFallback.stop()
            heroOpeningSpin.restart()
            return true
        }
        if (service.settingsReady === false || service.cityDataReady === false
                || String(service.localZone || "") === "") {
            openingSpinPending = true
            openingSpinFallback.restart()
            return false
        }
        var home = hereZone ? { label: hereZone.label, id: hereZone.id, lat: hereZone.lat, lon: hereZone.lon } : null
        var place = placeForCity(home)
        var target = place ? Number(place.lon) : NaN
        if (!isFinite(target)) {
            openingSpinPending = true
            openingSpinFallback.restart()
            return false
        }
        openingSpinPending = false
        openingSpinFallback.stop()
        heroOpeningSpin.stop()
        heroOpeningSpin.from = target - 1080
        heroOpeningSpin.to = target
        heroOpeningSpin.restart()
        return true
    }

    function addSearchResult(option) {
        if (!option) return false
        if (searchMode === "here") return pickHereOption(option)
        if (searchMode === "jump") return jumpToOption(option)
        var place = placeForZone(option.value)
        var facts = option.lat !== undefined && option.lon !== undefined
            ? { lat: option.lat, lon: option.lon, region: option.region }
            : place ? { lat: place[2], lon: place[3] } : null
        if (!service.addCity(option.value, option.label, facts)) {
            statusMessage = service.lastError || "Could not add this time zone"
            return false
        }
        statusMessage = ""
        searchMode = ""
        zoneSearchInput.clear()
        return true
    }

    function pickHereOption(option) {
        var zone = String(option.value || option.id || "")
        var pick = { label: option.label, id: zone }
        if (option.lat !== undefined && option.lon !== undefined) {
            pick.lat = Number(option.lat)
            pick.lon = Number(option.lon)
        } else {
            var point = placeForCity({ label: option.label, id: zone })
            if (point) { pick.lat = point.lat; pick.lon = point.lon }
        }
        if (option.region) pick.region = option.region
        var next = Model.hereAfterPick(service.cities || [], hereZone, pick, service.localZone)
        if (!next) {
            statusMessage = "Could not resolve this place as a time zone"
            return false
        }
        if (next.zoneChange !== "") {
            if (!service.requestTimezoneChange(next.zoneChange, next.here, next.zones)) {
                statusMessage = service.timezoneError || service.lastError || "Could not change the system time zone"
                return false
            }
        } else if (!service.setHere(next.here, next.zones)) {
            statusMessage = service.lastError || "Could not save this place as here"
            return false
        }
        statusMessage = ""
        searchMode = ""
        searchText = ""
        zoneSearchInput.clear()
        panel.forceActiveFocus()
        return true
    }

    function jumpToOption(option) {
        var zone = String(option.value || option.id || "")
        var place = option.lat !== undefined && option.lon !== undefined
            ? { lat: Number(option.lat), lon: Number(option.lon), region: option.region || "" }
            : placeForCity({ label: option.label, id: zone })
        var label = String(option.label || zone)
        if (!place || !isFinite(Number(place.lat)) || !isFinite(Number(place.lon))) {
            statusMessage = "This place has no map coordinates"
            return false
        }
        place = { lat: Number(place.lat), lon: Number(place.lon), region: String(option.region || place.region || "") }
        var places = globePlaces(), match = null, nameTaken = false
        for (var i = 0; i < places.length; i++) {
            var existing = places[i]
            if (String(existing.label).toLowerCase() === label.toLowerCase()) nameTaken = true
            if (existing.id === zone && String(existing.label).toLowerCase() === label.toLowerCase()
                    && Model.nearPlace(existing, place)) match = existing
        }
        if (!match && nameTaken) {
            var regional = Model.regionalName(label, place.region)
            if (regional === label) {
                faceGlobe(place)
                searchMode = ""
                searchText = ""
                zoneSearchInput.clear()
                panel.forceActiveFocus()
                return true
            }
            label = regional
            for (var j = 0; j < places.length; j++) {
                var renamed = places[j]
                if (renamed.id === zone && String(renamed.label).toLowerCase() === label.toLowerCase()
                        && Model.nearPlace(renamed, place)) { match = renamed; break }
            }
        }
        if (match) {
            globeSelectionKey = match.key
            globeSelectionLabel = match.label
            globeSelectionZone = match.id
            timezoneTarget = match.id
            if (match.tracked) focusCity(match.trackedIndex)
            else faceGlobe(match)
        } else {
            var sessionCity = { label: label, id: zone, lat: place.lat, lon: place.lon }
            if (place.region) sessionCity.region = place.region
            var nextSession = (globeSessionCities || []).slice()
            nextSession.push(sessionCity)
            globeSessionCities = nextSession
            globeSelectionKey = globeCityIdentity(sessionCity)
            globeSelectionLabel = label
            globeSelectionZone = zone
            timezoneTarget = zone
            faceGlobe(sessionCity)
        }
        if (typeof service.ensureProbeZone === "function") service.ensureProbeZone(zone)
        statusMessage = ""
        searchMode = ""
        searchText = ""
        zoneSearchInput.clear()
        panel.forceActiveFocus()
        return true
    }

    Behavior on moonDemo {
        enabled: panel.moonShowing
        NumberAnimation { duration: 460; easing.type: Easing.InOutSine }
    }

    Timer {
        id: moonShowTimer
        interval: 620
        repeat: true
        onTriggered: {
            panel.moonShowStep++
            if (panel.moonShowStep >= panel.moonShowStops.length) panel.stopMoonShow()
            else panel.moonDemo = panel.moonShowStops[panel.moonShowStep]
        }
    }

    Binding {
        target: panel
        property: "heroSpin"
        value: panel.heroRestLon
        when: !heroOpeningSpin.running && !heroFocusAnimation.running
        restoreMode: Binding.RestoreNone
    }

    NumberAnimation {
        id: heroOpeningSpin
        target: panel
        property: "heroSpin"
        duration: panel.service.preferenceData && panel.service.preferenceData.smoothMotion === false ? 0 : 1250
        easing.type: Easing.OutQuart
    }

    NumberAnimation {
        id: heroFocusAnimation
        target: panel
        property: "heroSpin"
        duration: panel.service.preferenceData && panel.service.preferenceData.smoothMotion === false ? 0 : 700
        easing.type: Easing.OutCubic
    }

    Timer {
        id: openingSpinFallback
        interval: 1500
        repeat: false
        onTriggered: {
            if (panel.openingSpinPending && panel.panelIsOpen) panel.startOpeningSpin(true)
        }
    }

    NumberAnimation {
        id: globeFocusAnimation
        target: panel
        property: "globeSpin"
        duration: 500
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: globeViewAnimation
        target: panel
        property: "globeViewLat"
        duration: 500
        easing.type: Easing.OutCubic
    }

    Timer {
        interval: 20 * 60 * 1000
        repeat: true
        running: panel.service.active
        onTriggered: panel.requestCityWeather()
    }

    Connections {
        target: panel.service
        function onActiveChanged() { if (panel.service.active) panel.requestCityWeather() }
        function onCitiesChanged() { panel.requestCityWeather(); globeCanvasItem.requestPaint() }
        function onSettingsReadyChanged() { if (panel.openingSpinPending) panel.startOpeningSpin() }
        function onCityDataReadyChanged() { panel.requestCityWeather(); if (panel.openingSpinPending) panel.startOpeningSpin() }
        function onWeatherChanged() { globeCanvasItem.requestPaint() }
        function onNowMsChanged() { globeCanvasItem.requestPaint() }
        function onWorldDataChanged() { globeCanvasItem.requestPaint() }
        function onCityDataChanged() {
            if (panel.openingSpinPending) panel.startOpeningSpin()
            globeCanvasItem.requestPaint()
        }
        function onLocalZoneChanged() { if (panel.openingSpinPending) panel.startOpeningSpin() }
        function onPreferenceDataChanged() { if (panel.openingSpinPending) panel.startOpeningSpin() }
        function onTimezoneChanged(zone) { panel.notifyTimezoneChange(true, zone) }
        function onTimezoneChangeFailed(zone) { panel.notifyTimezoneChange(false, zone) }
    }

    Component.onCompleted: globeCanvasItem.requestPaint()
}
