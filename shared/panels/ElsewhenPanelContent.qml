pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../components" as SharedComponents
import "../integrations/elsewhen" as Elsewhen
import "../integrations/elsewhen/GlobeModel.js" as Globe
import "../integrations/elsewhen/Model.js" as Model

Item {
    id: panel
    required property var root
    required property var service
    property real scrubMinutes: 0
    property string searchText: ""
    property string statusMessage: ""
    property real globeSpin: 0
    property real globeViewLat: 0
    property real globeDragX: 0
    property real globeDragY: 0
    readonly property var contentRoot: panel
    property bool timezoneConfirmationVisible: false
    property int peopleEditIndex: -1
    property int draggingCityIndex: -1
    property int rowDragTargetIndex: -1
    property real rowDragPitch: 104
    property var profiles: ({})
    property string temperatureLabel: ""
    property string timezoneTarget: service.clockRows.length ? service.clockRows[0].id : service.localZone
    property string keyboardFocusId: ""
    property string keyboardFocusKey: ""
    onKeyboardFocusIdChanged: keyboardFocusKey = ""
    readonly property double effectiveMs: (service.nowMs !== undefined ? service.nowMs : Date.now()) + scrubMinutes * 60000
    readonly property bool hour24: service.preferenceData ? service.preferenceData.hour24 === true : false
    readonly property var hereZone: Model.resolveHere(null,
        service.preferenceData ? service.preferenceData.homeCity : "", service.localZone)
    readonly property var displayRows: {
        var zones = service.cities || []
        var probeData = service.probe || ({})
        if (Object.keys(probeData).length === 0) return service.clockRows || []
        var offset = service.localOffsetMinutes !== undefined ? service.localOffsetMinutes : 0
        var use24 = service.preferenceData && service.preferenceData.hour24 === true
        return Model.rows(zones, probeData, effectiveMs, offset, use24)
    }
    readonly property var searchResults: typeof service.searchLocations === "function"
        ? service.searchLocations(searchText, 8) : service.searchZones(searchText, 8)
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
    property alias globeDragArea: globeDragArea
    property alias changeTimezoneButton: changeTimezoneAction
    property alias confirmTimezoneButton: confirmTimezoneAction
    onGlobeSpinChanged: globeCanvasItem.requestPaint()
    onGlobeViewLatChanged: globeCanvasItem.requestPaint()
    focus: true
    Keys.priority: Keys.AfterItem
    Keys.onPressed: function(event) {
        if ((event.modifiers & (Qt.ControlModifier | Qt.MetaModifier))
                || ((event.modifiers & Qt.AltModifier) && event.key !== Qt.Key_T)) return
        if (event.key === Qt.Key_Escape) {
            handleEscape()
        } else if (zoneSearchInput.activeFocus || peopleEditIndex >= 0) {
            return
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
            zoneSearchInput.forceActiveFocus()
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
        keyboardFocusId = zoneId
        keyboardFocusKey = Model.factsKey(cities[index])
        timezoneTarget = zoneId
        var city = cities[index]
        var place = placeForCity(city)
        if (place && isFinite(place.lon)) {
            globeFocusAnimation.stop()
            globeFocusAnimation.from = globeSpin
            globeFocusAnimation.to = globeSpin + Globe.shortestTurn(globeSpin, place.lon)
            globeFocusAnimation.restart()
        }
        var row = cityList.itemAtIndex(index)
        if (row) {
            var top = row.mapToItem(flick.contentItem, 0, 0).y
            if (top < flick.contentY) flick.contentY = top
            else if (top + row.height > flick.contentY + flick.height)
                flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, top + row.height - flick.height))
        }
        return true
    }

    function tapGlobeAt(x, y) {
        var point = globeCanvasItem.mapFromItem(globeDragArea, x, y)
        var cx = globeCanvasItem.width / 2, cy = globeCanvasItem.height / 2
        var radius = globePaintRadius(globeCanvasItem.width, globeCanvasItem.height)
        var cities = service.cities || []
        var hit = -1, bestDistance = 64
        for (var i = 0; i < cities.length; i++) {
            var place = placeForCity(cities[i])
            if (!place) continue
            var marker = Globe.project(place.lat, place.lon, globeSpin, globeViewLat, radius)
            if (!marker.visible) continue
            var dx = point.x - cx - marker.x, dy = point.y - cy - marker.y
            var distance = dx * dx + dy * dy
            if (distance <= bestDistance) { hit = i; bestDistance = distance }
        }
        if (hit < 0) return false

        var city = cities[hit]
        var place = placeForCity(city)
        focusCity(hit)
        globeViewAnimation.stop()
        globeViewAnimation.from = globeViewLat
        globeViewAnimation.to = Math.max(-70, Math.min(70, Number(place.lat)))
        globeViewAnimation.restart()

        var preference = service.preferenceData || ({})
        var homeOverride = String(preference.homeCity || "")
        var nextHome = Model.homeCityAfterTap(city.label, city.id, homeOverride, service.localZone)
        if (nextHome !== null && !service.updateSetting("homeCity", nextHome))
            statusMessage = service.lastError
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
        else if (scrubMinutes !== 0) {
            scrubHold.stop()
            scrubMinutes = 0
        } else root.elsewhenVisible = false
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

            Row {
                width: parent.width
                height: 28
                spacing: 8
                SharedComponents.UiText {
                    objectName: "elsewhen-here-city"
                    width: parent.width - refreshAction.width - 8
                    height: parent.height
                    text: panel.hereZone && panel.hereZone.chosen
                        ? "Here now · " + panel.hereZone.label : "World clock"
                    color: panel.root.ink
                    font.pixelSize: 14
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }
                ActionButton {
                    id: refreshAction
                    label: "Refresh"
                    onClicked: {
                        if (!panel.service.refresh()) panel.statusMessage = panel.service.lastError
                    }
                }
            }

            ListView {
                id: cityList
                objectName: "elsewhen-city-list"
                width: parent.width
                height: contentHeight
                implicitHeight: height
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
                spacing: 7
                TextField {
                    id: zoneSearchInput
                    objectName: "elsewhen-zone-search"
                    width: parent.width - 104
                    height: 32
                    placeholderText: "Search time zones or places"
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
                        if (typeof panel.service.requestPlaceSearch === "function")
                            panel.service.requestPlaceSearch(text)
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
                    label: "Add zone"
                    available: panel.searchResults.length > 0
                    onClicked: panel.addSearchResult(panel.searchResults[0])
                }
            }

            ListView {
                id: searchList
                objectName: "elsewhen-search-results"
                width: parent.width
                height: visible ? contentHeight : 0
                visible: panel.searchText.trim().length >= 2 && count > 0
                clip: false
                interactive: false
                model: panel.searchResults
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: searchList.width
                    height: 32
                    color: resultMouse.containsMouse ? panel.root.fillHover : panel.root.fillIdle
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
                        onClicked: panel.addSearchResult(modelData)
                    }
                }
            }

            SharedComponents.UiText {
                objectName: "elsewhen-place-search-status"
                width: parent.width
                visible: panel.searchText.trim().length >= 3
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
                visible: panel.searchText.trim().length >= 3
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
                    label: panel.service.preferenceData.hour24 ? "24-hour" : "12-hour"
                    highlighted: panel.service.preferenceData.hour24 === true
                    onClicked: panel.toggleHour24()
                }
                ActionButton {
                    id: globeToggleAction
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
            }

            Rectangle {
                width: parent.width
                height: panel.service.preferenceData.globeEnabled === false ? 0 : 170
                visible: height > 0
                color: panel.root.fillIdle
                radius: 8
                border.color: panel.root.sep
                border.width: 1
                Canvas {
                    id: globeCanvasItem
                    objectName: "elsewhen-globe"
                    anchors.centerIn: parent
                    width: Math.max(0, Math.min(parent.width - 12, 260))
                    height: 158
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
                        for (var cityIndex = 0; cityIndex < panel.service.cities.length; cityIndex++) {
                            var city = panel.service.cities[cityIndex]
                            var place = panel.placeForCity(city)
                            if (!place) continue
                            var marker = Globe.project(place.lat, place.lon, spin, panel.globeViewLat, radius)
                            if (!marker.visible) continue
                            ctx.beginPath()
                            ctx.arc(cx + marker.x, cy + marker.y, 2.4, 0, Math.PI * 2)
                            ctx.fillStyle = Globe.isDaylight(place.lat, place.lon, sun)
                                ? panel.root.seal.toString() : panel.root.ink.toString()
                            ctx.fill()
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
                    anchors.fill: parent
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

            Rectangle {
                width: parent.width
                height: panel.timezoneConfirmationVisible ? 54 : 0
                visible: height > 0
                color: panel.root.bg
                radius: 6
                Row {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8
                    SharedComponents.UiText {
                        width: parent.width - confirmTimezoneAction.width - 50
                        text: "Set system zone to " + panel.timezoneTarget + "?"
                        color: panel.root.ink
                        font.pixelSize: 10
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
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

    function addSearchResult(option) {
        if (!option) return false
        var place = placeForZone(option.value)
        var facts = option.lat !== undefined && option.lon !== undefined
            ? { lat: option.lat, lon: option.lon, region: option.region }
            : place ? { lat: place[2], lon: place[3] } : null
        if (!service.addCity(option.value, option.label, facts)) {
            statusMessage = service.lastError || "Could not add this time zone"
            return false
        }
        statusMessage = ""
        zoneSearchInput.clear()
        return true
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
        function onCityDataReadyChanged() { panel.requestCityWeather() }
        function onWeatherChanged() { globeCanvasItem.requestPaint() }
        function onNowMsChanged() { globeCanvasItem.requestPaint() }
        function onWorldDataChanged() { globeCanvasItem.requestPaint() }
        function onCityDataChanged() { globeCanvasItem.requestPaint() }
    }

    Component.onCompleted: globeCanvasItem.requestPaint()
}
