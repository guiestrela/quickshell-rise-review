import QtQuick
import QtTest
import "../shared/panels" as Panels
import "../shared/integrations/elsewhen/GlobeModel.js" as Globe

Item {
    id: testRoot
    width: 460
    height: 620

    QtObject {
        id: fakeTheme
        property color bg: "#1d2021"
        property color ink: "#ebdbb2"
        property color seal: "#d79921"
        property color sep: "#504945"
        property color accent: "#cc241d"
        property color fillIdle: "#282828"
        property color fillHover: "#3c3836"
        property string mono: "monospace"
        property bool elsewhenVisible: true
        property var notificationMessages: []
        function notify(message) {
            notificationMessages = notificationMessages.concat([String(message)])
        }
    }

    QtObject {
        id: fakeService
        signal timezoneChanged(string zone)
        signal timezoneChangeFailed(string zone, string error)
        property var clockRows: [
            { label: "Paris", id: "Europe/Paris", time: "13:00", offset: "UTC+1", abbr: "CET", ready: true, offsetMinutes: 60, progress: 0.5, lit: true },
            { label: "Tokyo", id: "Asia/Tokyo", time: "21:00", offset: "UTC+9", abbr: "JST", ready: true, offsetMinutes: 540, progress: 0.5, lit: true }
        ]
        property var zoneOptions: [
            { label: "Paris", value: "Europe/Paris" },
            { label: "Tokyo", value: "Asia/Tokyo" },
            { label: "New York", value: "America/New_York" }
        ]
        property var cityData: [["Paris", "Europe/Paris", 48.85, 2.35, 1], ["Tokyo", "Asia/Tokyo", 35.68, 139.69, 1]]
        property var weather: ({})
        property var profiles: ({})
        property double profileStamp: 0
        property bool active: false
        property bool weatherRunning: false
        property var cities: [{ label: "Paris", id: "Europe/Paris", people: ["Alice"] }, { label: "Tokyo", id: "Asia/Tokyo" }]
        property var worldData: [[-180, -80, 0, -80, 180, -80, 180, 80, 0, 80, -180, 80]]
        property double nowMs: Date.UTC(2024, 2, 20, 12, 0, 0)
        property int localOffsetMinutes: 0
        property var probe: ({
            "Europe/Paris": { offsetMinutes: 60, abbr: "CET" },
            "Asia/Tokyo": { offsetMinutes: 540, abbr: "JST" }
        })
        property bool staticDataReady: true
        property bool settingsReady: true
        property bool cityDataReady: true
        property var preferenceData: ({ hour24: false, globeEnabled: true, smoothMotion: true })
        property string localZone: "Etc/UTC"
        property string lastError: ""
        property int refreshRequests: 0
        property int settingsWrites: 0
        property int cityAdds: 0
        property var lastAddedPlace: null
        property var searchPlaceResults: []
        property int placeSearchRequests: 0
        property string lastPlaceSearchQuery: ""
        property string placeSearchText: ""
        property bool placeSearchRunning: false
        property string placeSearchError: ""
        property var geocodeOptions: []
        property int cityRemoves: 0
        property int moveRequests: 0
        property int timezoneRequests: 0
        property string timezoneTarget: ""
        property var pendingTimezoneHere: undefined
        property var pendingTimezoneCities: undefined
        property int transientZoneRequests: 0
        property string lastTransientZone: ""
        function refresh() { refreshRequests++; return true }
        function updateSetting(name, value) {
            var next = Object.assign({}, preferenceData)
            next[name] = value
            preferenceData = next
            settingsWrites++
            return true
        }
        function searchZones(query, limit) {
            var q = String(query || "").toLowerCase()
            return zoneOptions.filter(function(option) {
                return option.label.toLowerCase().indexOf(q) >= 0 || option.value.toLowerCase().indexOf(q) >= 0
            }).slice(0, limit)
        }
        function searchLocations(query, limit) {
            return searchPlaceResults.length ? searchPlaceResults.slice(0, limit) : searchZones(query, limit)
        }
        function requestPlaceSearch(query) {
            placeSearchRequests++
            lastPlaceSearchQuery = String(query || "")
            placeSearchText = String(query || "").trim().toLowerCase()
            placeSearchRunning = true
            return true
        }
        function addCity(zone, label, place) { cityAdds++; lastAddedPlace = place; return true }
        function setCities(nextCities) { cities = nextCities; settingsWrites++; return true }
        function removeCity(index) {
            cityRemoves++
            if (clockRows.length <= 1) return false
            var nextCities = cities.slice()
            var nextRows = clockRows.slice()
            nextCities.splice(index, 1)
            nextRows.splice(index, 1)
            cities = nextCities
            clockRows = nextRows
            return true
        }
        function moveCity(from, to) { moveRequests++; return true }
        function setHere(here, nextCities) {
            var next = Object.assign({}, preferenceData)
            if (here === null || here === undefined) delete next.here
            else next.here = here
            delete next.homeCity
            if (nextCities !== undefined && nextCities !== null) cities = nextCities
            preferenceData = next
            settingsWrites++
            return true
        }
        function requestTimezoneChange(zone, here, nextCities) {
            timezoneRequests++
            timezoneTarget = zone
            pendingTimezoneHere = arguments.length > 1 ? here : undefined
            pendingTimezoneCities = arguments.length > 2 ? nextCities : undefined
            return true
        }
        function ensureProbeZone(zone) {
            transientZoneRequests++
            lastTransientZone = zone
            return true
        }
    }

    Panels.ElsewhenPanelContent {
        id: content
        anchors.fill: parent
        root: fakeTheme
        service: fakeService
    }

    TestCase {
        name: "ElsewhenPanelContent"
        when: windowShown

        function test_timezone_change_notifications_are_forwarded() {
            var originalMessages = fakeTheme.notificationMessages
            fakeTheme.notificationMessages = []
            try {
                fakeService.timezoneChanged("Europe/Paris")
                compare(fakeTheme.notificationMessages.length, 1)
                verify(fakeTheme.notificationMessages[0].indexOf("Europe/Paris") >= 0)

                fakeService.timezoneChangeFailed("Asia/Tokyo", "fixture denied")
                compare(fakeTheme.notificationMessages.length, 2)
                verify(fakeTheme.notificationMessages[1].indexOf("Asia/Tokyo") >= 0)
            } finally {
                fakeTheme.notificationMessages = originalMessages
            }
        }

        function test_weather_temperature_click_toggles_celsius_fahrenheit() {
            var first = content.cityList.itemAtIndex(0)
            var oldPrefs = fakeService.preferenceData
            var oldWeather = fakeService.weather
            fakeService.preferenceData = Object.assign({}, oldPrefs, { units: "C" })
            fakeService.weather = ({ "Paris|Europe/Paris": { c: 20, w: 0, at: 1, lat: 48.85, lon: 2.35 } })
            var temperature = findChild(first, "elsewhen-weather-temperature")
            var control = findChild(first, "elsewhen-weather-temperature-control")
            verify(temperature !== null)
            verify(control !== null)
            try {
                tryCompare(temperature, "visible", true)
                compare(temperature.text, "20°C")
                var point = control.mapToItem(first, 0, 0)
                mouseClick(first, point.x + control.width / 2, point.y + control.height / 2)
                compare(fakeService.preferenceData.units, "F")
                compare(temperature.text, "68°F")
            } finally {
                fakeService.preferenceData = oldPrefs
                fakeService.weather = oldWeather
            }
        }

        function test_world_clock_rows_render() {
            compare(content.cityList.count, 2)
            verify(content.cityList.visible)
        }

        function test_city_row_hover_shows_local_greeting_until_pointer_leaves() {
            var oldNowMs = fakeService.nowMs
            var oldProbe = fakeService.probe
            var row = content.cityList.itemAtIndex(0)
            try {
                mouseMove(testRoot, testRoot.width - 1, testRoot.height - 1)
                fakeService.nowMs = Date.UTC(2024, 2, 20, 8, 0, 0)
                fakeService.probe = Object.assign({}, oldProbe, {
                    "Europe/Paris": { offsetMinutes: 60, abbr: "CET" }
                })
                wait(40)
                var dateLine = findChild(row, "elsewhen-city-date-line")
                var greetingLine = findChild(row, "elsewhen-city-greeting-line")
                verify(dateLine !== null && greetingLine !== null)
                tryVerify(function() { return dateLine.visible })
                tryVerify(function() { return !row.hovered }, 500)
                tryCompare(greetingLine, "visible", false, 500)

                mouseMove(row, row.width / 2, row.height / 2)
                tryCompare(greetingLine, "visible", true, 500)
                tryCompare(dateLine, "visible", false, 500)
                var greeting = findChild(greetingLine, "elsewhen-city-greeting-text")
                verify(greeting !== null)
                compare(greeting.text, "Bonjour")

                mouseMove(testRoot, testRoot.width - 1, testRoot.height - 1)
                tryCompare(dateLine, "visible", true, 500)
                tryCompare(greetingLine, "visible", false, 500)
            } finally {
                mouseMove(testRoot, testRoot.width - 1, testRoot.height - 1)
                fakeService.nowMs = oldNowMs
                fakeService.probe = oldProbe
            }
        }

        function test_city_row_greeting_slot_is_fixed_and_hides_without_ready_probe() {
            var oldNowMs = fakeService.nowMs
            var oldProbe = fakeService.probe
            var oldClockRows = fakeService.clockRows
            var oldPeopleEditIndex = content.peopleEditIndex
            var row = content.cityList.itemAtIndex(0)
            try {
                mouseMove(testRoot, testRoot.width - 1, testRoot.height - 1)
                fakeService.nowMs = Date.UTC(2024, 2, 20, 8, 0, 0)
                fakeService.probe = Object.assign({}, oldProbe, {
                    "Europe/Paris": { offsetMinutes: 60, abbr: "CET" }
                })
                wait(40)
                var slot = findChild(row, "elsewhen-city-date-slot")
                var dateLine = findChild(row, "elsewhen-city-date-line")
                var greetingLine = findChild(row, "elsewhen-city-greeting-line")
                var date = findChild(row, "elsewhen-city-date")
                verify(slot !== null && dateLine !== null && greetingLine !== null && date !== null)
                compare(slot.implicitHeight, dateLine.implicitHeight)
                compare(slot.height, dateLine.implicitHeight)
                compare(dateLine.y, greetingLine.y)
                verify(greetingLine.implicitHeight <= slot.height)
                var slotHeight = slot.height

                mouseMove(row, row.width / 2, row.height / 2)
                tryCompare(greetingLine, "visible", true, 500)
                compare(slot.height, slotHeight)
                compare(slot.implicitHeight, slotHeight)
                content.peopleEditIndex = 0
                verify(!row.greetingVisible)
                verify(!slot.visible)
                content.peopleEditIndex = -1

                fakeService.probe = ({})
                fakeService.clockRows = [
                    { label: "Paris", id: "Europe/Paris", ready: false },
                    { label: "Tokyo", id: "Asia/Tokyo", ready: false }
                ]
                wait(40)
                mouseMove(row, row.width / 2, row.height / 2)
                tryVerify(function() { return row.hovered }, 500)
                compare(row.rowData.ready, false)
                verify(!row.greetingVisible)
                compare(date.text, "…")
            } finally {
                mouseMove(testRoot, testRoot.width - 1, testRoot.height - 1)
                content.peopleEditIndex = oldPeopleEditIndex
                fakeService.nowMs = oldNowMs
                fakeService.probe = oldProbe
                fakeService.clockRows = oldClockRows
            }
        }

        function test_weather_temperature_is_city_specific_and_uses_units() {
            fakeService.weather = ({
                "Paris|Europe/Paris": { c: 20, w: 0, at: 1, lat: 48.85, lon: 2.35 },
                "Tokyo|Asia/Tokyo": { c: 10, w: 3, at: 1, lat: 35.68, lon: 139.69 }
            })
            fakeService.preferenceData = ({ hour24: false, globeEnabled: true, smoothMotion: true, units: "C" })
            compare(content.temperatureFor(fakeService.cities[0]), "20°C")
            compare(content.temperatureFor(fakeService.cities[1]), "10°C")
            fakeService.preferenceData = ({ hour24: false, globeEnabled: true, smoothMotion: true, units: "F" })
            compare(content.temperatureFor(fakeService.cities[0]), "68°F")
            fakeService.weather = ({})
            fakeService.preferenceData = ({ hour24: false, globeEnabled: true, smoothMotion: true })
        }

        function test_city_list_expands_into_parent_scroll_flow() {
            var original = fakeService.cities
            var originalTarget = content.timezoneTarget
            var originalContentY = content.scrollArea.contentY
            var many = []
            for (var i = 0; i < 8; i++) many.push({ label: "City " + i, id: "Etc/GMT" })
            try {
                fakeService.cities = many
                tryCompare(content.cityList, "count", 8)
                verify(content.cityList.height > 144)
                compare(content.cityList.height, content.cityList.contentHeight)
                tryVerify(function() { return content.scrollArea.contentHeight > content.scrollArea.height }, 500)
                var last = content.cityList.itemAtIndex(7)
                verify(last !== null)
                var maxScroll = content.scrollArea.contentHeight - content.scrollArea.height
                verify(maxScroll > 0)
                content.scrollArea.contentY = maxScroll
                wait(50)
                var lastPoint = last.mapToItem(content.scrollArea, 24, 27)
                verify(lastPoint.y >= 0 && lastPoint.y + 40 <= content.scrollArea.height)
                mouseClick(last, 24, 27, Qt.LeftButton)
                compare(content.timezoneTarget, "Etc/GMT")
            } finally {
                fakeService.cities = original
                content.timezoneTarget = originalTarget
                content.scrollArea.contentY = originalContentY
            }
        }

        function test_city_row_controls_route_remove_and_reorder() {
            var originalCities = fakeService.cities
            var originalClockRows = fakeService.clockRows
            try {
                fakeService.moveRequests = 0
                fakeService.cityRemoves = 0
                var second = content.cityList.itemAtIndex(1)
                mouseMove(second, 30, 30)
                wait(40)
                verify(second.moveUpButton.visible)
                mouseClick(second.moveUpButton, second.moveUpButton.width / 2, second.moveUpButton.height / 2)
                compare(fakeService.moveRequests, 1)
                var first = content.cityList.itemAtIndex(0)
                mouseMove(first, 30, 30)
                wait(40)
                verify(first.removeButton.visible)
                mouseClick(first.removeButton, first.removeButton.width / 2, first.removeButton.height / 2)
                compare(fakeService.cityRemoves, 1)
            } finally {
                fakeService.cities = originalCities
                fakeService.clockRows = originalClockRows
            }
        }

        function test_row_drag_requests_service_reorder() {
            fakeService.moveRequests = 0
            var first = content.cityList.itemAtIndex(0)
            verify(first !== null)
            verify(first.dragArea !== null)
            mouseDrag(first.dragArea, 30, 30, 0, 104, Qt.LeftButton)
            compare(fakeService.moveRequests, 1)
        }

        function test_globe_catalog_city_click_sets_home_without_adding_a_clock_row() {
            var oldCityData = fakeService.cityData
            var oldLocalZone = fakeService.localZone
            var oldPreferenceData = fakeService.preferenceData
            var oldCities = fakeService.cities
            var oldRows = fakeService.clockRows
            var oldSelection = content.globeSelectionKey
            var oldSelectionLabel = content.globeSelectionLabel
            var oldTarget = content.timezoneTarget
            var oldFocus = content.keyboardFocusKey
            var oldSpin = content.globeSpin
            var oldViewLat = content.globeViewLat
            fakeService.cityData = oldCityData.concat([
                ["Cebu", "Asia/Manila", 10.3157, 123.8854, 1],
                ["Cébu", "Asia/Manila", 10.3157, 123.8854, 1]
            ])
            fakeService.localZone = "Asia/Manila"
            fakeService.preferenceData = Object.assign({}, oldPreferenceData, {
                here: { name: "Existing home", zone: "Asia/Manila", lat: -30, lon: 0 }
            })
            try {
                var city = { label: "Cebu", id: "Asia/Manila", lat: 10.3157, lon: 123.8854 }
                content.globeSpin = city.lon
                content.globeViewLat = 0
                var radius = content.globePaintRadius(content.globeCanvas.width, content.globeCanvas.height)
                var marker = Globe.project(city.lat, city.lon, content.globeSpin, content.globeViewLat, radius)
                verify(marker.visible)
                var point = content.globeCanvas.mapToItem(content.globeDragArea,
                    content.globeCanvas.width / 2 + marker.x,
                    content.globeCanvas.height / 2 + marker.y)
                mouseClick(content.globeDragArea, point.x, point.y, Qt.LeftButton)
                verify(content.globeFooterPlace !== null)
                compare(content.globeFooterPlace.label, "Cebu")
                compare(content.globeSelectionLabel, "Cebu")
                compare(content.timezoneTarget, "Asia/Manila")
                compare(fakeService.preferenceData.here.name, "Cebu")
                compare(fakeService.cities.length, oldCities.length)
                wait(400)
            } finally {
                fakeService.cityData = oldCityData
                fakeService.localZone = oldLocalZone
                fakeService.preferenceData = oldPreferenceData
                fakeService.cities = oldCities
                fakeService.clockRows = oldRows
                content.globeSelectionKey = oldSelection
                content.globeSelectionLabel = oldSelectionLabel
                content.timezoneTarget = oldTarget
                content.keyboardFocusKey = oldFocus
                content.globeSpin = oldSpin
                content.globeViewLat = oldViewLat
            }
        }

        function test_globe_marker_click_selects_city_and_sets_local_home() {
            var oldPreferenceData = fakeService.preferenceData
            var oldLocalZone = fakeService.localZone
            var oldCities = fakeService.cities
            var oldClockRows = fakeService.clockRows
            var oldFocus = content.keyboardFocusId
            var oldFocusKey = content.keyboardFocusKey
            var oldTarget = content.timezoneTarget
            var oldSpin = content.globeSpin
            var oldViewLat = content.globeViewLat
            fakeService.localZone = "Asia/Manila"
            fakeService.cities = [{ label: "Cebu", id: "Asia/Manila", lat: 10.3157, lon: 123.8854 }]
            fakeService.clockRows = [{ label: "Cebu", id: "Asia/Manila", time: "13:00", offset: "UTC+8", abbr: "PHT", ready: true, offsetMinutes: 480, progress: 0.5, lit: true }]
            fakeService.preferenceData = Object.assign({}, oldPreferenceData)
            try {
                var city = fakeService.cities[0]
                var place = content.placeForCity(city)
                content.globeSpin = city.lon
                content.globeViewLat = 0
                var radius = content.globePaintRadius(content.globeCanvas.width, content.globeCanvas.height)
                var marker = Globe.project(place.lat, place.lon, content.globeSpin, content.globeViewLat, radius)
                verify(marker.visible)
                var point = content.globeCanvas.mapToItem(content.globeDragArea,
                    content.globeCanvas.width / 2 + marker.x,
                    content.globeCanvas.height / 2 + marker.y)
                mouseClick(content.globeDragArea, point.x, point.y, Qt.LeftButton)
                compare(content.keyboardFocusId, "Asia/Manila")
                compare(content.timezoneTarget, "Asia/Manila")
                compare(fakeService.preferenceData.here.name, "Cebu")
                tryVerify(function() { return Math.abs(content.globeSpin - 123.8854) < 0.5 }, 900)
                tryVerify(function() { return Math.abs(content.globeViewLat - 10.3157) < 0.5 }, 900)
                var hereLabel = findChild(content, "elsewhen-here-city")
                verify(hereLabel !== null)
                tryCompare(hereLabel, "text", "It's 12:00 PM here in Cebu")
                wait(400)
            } finally {
                fakeService.localZone = oldLocalZone
                fakeService.cities = oldCities
                fakeService.clockRows = oldClockRows
                fakeService.preferenceData = oldPreferenceData
                content.keyboardFocusId = oldFocus
                content.keyboardFocusKey = oldFocusKey
                content.timezoneTarget = oldTarget
                content.globeSpin = oldSpin
                content.globeViewLat = oldViewLat
            }
        }

        function test_here_caption_arcs_local_time_and_world_clock_title() {
            var oldNowMs = fakeService.nowMs
            var oldOffset = fakeService.localOffsetMinutes
            var oldPreferences = fakeService.preferenceData
            try {
                fakeService.nowMs = Date.UTC(2024, 2, 20, 12, 0, 0)
                fakeService.localOffsetMinutes = 0
                fakeService.preferenceData = Object.assign({}, oldPreferences, { hour24: false })
                var caption = findChild(content, "elsewhen-here-city")
                verify(caption !== null)
                compare(caption.text, "It's 12:00 PM here")
                compare(caption.flat, false)
                compare(caption.pixelSize, 10)
                compare(caption.color, Qt.darker(fakeTheme.ink, 1.55))
                verify(caption.width > 0 && caption.height > 0)
                var worldTitle = findChild(content, "elsewhen-world-title")
                var clockTitle = findChild(content, "elsewhen-clock-title")
                verify(worldTitle !== null && clockTitle !== null)
                var titleLeft = worldTitle.mapToItem(content, 0, 0).x
                var titleRight = clockTitle.mapToItem(content, clockTitle.width, 0).x
                verify(Math.abs((titleLeft + titleRight) / 2 - content.width / 2) < 1)
                verify(Math.abs(caption.mapToItem(content, caption.width / 2, 0).x - content.width / 2) < 1)
                verify(caption.glyphs.length === caption.text.length && caption.placed.width > 0)
                var firstGlyph = findChild(caption, "elsewhen-arc-glyph")
                verify(firstGlyph !== null && firstGlyph.width > 0 && firstGlyph.height > 0)
                verify(findChild(content, "elsewhen-world-title") !== null)
                verify(findChild(content, "elsewhen-clock-title") !== null)
            } finally {
                fakeService.nowMs = oldNowMs
                fakeService.localOffsetMinutes = oldOffset
                fakeService.preferenceData = oldPreferences
            }
        }

        function test_header_centering_keeps_title_and_caption_clear_of_refresh_when_narrow() {
            var oldWidth = testRoot.width
            try {
                testRoot.width = 260
                wait(80)
                var header = findChild(content, "elsewhen-world-clock-header")
                var worldTitle = findChild(content, "elsewhen-world-title")
                var clockTitle = findChild(content, "elsewhen-clock-title")
                var caption = findChild(content, "elsewhen-here-city")
                verify(header !== null && worldTitle !== null && clockTitle !== null && caption !== null)
                compare(header.width, content.width)
                var titleLeft = worldTitle.mapToItem(content, 0, 0).x
                var titleRight = clockTitle.mapToItem(content, clockTitle.width, 0).x
                var titleTop = worldTitle.mapToItem(content, 0, 0).y
                var titleBottom = clockTitle.mapToItem(content, clockTitle.width, clockTitle.height).y
                var refreshBox = content.refreshButton.mapToItem(content, 0, 0)
                var titleOverlapsRefresh = titleRight > refreshBox.x
                    && titleLeft < refreshBox.x + content.refreshButton.width
                    && titleBottom > refreshBox.y
                    && titleTop < refreshBox.y + content.refreshButton.height
                verify(Math.abs((titleLeft + titleRight) / 2 - content.width / 2) < 1)
                verify(!titleOverlapsRefresh)
                var captionLeft = caption.mapToItem(content, 0, 0).x
                var captionTop = caption.mapToItem(content, 0, 0).y
                var captionBottom = caption.mapToItem(content, caption.width, caption.height).y
                var captionOverlapsRefresh = captionLeft + caption.width > refreshBox.x
                    && captionLeft < refreshBox.x + content.refreshButton.width
                    && captionBottom > refreshBox.y
                    && captionTop < refreshBox.y + content.refreshButton.height
                verify(!captionOverlapsRefresh)
            } finally {
                testRoot.width = oldWidth
            }
        }

        function test_header_compact_layout_switches_at_intrinsic_width_boundary() {
            var oldWidth = testRoot.width
            const header = findChild(content, "elsewhen-world-clock-header")
            verify(header !== null)
            const oldHeaderWidth = header.width
            try {
                testRoot.width = 800
                wait(80)
                const titleRow = findChild(header, "elsewhen-world-title-row")
                verify(titleRow !== null)
                if (titleRow === null) return
                const requiredWidth = titleRow.implicitWidth + 2 * (content.refreshButton.width + 8)
                verify(header.width > requiredWidth)

                testRoot.width += requiredWidth - 1 - header.width
                tryCompare(header, "width", requiredWidth - 1, 1000)
                tryCompare(header, "compactLayout", true, 1000)
                testRoot.width += requiredWidth + 1 - header.width
                tryCompare(header, "width", requiredWidth + 1, 1000)
                tryCompare(header, "compactLayout", false, 1000)
            } finally {
                testRoot.width = oldWidth
                tryCompare(header, "width", oldHeaderWidth, 1000)
            }
        }

        function test_header_extremely_narrow_keeps_title_inside_header() {
            var oldWidth = testRoot.width
            const header = findChild(content, "elsewhen-world-clock-header")
            verify(header !== null)
            const oldHeaderWidth = header.width
            try {
                testRoot.width = 140
                wait(80)
                const titleRow = findChild(header, "elsewhen-world-title-row")
                const worldTitle = findChild(content, "elsewhen-world-title")
                const clockTitle = findChild(content, "elsewhen-clock-title")
                verify(titleRow !== null && worldTitle !== null && clockTitle !== null)
                if (titleRow === null) return
                verify(header.compactLayout)
                const contentBox = content.mapToItem(testRoot, 0, 0)
                const titleBox = titleRow.mapToItem(testRoot, 0, 0)
                verify(titleRow.width > 0)
                verify(titleRow.width <= content.width)
                verify(titleBox.x >= contentBox.x)
                verify(titleBox.x + titleRow.width <= contentBox.x + content.width)
                const titleTop = titleRow.mapToItem(content, 0, 0).y
                const refreshBox = content.refreshButton.mapToItem(content, 0, 0)
                verify(titleTop >= refreshBox.y + content.refreshButton.height)
                verify(worldTitle.width > 0 && clockTitle.width > 0)
            } finally {
                testRoot.width = oldWidth
                tryCompare(header, "width", oldHeaderWidth, 1000)
            }
        }

        function test_arc_caption_falls_back_to_shaped_complex_text() {
            var caption = findChild(content, "elsewhen-here-city")
            verify(caption !== null)
            try {
                caption.text = "العربية"
                compare(caption.flat, true)
                compare(caption.glyphs.length, 0)
                var shapedText = findChild(caption, "elsewhen-arc-flat-text")
                verify(shapedText !== null && shapedText.visible)
                compare(shapedText.text, caption.text)
            } finally {
                caption.text = Qt.binding(function() { return content.hereLine })
            }
        }

        function test_arc_caption_falls_back_for_extended_marks_and_joiners() {
            var caption = findChild(content, "elsewhen-here-city")
            verify(caption !== null)
            var complexTexts = ["a\u0301", "a\u1AB0", "a\u20D0", "\u2764\uFE0F", "A\u200D", "\uD83D\uDC69\u200D\uD83D\uDCBB"]
            try {
                for (var i = 0; i < complexTexts.length; i++) {
                    caption.text = complexTexts[i]
                    verify(caption.flat)
                    compare(caption.glyphs.length, 0)
                    var shapedText = findChild(caption, "elsewhen-arc-flat-text")
                    verify(shapedText !== null && shapedText.visible)
                    compare(shapedText.text, complexTexts[i])
                }
            } finally {
                caption.text = Qt.binding(function() { return content.hereLine })
            }
        }

        function test_here_caption_action_exposes_accessible_name_and_role() {
            var captionButton = findChild(content, "elsewhen-here-search-button")
            var oldFocusId = content.keyboardFocusId
            var oldFocusKey = content.keyboardFocusKey
            var oldSearchMode = content.searchMode
            try {
                content.keyboardFocusId = ""
                content.keyboardFocusKey = ""
                content.searchMode = ""
                verify(captionButton !== null)
                compare(captionButton.Accessible.role, Accessible.Button)
                compare(captionButton.Accessible.name, "Choose home time zone")
                content.keyboardFocusId = "Asia/Tokyo"
                compare(captionButton.Accessible.name, "Return to home time zone")
                content.keyboardFocusId = ""
                content.searchMode = "here"
                compare(captionButton.Accessible.name, "Cancel choosing home time zone")
            } finally {
                content.keyboardFocusId = oldFocusId
                content.keyboardFocusKey = oldFocusKey
                content.searchMode = oldSearchMode
            }
        }

        function test_here_caption_action_activates_with_keyboard() {
            var captionButton = findChild(content, "elsewhen-here-search-button")
            verify(captionButton !== null && captionButton.enabled)
            content.searchMode = ""
            content.searchText = ""
            content.keyboardFocusId = ""
            content.keyboardFocusKey = ""
            content.globeExpanded = false
            captionButton.forceActiveFocus()
            keyClick(Qt.Key_Return)
            compare(content.searchMode, "here")
            content.searchMode = ""
            captionButton.forceActiveFocus()
            keyClick(Qt.Key_Space)
            compare(content.searchMode, "here")
            content.searchMode = ""
            content.forceActiveFocus()
        }

        function test_here_caption_tracks_scrubbed_time_and_delta() {
            var oldNowMs = fakeService.nowMs
            var oldOffset = fakeService.localOffsetMinutes
            var oldPreferences = fakeService.preferenceData
            var oldScrub = content.scrubMinutes
            try {
                fakeService.nowMs = Date.UTC(2024, 2, 20, 12, 0, 0)
                fakeService.localOffsetMinutes = 0
                fakeService.preferenceData = Object.assign({}, oldPreferences, { hour24: false })
                content.scrubMinutes = 180
                var caption = findChild(content, "elsewhen-here-city")
                verify(caption !== null)
                compare(caption.text, "It's 3:00 PM here  +3h")
                compare(caption.color, fakeTheme.accent)
            } finally {
                fakeService.nowMs = oldNowMs
                fakeService.localOffsetMinutes = oldOffset
                fakeService.preferenceData = oldPreferences
                content.scrubMinutes = oldScrub
            }
        }

        function test_here_caption_returns_home_focus_from_expanded_globe() {
            var oldLocalZone = fakeService.localZone
            var oldCityData = fakeService.cityData
            var oldPreferences = fakeService.preferenceData
            var oldFocusId = content.keyboardFocusId
            var oldFocusKey = content.keyboardFocusKey
            var oldTarget = content.timezoneTarget
            var oldSelectionKey = content.globeSelectionKey
            var oldSelectionLabel = content.globeSelectionLabel
            var oldSelectionZone = content.globeSelectionZone
            var oldExpanded = content.globeExpanded
            try {
                fakeService.localZone = "Asia/Manila"
                fakeService.cityData = oldCityData.concat([["Cebu", "Asia/Manila", 10.3157, 123.8854, 1]])
                fakeService.preferenceData = Object.assign({}, oldPreferences, {
                    here: { name: "Cebu", zone: "Asia/Manila", lat: 10.3157, lon: 123.8854 }
                })
                content.keyboardFocusId = "Asia/Tokyo"
                content.keyboardFocusKey = "focused-city"
                content.timezoneTarget = "Asia/Tokyo"
                content.globeSelectionKey = "tokyo|Asia/Tokyo"
                content.globeSelectionLabel = "Tokyo"
                content.globeSelectionZone = "Asia/Tokyo"
                content.globeExpanded = true
                var captionButton = findChild(content, "elsewhen-here-search-button")
                verify(captionButton !== null && captionButton.enabled)
                mouseClick(captionButton, captionButton.width / 2, captionButton.height / 2)
                compare(content.keyboardFocusId, "")
                compare(content.keyboardFocusKey, "")
                compare(content.timezoneTarget, fakeService.localZone)
                compare(content.globeSelectionZone, fakeService.localZone)
                compare(content.globeSelectionLabel, content.hereZone.label)
                compare(content.searchMode, "")
            } finally {
                fakeService.localZone = oldLocalZone
                fakeService.cityData = oldCityData
                fakeService.preferenceData = oldPreferences
                content.keyboardFocusId = oldFocusId
                content.keyboardFocusKey = oldFocusKey
                content.timezoneTarget = oldTarget
                content.globeSelectionKey = oldSelectionKey
                content.globeSelectionLabel = oldSelectionLabel
                content.globeSelectionZone = oldSelectionZone
                content.globeExpanded = oldExpanded
            }
        }

        function test_here_caption_keeps_focus_when_home_place_cannot_be_resolved() {
            var oldLocalZone = fakeService.localZone
            var oldCityData = fakeService.cityData
            var oldFocusId = content.keyboardFocusId
            var oldFocusKey = content.keyboardFocusKey
            var oldTarget = content.timezoneTarget
            var oldSelectionKey = content.globeSelectionKey
            var oldSelectionLabel = content.globeSelectionLabel
            var oldSelectionZone = content.globeSelectionZone
            var oldExpanded = content.globeExpanded
            try {
                fakeService.localZone = "Etc/Unavailable"
                fakeService.cityData = []
                content.keyboardFocusId = "Asia/Tokyo"
                content.keyboardFocusKey = "focused-city"
                content.timezoneTarget = "Asia/Tokyo"
                content.globeSelectionKey = "tokyo|Asia/Tokyo"
                content.globeSelectionLabel = "Tokyo"
                content.globeSelectionZone = "Asia/Tokyo"
                content.globeExpanded = true
                var captionButton = findChild(content, "elsewhen-here-search-button")
                verify(captionButton !== null && captionButton.enabled)
                mouseClick(captionButton, captionButton.width / 2, captionButton.height / 2)
                compare(content.keyboardFocusId, "Asia/Tokyo")
                compare(content.keyboardFocusKey, "focused-city")
                compare(content.timezoneTarget, "Asia/Tokyo")
                compare(content.globeSelectionZone, "Asia/Tokyo")
            } finally {
                fakeService.localZone = oldLocalZone
                fakeService.cityData = oldCityData
                content.keyboardFocusId = oldFocusId
                content.keyboardFocusKey = oldFocusKey
                content.timezoneTarget = oldTarget
                content.globeSelectionKey = oldSelectionKey
                content.globeSelectionLabel = oldSelectionLabel
                content.globeSelectionZone = oldSelectionZone
                content.globeExpanded = oldExpanded
            }
        }

        function test_city_click_focuses_city_and_rotates_globe_without_drag() {
            var second = content.cityList.itemAtIndex(1)
            verify(second !== null)
            var previousTarget = content.timezoneTarget
            var previousFocusId = content.keyboardFocusId
            var previousSpin = content.globeSpin
            var previousViewLat = content.globeViewLat
            try {
                compare(previousTarget, "Europe/Paris")
                fakeService.moveRequests = 0
                mouseClick(second, 24, 27, Qt.LeftButton)
                compare(content.timezoneTarget, "Asia/Tokyo")
                compare(content.keyboardFocusId, "Asia/Tokyo")
                compare(second.keyboardFocused, true)
                tryVerify(function() { return Math.abs(content.globeSpin - 139.69) < 0.5 }, 800)
                tryVerify(function() { return Math.abs(content.globeViewLat - 35.68) < 0.5 }, 800)
                wait(400)
                compare(content.draggingCityIndex, -1)
                compare(fakeService.moveRequests, 0)
            } finally {
                content.timezoneTarget = previousTarget
                content.keyboardFocusId = previousFocusId
                content.globeSpin = previousSpin
                content.globeViewLat = previousViewLat
            }
        }

        function test_people_profile_enrichment_renders_name_and_initial_avatar() {
            var oldCities = fakeService.cities
            var oldProfiles = fakeService.profiles
            var oldStamp = fakeService.profileStamp
            try {
                fakeService.cities = [
                    Object.assign({}, oldCities[0], { people: ["@alice"] }), oldCities[1]
                ]
                fakeService.profiles = {
                    alice: { login: "alice", name: "Alice Example", avatar: "" }
                }
                fakeService.profileStamp = 1234
                tryCompare(content.cityList, "count", 2)
                var row = content.cityList.itemAtIndex(0)
                verify(row !== null)
                var names = findChild(row, "elsewhen-people-names")
                verify(names !== null)
                compare(names.text, "Alice Example")
                var avatar = findChild(row, "elsewhen-person-avatar")
                verify(avatar !== null)
                compare(avatar.name, "Alice Example")
                verify(!avatar.pictured)
                var initial = findChild(avatar, "elsewhen-person-avatar-initial")
                verify(initial !== null)
                compare(initial.text, "A")
            } finally {
                fakeService.cities = oldCities
                fakeService.profiles = oldProfiles
                fakeService.profileStamp = oldStamp
            }
        }

        function test_people_notes_persist_through_city_row() {
            var first = content.cityList.itemAtIndex(0)
            verify(first !== null)
            mouseMove(first, first.width / 2, first.height / 2)
            wait(40)
            var editButton = findChild(first, "elsewhen-people-edit")
            verify(editButton !== null)
            verify(editButton.visible)
            mouseClick(editButton, editButton.width / 2, editButton.height / 2)
            tryCompare(content, "peopleEditIndex", 0)
            var field = findChild(first, "elsewhen-people-field")
            verify(field !== null)
            tryCompare(field, "visible", true)
            tryCompare(field, "activeFocus", true)
            compare(field.text, "Alice")
            field.text = "Alice, Bob"
            keyClick(Qt.Key_Return)
            tryCompare(content, "peopleEditIndex", -1)
            compare(JSON.stringify(fakeService.cities[0].people), JSON.stringify(["Alice", "Bob"]))
        }

        function test_refresh_button_reaches_service() {
            fakeService.refreshRequests = 0
            mouseClick(content.refreshButton, content.refreshButton.width / 2, content.refreshButton.height / 2)
            compare(fakeService.refreshRequests, 1)
        }

        function test_keyboard_r_triggers_refresh() {
            fakeService.refreshRequests = 0
            content.forceActiveFocus()
            keyClick(Qt.Key_R)
            compare(fakeService.refreshRequests, 1)
        }

        function test_keyboard_t_and_shift_t_toggle_hour24_and_alt_t_toggle_units() {
            fakeService.preferenceData = Object.assign({}, fakeService.preferenceData, { hour24: false, units: "C" })
            fakeService.settingsWrites = 0
            content.forceActiveFocus()
            keyClick(Qt.Key_T)
            compare(fakeService.preferenceData.hour24, true)
            compare(fakeService.settingsWrites, 1)
            keyClick(Qt.Key_T, Qt.ShiftModifier)
            compare(fakeService.preferenceData.hour24, false)
            compare(fakeService.settingsWrites, 2)
            keyClick(Qt.Key_T, Qt.AltModifier)
            compare(fakeService.preferenceData.units, "F")
            compare(fakeService.settingsWrites, 3)
        }

        function test_keyboard_a_focuses_search() {
            content.forceActiveFocus()
            keyClick(Qt.Key_A)
            verify(content.zoneSearchInput.activeFocus)
        }

        function test_keyboard_plus_focuses_search() {
            content.forceActiveFocus()
            keyClick(Qt.Key_Plus)
            verify(content.zoneSearchInput.activeFocus)
        }

        function test_keyboard_shifted_equal_focuses_search() {
            content.forceActiveFocus()
            keyClick(Qt.Key_Equal, Qt.ShiftModifier)
            verify(content.zoneSearchInput.activeFocus)
        }

        function test_search_field_keeps_r_for_text() {
            fakeService.refreshRequests = 0
            content.zoneSearchInput.text = ""
            content.zoneSearchInput.forceActiveFocus()
            keyClick(Qt.Key_R)
            compare(content.zoneSearchInput.text, "r")
            compare(fakeService.refreshRequests, 0)
        }

        function test_search_keyboard_selects_the_highlighted_result() {
            var oldResults = fakeService.searchPlaceResults
            var oldAdds = fakeService.cityAdds
            var oldMode = content.searchMode
            var oldText = content.zoneSearchInput.text
            fakeService.searchPlaceResults = [
                { label: "Santiago", value: "America/Santiago", lat: -33.4489, lon: -70.6693 },
                { label: "Salvador", value: "America/Bahia", lat: -12.9714, lon: -38.5014 }
            ]
            content.startAddSearch()
            content.zoneSearchInput.text = "S"
            try {
                compare(content.searchResults.length, 2)
                keyClick(Qt.Key_Down)
                keyClick(Qt.Key_Return)
                compare(fakeService.cityAdds, oldAdds + 1)
                compare(fakeService.lastAddedPlace.lat, -12.9714)
                compare(content.searchMode, "")
            } finally {
                fakeService.searchPlaceResults = oldResults
                fakeService.cityAdds = oldAdds
                content.searchMode = oldMode
                content.zoneSearchInput.text = oldText
            }
        }

        function test_add_button_uses_highlighted_search_result() {
            var oldResults = fakeService.searchPlaceResults
            var oldAdds = fakeService.cityAdds
            var oldMode = content.searchMode
            var oldText = content.zoneSearchInput.text
            fakeService.searchPlaceResults = [
                { label: "Santiago", value: "America/Santiago", lat: -33.4489, lon: -70.6693 },
                { label: "Salvador", value: "America/Bahia", lat: -12.9714, lon: -38.5014 }
            ]
            content.startAddSearch()
            content.zoneSearchInput.text = "S"
            try {
                compare(content.searchResults.length, 2)
                keyClick(Qt.Key_Down)
                compare(content.searchSelectionIndex, 1)
                var point = content.addZoneButton.mapToItem(testRoot, 0, 0)
                mouseClick(testRoot, point.x + content.addZoneButton.width / 2,
                    point.y + content.addZoneButton.height / 2)
                compare(fakeService.cityAdds, oldAdds + 1)
                compare(fakeService.lastAddedPlace.lat, -12.9714)
            } finally {
                fakeService.searchPlaceResults = oldResults
                fakeService.cityAdds = oldAdds
                content.searchMode = oldMode
                content.zoneSearchInput.text = oldText
                content.searchSelectionIndex = 0
            }
        }

        function test_here_button_uses_highlighted_search_result() {
            var oldResults = fakeService.searchPlaceResults
            var oldMode = content.searchMode
            var oldText = content.zoneSearchInput.text
            var oldRequests = fakeService.timezoneRequests
            var oldHere = fakeService.pendingTimezoneHere
            fakeService.searchPlaceResults = [
                { label: "Santiago", value: "America/Santiago", lat: -33.4489, lon: -70.6693 },
                { label: "Salvador", value: "America/Bahia", lat: -12.9714, lon: -38.5014 }
            ]
            content.startHereSearch()
            content.zoneSearchInput.text = "S"
            try {
                compare(content.searchResults.length, 2)
                keyClick(Qt.Key_Down)
                compare(content.searchSelectionIndex, 1)
                var point = content.addZoneButton.mapToItem(testRoot, 0, 0)
                mouseClick(testRoot, point.x + content.addZoneButton.width / 2,
                    point.y + content.addZoneButton.height / 2)
                compare(fakeService.timezoneRequests, oldRequests + 1)
                compare(fakeService.pendingTimezoneHere.name, "Salvador")
                compare(fakeService.pendingTimezoneHere.lat, -12.9714)
            } finally {
                fakeService.searchPlaceResults = oldResults
                fakeService.timezoneRequests = oldRequests
                fakeService.pendingTimezoneHere = oldHere
                content.searchMode = oldMode
                content.zoneSearchInput.text = oldText
                content.searchSelectionIndex = 0
            }
        }

        function test_jump_button_uses_highlighted_search_result() {
            var oldResults = fakeService.searchPlaceResults
            var oldCities = fakeService.cities
            var oldPreferences = fakeService.preferenceData
            var oldSessionCities = content.globeSessionCities
            var oldExpanded = content.globeExpanded
            var oldMode = content.searchMode
            var oldSpin = content.globeSpin
            var oldViewLat = content.globeViewLat
            fakeService.searchPlaceResults = [
                { label: "Santiago", value: "America/Santiago", lat: -33.4489, lon: -70.6693 },
                { label: "Salvador", value: "America/Bahia", lat: -12.9714, lon: -38.5014 }
            ]
            content.globeExpanded = true
            content.globeSpin = 0
            content.globeViewLat = 0
            content.startJumpSearch()
            content.zoneSearchInput.text = "S"
            try {
                compare(content.searchResults.length, 2)
                keyClick(Qt.Key_Down)
                compare(content.searchSelectionIndex, 1)
                var point = content.addZoneButton.mapToItem(testRoot, 0, 0)
                mouseClick(testRoot, point.x + content.addZoneButton.width / 2,
                    point.y + content.addZoneButton.height / 2)
                compare(content.globeSelectionLabel, "Salvador")
                compare(content.globeSessionCities.length, 1)
                compare(content.globeSessionCities[0].label, "Salvador")
                compare(fakeService.cities.length, oldCities.length)
                compare(fakeService.preferenceData, oldPreferences)
                wait(400)
            } finally {
                fakeService.searchPlaceResults = oldResults
                fakeService.cities = oldCities
                fakeService.preferenceData = oldPreferences
                content.globeSessionCities = oldSessionCities
                content.globeExpanded = oldExpanded
                content.searchMode = oldMode
                content.globeSpin = oldSpin
                content.globeViewLat = oldViewLat
                content.zoneSearchInput.text = ""
                content.searchSelectionIndex = 0
            }
        }

        function test_search_field_arrow_does_not_change_city_focus() {
            var originalTarget = content.timezoneTarget
            var originalFocusId = content.keyboardFocusId
            try {
                content.timezoneTarget = "Europe/Paris"
                content.keyboardFocusId = ""
                content.zoneSearchInput.forceActiveFocus()
                keyClick(Qt.Key_Down)
                compare(content.timezoneTarget, "Europe/Paris")
            } finally {
                content.timezoneTarget = originalTarget
                content.keyboardFocusId = originalFocusId
            }
        }

        function test_keyboard_p_edits_selected_city_people() {
            var originalTarget = content.timezoneTarget
            var originalFocusId = content.keyboardFocusId
            var originalPeopleIndex = content.peopleEditIndex
            try {
                content.timezoneTarget = "Europe/Paris"
                content.keyboardFocusId = ""
                content.peopleEditIndex = -1
                content.forceActiveFocus()
                keyClick(Qt.Key_P)
                compare(content.peopleEditIndex, 0)
                content.peopleEditIndex = -1
                content.forceActiveFocus()
                keyClick(Qt.Key_P, Qt.ShiftModifier)
                compare(content.peopleEditIndex, 0)
            } finally {
                content.timezoneTarget = originalTarget
                content.keyboardFocusId = originalFocusId
                content.peopleEditIndex = originalPeopleIndex
            }
        }

        function test_escape_in_people_editor_cancels_without_closing_panel() {
            fakeTheme.elsewhenVisible = true
            content.peopleEditIndex = -1
            content.startPeopleEdit(0)
            var first = content.cityList.itemAtIndex(0)
            var field = findChild(first, "elsewhen-people-field")
            verify(field !== null)
            tryCompare(field, "activeFocus", true)
            keyClick(Qt.Key_Escape)
            tryCompare(content, "peopleEditIndex", -1)
            compare(fakeTheme.elsewhenVisible, true)
        }

        function test_keyboard_j_and_k_navigate_cities() {
            var originalTarget = content.timezoneTarget
            var originalFocusId = content.keyboardFocusId
            try {
                content.timezoneTarget = "Europe/Paris"
                content.keyboardFocusId = ""
                content.forceActiveFocus()
                keyClick(Qt.Key_J)
                compare(content.timezoneTarget, "Asia/Tokyo")
                keyClick(Qt.Key_K)
                compare(content.timezoneTarget, "Europe/Paris")
            } finally {
                content.timezoneTarget = originalTarget
                content.keyboardFocusId = originalFocusId
            }
        }

        function test_keyboard_j_starts_jump_search_on_expanded_globe() {
            var oldExpanded = content.globeExpanded
            var oldMode = content.searchMode
            try {
                content.globeExpanded = true
                content.searchMode = ""
                content.zoneSearchInput.focus = false
                content.forceActiveFocus()
                keyClick(Qt.Key_J)
                compare(content.searchMode, "jump")
                verify(content.zoneSearchInput.activeFocus)
            } finally {
                content.globeExpanded = oldExpanded
                content.searchMode = oldMode
                content.zoneSearchInput.focus = false
            }
        }

        function test_keyboard_delete_targets_the_focused_city_when_timezones_repeat() {
            var originalCities = fakeService.cities
            var originalClockRows = fakeService.clockRows
            var originalTarget = content.timezoneTarget
            var originalFocusId = content.keyboardFocusId
            var originalRemoves = fakeService.cityRemoves
            try {
                fakeService.cityRemoves = 0
                fakeService.cities = [
                    { label: "Springfield, Illinois", id: "America/Chicago" },
                    { label: "Springfield, Missouri", id: "America/Chicago" }
                ]
                fakeService.clockRows = [
                    { label: "Springfield, Illinois", id: "America/Chicago", ready: true },
                    { label: "Springfield, Missouri", id: "America/Chicago", ready: true }
                ]
                content.timezoneTarget = "America/Chicago"
                content.keyboardFocusId = ""
                content.focusCity(1)
                content.forceActiveFocus()
                keyClick(Qt.Key_X)
                compare(fakeService.cityRemoves, 1)
                compare(fakeService.cities.length, 1)
                compare(fakeService.cities[0].label, "Springfield, Illinois")
            } finally {
                fakeService.cities = originalCities
                fakeService.clockRows = originalClockRows
                content.timezoneTarget = originalTarget
                content.keyboardFocusId = originalFocusId
                fakeService.cityRemoves = originalRemoves
            }
        }

        function test_keyboard_down_focuses_next_city() {
            var originalTarget = content.timezoneTarget
            var originalFocusId = content.keyboardFocusId
            var originalContentY = content.scrollArea.contentY
            try {
                content.keyboardFocusId = ""
                content.timezoneTarget = "Europe/Paris"
                content.forceActiveFocus()
                keyClick(Qt.Key_Down)
                compare(content.timezoneTarget, "Asia/Tokyo")
                compare(content.cityList.itemAtIndex(1).border.color, fakeTheme.seal)
            } finally {
                content.keyboardFocusId = originalFocusId
                content.timezoneTarget = originalTarget
                content.scrollArea.contentY = originalContentY
            }
        }

        function test_keyboard_navigation_scrolls_to_distant_city() {
            var originalCities = fakeService.cities
            var originalTarget = content.timezoneTarget
            var originalFocusId = content.keyboardFocusId
            var originalContentY = content.scrollArea.contentY
            var many = []
            for (var i = 0; i < 8; i++) many.push({ label: "City " + i, id: "Etc/GMT" + i })
            try {
                fakeService.cities = many
                content.timezoneTarget = "Etc/GMT0"
                content.keyboardFocusId = ""
                content.forceActiveFocus()
                for (var step = 0; step < 7; step++) keyClick(Qt.Key_Down)
                compare(content.keyboardFocusId, "Etc/GMT7")
                verify(content.scrollArea.contentY > 0)
                var last = content.cityList.itemAtIndex(7)
                verify(last !== null)
                var y = last.mapToItem(content.scrollArea.contentItem, 0, 0).y
                verify(y >= content.scrollArea.contentY)
                verify(y + last.height <= content.scrollArea.contentY + content.scrollArea.height)
            } finally {
                fakeService.cities = originalCities
                content.timezoneTarget = originalTarget
                content.keyboardFocusId = originalFocusId
                content.scrollArea.contentY = originalContentY
            }
        }

        function test_keyboard_escape_closes_panel() {
            var oldVisible = fakeTheme.elsewhenVisible
            var oldSearchMode = content.searchMode
            try {
                fakeTheme.elsewhenVisible = true
                content.scrubMinutes = 0
                content.timezoneConfirmationVisible = false
                content.peopleEditIndex = -1
                content.searchMode = ""
                content.zoneSearchInput.text = ""
                content.zoneSearchInput.focus = false
                content.forceActiveFocus()
                keyClick(Qt.Key_Escape)
                compare(fakeTheme.elsewhenVisible, false)
            } finally {
                content.searchMode = oldSearchMode
                fakeTheme.elsewhenVisible = oldVisible
            }
        }

        function test_keyboard_h_and_l_shift_clock_by_hour() {
            var previousShift = content.scrubMinutes
            try {
                content.scrubMinutes = 0
                content.forceActiveFocus()
                keyClick(Qt.Key_H)
                compare(content.scrubMinutes, -60)
                keyClick(Qt.Key_L)
                compare(content.scrubMinutes, 0)
            } finally {
                content.scrubMinutes = previousShift
            }
        }

        function test_keyboard_left_and_right_shift_city_clock_one_hour() {
            var previousShift = content.scrubMinutes
            try {
                content.scrubMinutes = 0
                content.forceActiveFocus()
                keyClick(Qt.Key_Left)
                compare(content.scrubMinutes, -60)
                keyClick(Qt.Key_Right)
                compare(content.scrubMinutes, 0)
            } finally {
                content.scrubMinutes = previousShift
            }
        }

        function test_keyboard_x_removes_focused_city() {
            var originalCities = fakeService.cities
            var originalClockRows = fakeService.clockRows
            var originalTarget = content.timezoneTarget
            var originalFocusId = content.keyboardFocusId
            try {
                fakeService.cities = originalCities.slice()
                fakeService.clockRows = originalClockRows.slice()
                content.timezoneTarget = "Europe/Paris"
                content.keyboardFocusId = "Europe/Paris"
                content.forceActiveFocus()
                keyClick(Qt.Key_X)
                compare(fakeService.cities.length, 1)
                compare(content.keyboardFocusId, "Asia/Tokyo")
            } finally {
                fakeService.cities = originalCities
                fakeService.clockRows = originalClockRows
                content.timezoneTarget = originalTarget
                content.keyboardFocusId = originalFocusId
            }
        }

        function test_keyboard_delete_removes_focused_city_and_moves_focus() {
            var originalCities = fakeService.cities
            var originalClockRows = fakeService.clockRows
            var originalTarget = content.timezoneTarget
            var originalFocusId = content.keyboardFocusId
            try {
                fakeService.cities = originalCities.slice()
                fakeService.clockRows = originalClockRows.slice()
                fakeService.cityRemoves = 0
                content.timezoneTarget = "Europe/Paris"
                content.keyboardFocusId = "Europe/Paris"
                content.forceActiveFocus()
                keyClick(Qt.Key_Delete)
                compare(fakeService.cityRemoves, 1)
                compare(fakeService.cities.length, 1)
                compare(content.keyboardFocusId, "Asia/Tokyo")
            } finally {
                fakeService.cities = originalCities
                fakeService.clockRows = originalClockRows
                content.timezoneTarget = originalTarget
                content.keyboardFocusId = originalFocusId
            }
        }

        function test_escape_resets_shift_before_closing_panel() {
            var previousShift = content.scrubMinutes
            try {
                fakeTheme.elsewhenVisible = true
                content.scrubMinutes = 60
                content.forceActiveFocus()
                keyClick(Qt.Key_Escape)
                compare(content.scrubMinutes, 0)
                compare(fakeTheme.elsewhenVisible, true)
            } finally {
                content.scrubMinutes = previousShift
            }
        }

        function test_escape_cancels_timezone_confirmation_first() {
            fakeTheme.elsewhenVisible = true
            content.timezoneConfirmationVisible = true
            content.forceActiveFocus()
            keyClick(Qt.Key_Escape)
            compare(content.timezoneConfirmationVisible, false)
            compare(fakeTheme.elsewhenVisible, true)
        }

        function test_escape_clears_search_without_closing_panel() {
            var oldText = content.zoneSearchInput.text
            fakeTheme.elsewhenVisible = true
            content.zoneSearchInput.text = "Paris"
            content.zoneSearchInput.forceActiveFocus()
            keyClick(Qt.Key_Escape)
            compare(content.zoneSearchInput.text, "")
            compare(fakeTheme.elsewhenVisible, true)
            content.zoneSearchInput.text = oldText
        }

        function test_hour_format_setting_is_persisted() {
            fakeService.settingsWrites = 0
            mouseClick(content.hour24Button, content.hour24Button.width / 2, content.hour24Button.height / 2)
            compare(fakeService.preferenceData.hour24, true)
            compare(fakeService.settingsWrites, 1)
        }

        function test_city_offset_click_toggles_between_relative_and_utc() {
            var first = content.cityList.itemAtIndex(0)
            var original = fakeService.preferenceData
            fakeService.preferenceData = Object.assign({}, original, { offsetMode: "home" })
            var offset = findChild(first, "elsewhen-city-offset")
            verify(offset !== null)
            try {
                mouseClick(offset, offset.width / 2, offset.height / 2)
                compare(fakeService.preferenceData.offsetMode, "utc")
                mouseClick(offset, offset.width / 2, offset.height / 2)
                compare(fakeService.preferenceData.offsetMode, "home")
            } finally { fakeService.preferenceData = original }
        }

        function test_city_time_click_toggles_hour_format_each_way() {
            var previousPreferences = fakeService.preferenceData
            var previousWrites = fakeService.settingsWrites
            try {
                fakeService.preferenceData = { hour24: false, globeEnabled: true, smoothMotion: true }
                fakeService.settingsWrites = 0
                var row = content.cityList.itemAtIndex(0)
                var time = findChild(row, "elsewhen-city-time")
                verify(time !== null)
                mouseClick(time, time.width / 2, time.height / 2)
                compare(fakeService.preferenceData.hour24, true)
                mouseClick(time, time.width / 2, time.height / 2)
                compare(fakeService.preferenceData.hour24, false)
                compare(fakeService.settingsWrites, 2)
            } finally {
                fakeService.preferenceData = previousPreferences
                fakeService.settingsWrites = previousWrites
            }
        }

        function test_offline_zone_search_and_add() {
            fakeService.cityAdds = 0
            content.zoneSearchInput.text = "new york"
            compare(content.searchText, "new york")
            compare(content.searchResults.length, 1)
            tryCompare(content.searchList, "count", 1)
            mouseClick(content.addZoneButton, content.addZoneButton.width / 2, content.addZoneButton.height / 2)
            compare(fakeService.cityAdds, 1)
        }

        function test_here_search_saves_selected_coordinates_without_adding_a_clock() {
            var oldPrefs = fakeService.preferenceData
            var oldCities = fakeService.cities
            var oldLocalZone = fakeService.localZone
            var oldResults = fakeService.searchPlaceResults
            var oldWrites = fakeService.settingsWrites
            var oldMode = content.searchMode
            var oldFocusId = content.keyboardFocusId
            var oldFocusKey = content.keyboardFocusKey
            fakeService.preferenceData = { hour24: false, homeCity: "Old override" }
            fakeService.localZone = "Asia/Manila"
            fakeService.searchPlaceResults = [{
                label: "Cebu", region: "Central Visayas, Philippines", value: "Asia/Manila",
                lat: 10.3157, lon: 123.8854
            }]
            var clocksBefore = fakeService.cities.length
            try {
                content.keyboardFocusId = ""
                content.keyboardFocusKey = ""
                var hereButton = findChild(content, "elsewhen-here-search-button")
                verify(hereButton !== null)
                mouseClick(hereButton, hereButton.width / 2, hereButton.height / 2)
                compare(content.searchMode, "here")
                compare(content.searchResults.length, 1)
                compare(content.addZoneButton.label, "Set here")
                mouseClick(content.addZoneButton, content.addZoneButton.width / 2, content.addZoneButton.height / 2)
                compare(fakeService.preferenceData.here.name, "Cebu")
                compare(fakeService.preferenceData.here.zone, "Asia/Manila")
                compare(fakeService.preferenceData.here.lat, 10.3157)
                compare(fakeService.preferenceData.here.lon, 123.8854)
                compare(fakeService.preferenceData.homeCity, undefined)
                compare(fakeService.cities.length, clocksBefore)
                compare(content.hereZone.label, "Cebu")
                compare(content.searchMode, "")
            } finally {
                fakeService.preferenceData = oldPrefs
                fakeService.cities = oldCities
                fakeService.localZone = oldLocalZone
                fakeService.searchPlaceResults = oldResults
                fakeService.settingsWrites = oldWrites
                content.searchMode = oldMode
                content.keyboardFocusId = oldFocusId
                content.keyboardFocusKey = oldFocusKey
                content.zoneSearchInput.text = ""
            }
        }

        function test_here_search_waits_for_cross_zone_change_result() {
            var oldPrefs = fakeService.preferenceData
            var oldResults = fakeService.searchPlaceResults
            var oldLocalZone = fakeService.localZone
            var oldRequests = fakeService.timezoneRequests
            var oldTarget = fakeService.timezoneTarget
            var oldPendingHere = fakeService.pendingTimezoneHere
            var oldPendingCities = fakeService.pendingTimezoneCities
            fakeService.preferenceData = { hour24: false }
            fakeService.localZone = "Asia/Manila"
            fakeService.searchPlaceResults = [{
                label: "Springfield", region: "Illinois, US", value: "America/Chicago",
                lat: 39.78, lon: -89.64
            }]
            fakeService.timezoneRequests = 0
            try {
                content.startHereSearch()
                content.zoneSearchInput.text = "Springfield"
                compare(content.searchResults.length, 1)
                mouseClick(content.addZoneButton, content.addZoneButton.width / 2, content.addZoneButton.height / 2)
                compare(fakeService.timezoneRequests, 1)
                compare(fakeService.timezoneTarget, "America/Chicago")
                compare(fakeService.pendingTimezoneHere.name, "Springfield")
                compare(fakeService.pendingTimezoneHere.zone, "America/Chicago")
                compare(fakeService.pendingTimezoneHere.lat, 39.78)
                compare(fakeService.preferenceData.here, undefined)
            } finally {
                fakeService.preferenceData = oldPrefs
                fakeService.searchPlaceResults = oldResults
                fakeService.localZone = oldLocalZone
                fakeService.timezoneRequests = oldRequests
                fakeService.timezoneTarget = oldTarget
                fakeService.pendingTimezoneHere = oldPendingHere
                fakeService.pendingTimezoneCities = oldPendingCities
                content.searchMode = ""
                content.zoneSearchInput.text = ""
                content.zoneSearchInput.focus = false
            }
        }

        function test_globe_footer_shows_selected_clock_and_toggles_offset_label() {
            var oldPrefs = fakeService.preferenceData
            var oldKey = content.globeSelectionKey
            var oldLabel = content.globeSelectionLabel
            var oldZone = content.globeSelectionZone
            var oldTarget = content.timezoneTarget
            var oldExpanded = content.globeExpanded
            var oldLocalOffset = fakeService.localOffsetMinutes
            var oldContentY = content.scrollArea.contentY
            var oldNowMs = fakeService.nowMs
            try {
                fakeService.preferenceData = Object.assign({}, oldPrefs, { offsetMode: "home" })
                fakeService.localOffsetMinutes = 0
                fakeService.nowMs = Date.UTC(2024, 2, 20, 0, 0, 0)
                content.globeExpanded = true
                content.globeSelectionKey = content.globeCityIdentity(fakeService.cities[0])
                content.globeSelectionLabel = "Paris"
                content.globeSelectionZone = "Europe/Paris"
                content.timezoneTarget = "Europe/Paris"
                var city = findChild(content, "elsewhen-globe-footer-city")
                var clock = findChild(content, "elsewhen-globe-footer-clock")
                var badge = findChild(content, "elsewhen-globe-footer-badge")
                var zone = findChild(content, "elsewhen-globe-footer-zone")
                var offsetText = findChild(content, "elsewhen-globe-footer-offset")
                var offset = findChild(content, "elsewhen-globe-footer-offset-toggle")
                var moon = findChild(content, "elsewhen-globe-footer-moon")
                verify(city !== null && clock !== null && badge !== null && zone !== null
                    && offsetText !== null && offset !== null && moon !== null)
                content.scrollArea.contentY = Math.max(0, content.scrollArea.contentHeight - content.scrollArea.height)
                wait(50)
                verify(offset.enabled && offset.width > 0 && offset.height > 0)
                compare(city.text, "Paris")
                compare(zone.text, "Europe/Paris")
                compare(badge.text.toLowerCase(), "tracked")
                verify(moon.visible)
                compare(moon.phase, content.globeFooterMoonPhase)
                compare(clock.text, content.globeFooterRow.time
                    + (content.globeFooterRow.meridiem ? " " + content.globeFooterRow.meridiem : ""))
                mouseClick(offset, offset.width / 2, offset.height / 2)
                compare(fakeService.preferenceData.offsetMode, "utc")
                compare(offsetText.text, content.offsetTextFor(content.globeFooterRow))
            } finally {
                fakeService.preferenceData = oldPrefs
                content.globeSelectionKey = oldKey
                content.globeSelectionLabel = oldLabel
                content.globeSelectionZone = oldZone
                content.timezoneTarget = oldTarget
                content.globeExpanded = oldExpanded
                fakeService.localOffsetMinutes = oldLocalOffset
                content.scrollArea.contentY = oldContentY
                fakeService.nowMs = oldNowMs
            }
        }

        function test_globe_footer_moon_uses_coordinates_while_timezone_probe_pending() {
            var oldProbe = fakeService.probe
            var oldNowMs = fakeService.nowMs
            var oldKey = content.globeSelectionKey
            var oldLabel = content.globeSelectionLabel
            var oldZone = content.globeSelectionZone
            var oldExpanded = content.globeExpanded
            try {
                fakeService.probe = ({})
                content.globeExpanded = true
                content.globeSelectionKey = content.globeCityIdentity(fakeService.cities[0])
                content.globeSelectionLabel = "Paris"
                content.globeSelectionZone = "Europe/Paris"
                var moon = findChild(content, "elsewhen-globe-footer-moon")
                verify(moon !== null)

                fakeService.nowMs = Date.UTC(2024, 2, 20, 0, 0, 0)
                compare(content.globeFooterRow.ready, false)
                tryCompare(moon, "visible", true)
                verify(!content.globeFooterDaylight)

                fakeService.nowMs = Date.UTC(2024, 2, 20, 12, 0, 0)
                compare(content.globeFooterRow.ready, false)
                tryCompare(moon, "visible", false)
                verify(content.globeFooterDaylight)
            } finally {
                fakeService.probe = oldProbe
                fakeService.nowMs = oldNowMs
                content.globeSelectionKey = oldKey
                content.globeSelectionLabel = oldLabel
                content.globeSelectionZone = oldZone
                content.globeExpanded = oldExpanded
            }
        }

        function test_globe_jump_adds_only_a_temporary_map_city() {
            var oldResults = fakeService.searchPlaceResults
            var oldCities = fakeService.cities
            var oldPreferences = fakeService.preferenceData
            var oldSessionCities = content.globeSessionCities
            var oldExpanded = content.globeExpanded
            var oldMode = content.searchMode
            var oldTarget = content.timezoneTarget
            var oldSpin = content.globeSpin
            var oldViewLat = content.globeViewLat
            var oldContentY = content.scrollArea.contentY
            fakeService.searchPlaceResults = [{
                label: "Valparaíso", region: "Valparaíso Region, Chile", value: "America/Santiago",
                lat: -33.0472, lon: -71.6127
            }]
            content.globeExpanded = true
            content.globeSpin = 0
            content.globeViewLat = 0
            content.scrollArea.contentY = 0
            wait(50)
            content.startJumpSearch()
            content.zoneSearchInput.text = "Valparaíso"
            try {
                compare(content.searchResults.length, 1)
                compare(content.addZoneButton.label, "Jump")
                wait(320)
                var jumpPoint = content.addZoneButton.mapToItem(testRoot, 0, 0)
                mouseClick(testRoot, jumpPoint.x + content.addZoneButton.width / 2,
                    jumpPoint.y + content.addZoneButton.height / 2)
                compare(content.globeExpanded, true)
                compare(content.searchMode, "")
                compare(content.globeSessionCities.length, 1)
                compare(content.globeSessionCities[0].label, "Valparaíso")
                compare(content.globeSelectionLabel, "Valparaíso")
                compare(fakeService.cities.length, oldCities.length)
                compare(fakeService.preferenceData, oldPreferences)
                tryVerify(function() { return Math.abs(Globe.shortestTurn(content.globeSpin, -71.6127)) < 0.5 }, 900)
                tryVerify(function() { return Math.abs(content.globeViewLat + 33.0472) < 0.5 }, 900)
                wait(400)
            } finally {
                fakeService.searchPlaceResults = oldResults
                fakeService.cities = oldCities
                fakeService.preferenceData = oldPreferences
                content.globeSessionCities = oldSessionCities
                content.globeExpanded = oldExpanded
                content.searchMode = oldMode
                content.timezoneTarget = oldTarget
                content.globeSpin = oldSpin
                content.globeViewLat = oldViewLat
                content.scrollArea.contentY = oldContentY
                content.zoneSearchInput.text = ""
            }
        }

        function test_place_search_debounce_dispatches_only_the_latest_text() {
            var previousRequests = fakeService.placeSearchRequests
            var previousQuery = fakeService.lastPlaceSearchQuery
            var previousSearchText = content.searchText
            try {
                fakeService.placeSearchRequests = 0
                content.zoneSearchInput.text = "San"
                wait(70)
                content.zoneSearchInput.text = "San Francisco"
                wait(120)
                compare(fakeService.placeSearchRequests, 0)
                tryCompare(fakeService, "placeSearchRequests", 1, 700)
                compare(fakeService.lastPlaceSearchQuery, "San Francisco")
                wait(350)
                compare(fakeService.placeSearchRequests, 1)
            } finally {
                content.zoneSearchInput.text = ""
                wait(350)
                content.searchText = previousSearchText
                fakeService.placeSearchRequests = previousRequests
                fakeService.lastPlaceSearchQuery = previousQuery
                fakeService.placeSearchText = ""
                fakeService.placeSearchRunning = false
                fakeService.placeSearchError = ""
            }
        }

        function test_geocoded_place_search_result_preserves_coordinates() {
            fakeService.cityAdds = 0
            fakeService.lastAddedPlace = null
            fakeService.searchPlaceResults = [{
                label: "Springfield", region: "Illinois, US", value: "America/Chicago",
                lat: 39.78, lon: -89.64
            }]
            content.zoneSearchInput.text = "springfield"
            tryCompare(content.searchList, "count", 1)
            mouseClick(content.addZoneButton, content.addZoneButton.width / 2, content.addZoneButton.height / 2)
            compare(fakeService.cityAdds, 1)
            verify(fakeService.lastAddedPlace !== null)
            compare(fakeService.lastAddedPlace.lat, 39.78)
            compare(fakeService.lastAddedPlace.lon, -89.64)
            compare(fakeService.lastAddedPlace.region, "Illinois, US")
            fakeService.searchPlaceResults = []
        }

        function test_globe_scene_keeps_home_marker_before_selection() {
            var oldLocalZone = fakeService.localZone
            var oldPreferences = fakeService.preferenceData
            var oldCityData = fakeService.cityData
            var oldCities = fakeService.cities
            var oldSessionCities = content.globeSessionCities
            var oldSelectionKey = content.globeSelectionKey
            var oldSpin = content.globeSpin
            var oldViewLat = content.globeViewLat
            try {
                fakeService.localZone = "Etc/UTC"
                fakeService.preferenceData = Object.assign({}, oldPreferences, {
                    here: { name: "Home", zone: "Etc/UTC", lat: 0, lon: 0 }
                })
                fakeService.cityData = [["Decoy", "Etc/UTC", 0, 0, 9]]
                fakeService.cities = []
                content.globeSessionCities = []
                content.globeSelectionKey = ""
                content.globeSpin = 0
                content.globeViewLat = 0

                var scene = content.globeScene(80)
                var homeIndex = -1
                var decoyIndex = -1
                for (var i = 0; i < scene.places.length; i++) {
                    if (scene.places[i].label === "Home") homeIndex = i
                    if (scene.places[i].label === "Decoy") decoyIndex = i
                }
                verify(homeIndex >= 0)
                verify(decoyIndex >= 0)
                var homePlotted = false
                var decoyPlotted = false
                for (var j = 0; j < scene.plotted.length; j++) {
                    if (scene.plotted[j].index === homeIndex) homePlotted = true
                    if (scene.plotted[j].index === decoyIndex) decoyPlotted = true
                }
                verify(homePlotted)
                verify(!decoyPlotted)
            } finally {
                fakeService.localZone = oldLocalZone
                fakeService.preferenceData = oldPreferences
                fakeService.cityData = oldCityData
                fakeService.cities = oldCities
                content.globeSessionCities = oldSessionCities
                content.globeSelectionKey = oldSelectionKey
                content.globeSpin = oldSpin
                content.globeViewLat = oldViewLat
            }
        }

        function test_custom_city_coordinates_override_timezone_catalog_on_globe() {
            var brasilia = { label: "Brasília", id: "America/Sao_Paulo", lat: -15.7939, lon: -47.8828 }
            var place = content.placeForCity(brasilia)
            verify(place !== null)
            compare(place.lat, -15.7939)
            compare(place.lon, -47.8828)
        }

        function test_city_name_overrides_shared_timezone_catalog_coordinates() {
            var oldCityData = fakeService.cityData
            fakeService.cityData = oldCityData.concat([
                ["Sao Paulo", "America/Sao_Paulo", -23.55, -46.64, 1],
                ["Brasília", "America/Sao_Paulo", -15.7939, -47.8828, 1]
            ])
            try {
                var place = content.placeForCity({ label: "Brasília", id: "America/Sao_Paulo" })
                compare(place.lat, -15.7939)
                compare(place.lon, -47.8828)
            } finally {
                fakeService.cityData = oldCityData
            }
        }

        function test_globe_can_be_hidden_and_restored() {
            var oldPreferences = fakeService.preferenceData
            try {
                mouseClick(content.globeToggleButton)
                compare(fakeService.preferenceData.globeEnabled, false)
                verify(!content.globeCanvas.visible)
                var heroButton = findChild(content, "elsewhen-hero-globe-button")
                verify(heroButton !== null)
                verify(!heroButton.enabled)
                mouseClick(content.globeToggleButton)
                compare(fakeService.preferenceData.globeEnabled, true)
                verify(content.globeCanvas.visible)
                verify(heroButton.enabled)
            } finally {
                fakeService.preferenceData = oldPreferences
            }
        }

        function test_disabled_hero_globe_hit_target_is_inactive() {
            var oldPreferences = fakeService.preferenceData
            var oldExpanded = content.globeExpanded
            try {
                fakeService.preferenceData = Object.assign({}, oldPreferences, { globeEnabled: false })
                var button = findChild(content, "elsewhen-hero-globe-button")
                verify(button !== null)
                verify(!button.enabled)
                var hitTarget = button.childAt(button.width / 2, button.height / 2)
                verify(hitTarget !== null)
                verify(!hitTarget.enabled)
                mouseClick(button, button.width / 2, button.height / 2)
                compare(content.globeExpanded, oldExpanded)
            } finally {
                content.globeExpanded = oldExpanded
                fakeService.preferenceData = oldPreferences
            }
        }

        function test_globe_zoom_button_expands_map_and_hides_clock_list() {
            var oldExpanded = content.globeExpanded
            try {
                var zoomButton = findChild(content, "elsewhen-globe-zoom")
                verify(zoomButton !== null)
                mouseClick(zoomButton, zoomButton.width / 2, zoomButton.height / 2)
                compare(content.globeExpanded, true)
                compare(content.cityList.visible, false)
                tryCompare(content.globeCanvas, "height", 300, 1000)
                mouseClick(zoomButton, zoomButton.width / 2, zoomButton.height / 2)
                compare(content.globeExpanded, false)
                compare(content.cityList.visible, true)
                wait(400)
            } finally {
                content.globeExpanded = oldExpanded
            }
        }

        function test_escape_exits_expanded_globe_without_closing_panel() {
            var oldExpanded = content.globeExpanded
            var oldVisible = fakeTheme.elsewhenVisible
            var oldSearchMode = content.searchMode
            try {
                content.globeExpanded = true
                content.searchMode = ""
                content.zoneSearchInput.text = ""
                content.zoneSearchInput.focus = false
                fakeTheme.elsewhenVisible = true
                content.handleEscape()
                compare(content.globeExpanded, false)
                compare(fakeTheme.elsewhenVisible, true)
            } finally {
                content.globeExpanded = oldExpanded
                content.searchMode = oldSearchMode
                fakeTheme.elsewhenVisible = oldVisible
            }
        }

        function test_hero_globe_button_toggles_expanded_mode() {
            var button = findChild(content, "elsewhen-hero-globe-button")
            verify(button !== null)
            verify(button.enabled)
            mouseClick(button)
            compare(content.globeExpanded, true)
            tryCompare(content.globeCanvas, "height", 300, 1000)
            mouseClick(button)
            compare(content.globeExpanded, false)
            tryCompare(content.globeCanvas, "height", 158, 700)
        }

        function test_hero_globe_shift_click_uses_slow_zoom_duration() {
            var oldExpanded = content.globeExpanded
            var button = findChild(content, "elsewhen-hero-globe-button")
            verify(button !== null)
            try {
                mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.ShiftModifier)
                compare(content.globeExpanded, true)
                compare(content.globeZoomDuration, 2400)
                compare(content.globeZoomEasing, Easing.OutQuart)
                tryCompare(content.globeCanvas, "height", 300, 2600)
                mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.ShiftModifier)
                compare(content.globeExpanded, false)
                compare(content.globeZoomDuration, 1500)
                compare(content.globeZoomEasing, Easing.InOutCubic)
                tryCompare(content.globeCanvas, "height", 158, 1700)
            } finally {
                content.globeExpanded = oldExpanded
            }
        }

        function test_keyboard_space_toggles_expanded_globe() {
            content.forceActiveFocus()
            keyClick(Qt.Key_Space)
            compare(content.globeExpanded, true)
            keyClick(Qt.Key_Space)
            compare(content.globeExpanded, false)
            wait(400)
        }

        function test_panel_open_spins_hero_globe_to_here_longitude() {
            var oldVisible = fakeTheme.elsewhenVisible
            var oldZone = fakeService.localZone
            var oldPreferences = fakeService.preferenceData
            var oldHeroSpin
            var oldGlobeSpin
            try {
                fakeTheme.elsewhenVisible = false
                wait(600)
                oldHeroSpin = content.heroSpin
                oldGlobeSpin = content.globeSpin
                content.heroSpin = 0
                fakeService.localZone = "Europe/Paris"
                wait(20)
                fakeTheme.elsewhenVisible = true
                verify(findChild(content, "elsewhen-hero-globe-icon") !== null)
                tryVerify(function() { return content.heroSpin < -1000 }, 250)
                tryVerify(function() { return Math.abs(content.heroSpin - 2.35) < 0.1 }, 1800)
                compare(content.globeSpin, oldGlobeSpin)
            } finally {
                fakeTheme.elsewhenVisible = false
                content.heroSpin = oldHeroSpin
                fakeService.localZone = oldZone
                fakeService.preferenceData = Object.assign({}, oldPreferences, { smoothMotion: false })
                fakeTheme.elsewhenVisible = oldVisible
                content.heroSpin = oldHeroSpin
                fakeService.preferenceData = oldPreferences
            }
        }

        function test_hero_globe_turns_to_city_focus_and_home() {
            var oldVisible = fakeTheme.elsewhenVisible
            var oldZone = fakeService.localZone
            var oldPreferences = fakeService.preferenceData
            var oldHeroSpin
            var oldGlobeSpin = content.globeSpin
            var oldGlobeViewLat = content.globeViewLat
            var oldFocusId = content.keyboardFocusId
            var oldFocusKey = content.keyboardFocusKey
            var oldTarget = content.timezoneTarget
            try {
                fakeTheme.elsewhenVisible = false
                wait(600)
                oldHeroSpin = content.heroSpin
                fakeService.localZone = "Europe/Paris"
                content.keyboardFocusId = ""
                content.keyboardFocusKey = ""
                fakeTheme.elsewhenVisible = true
                tryVerify(function() { return Math.abs(content.heroSpin - 2.35) < 0.1 }, 1800)
                verify(content.focusCity(1))
                tryVerify(function() { return Math.abs(content.heroSpin - 139.69) < 0.1 }, 1100)
                verify(content.focusCity(0))
                tryVerify(function() { return Math.abs(content.heroSpin - 2.35) < 0.1 }, 1100)
            } finally {
                fakeTheme.elsewhenVisible = false
                wait(600)
                content.keyboardFocusId = oldFocusId
                content.keyboardFocusKey = oldFocusKey
                content.timezoneTarget = oldTarget
                content.globeSpin = oldGlobeSpin
                content.globeViewLat = oldGlobeViewLat
                content.heroSpin = oldHeroSpin
                fakeService.localZone = oldZone
                fakeService.preferenceData = Object.assign({}, oldPreferences, { smoothMotion: false })
                fakeTheme.elsewhenVisible = oldVisible
                content.heroSpin = oldHeroSpin
                fakeService.preferenceData = oldPreferences
            }
        }

        function test_opening_spin_waits_for_home_data_and_replays_last_endpoints_without_coordinates() {
            var oldVisible = fakeTheme.elsewhenVisible
            var oldZone = fakeService.localZone
            var oldReady = fakeService.cityDataReady
            var oldPreferences = fakeService.preferenceData
            var oldHeroSpin
            try {
                fakeTheme.elsewhenVisible = false
                wait(600)
                oldHeroSpin = content.heroSpin
                content.heroSpin = 0
                fakeService.localZone = "Europe/Paris"
                fakeService.cityDataReady = false
                fakeTheme.elsewhenVisible = true
                compare(content.openingSpinPending, true)
                fakeTheme.elsewhenVisible = false
                compare(content.openingSpinPending, false)
                fakeService.cityDataReady = true
                fakeTheme.elsewhenVisible = true
                tryVerify(function() { return Math.abs(content.heroSpin - 2.35) < 0.1 }, 1800)

                fakeTheme.elsewhenVisible = false
                fakeService.localZone = "Etc/UTC"
                fakeTheme.elsewhenVisible = true
                compare(content.openingSpinPending, true)
                tryVerify(function() { return content.heroSpin < -1000 }, 1900)
                tryVerify(function() { return Math.abs(content.heroSpin - 2.35) < 0.1 }, 1800)
            } finally {
                fakeTheme.elsewhenVisible = false
                content.heroSpin = oldHeroSpin
                fakeService.localZone = oldZone
                fakeService.cityDataReady = oldReady
                fakeService.preferenceData = Object.assign({}, oldPreferences, { smoothMotion: false })
                fakeTheme.elsewhenVisible = oldVisible
                content.heroSpin = oldHeroSpin
                fakeService.preferenceData = oldPreferences
            }
        }

        function test_panel_close_resets_expanded_globe() {
            var oldExpanded = content.globeExpanded
            var oldVisible = fakeTheme.elsewhenVisible
            try {
                fakeTheme.elsewhenVisible = true
                content.globeExpanded = true
                fakeTheme.elsewhenVisible = false
                compare(content.panelIsOpen, false)
                compare(content.globeExpanded, false)
            } finally {
                fakeTheme.elsewhenVisible = oldVisible
                content.globeExpanded = oldExpanded
            }
        }

        function test_globe_drag_rotates_projection() {
            var before = content.globeSpin
            mouseDrag(content.globeDragArea, 40, 80, 32, 0, Qt.LeftButton)
            verify(content.globeSpin !== before)
        }

        function test_globe_vertical_drag_tilts_projection_without_tapping_city() {
            var before = content.globeViewLat
            var focusBefore = content.keyboardFocusKey
            mouseDrag(content.globeDragArea, 40, 80, 0, 20, Qt.LeftButton)
            compare(content.globeViewLat, before + 7)
            compare(content.keyboardFocusKey, focusBefore)
        }

        function test_globe_tiny_width_has_nonnegative_canvas_geometry() {
            var originalWidth = testRoot.width
            testRoot.width = 4
            wait(40)
            var tinyCanvasWidth = content.globeCanvas.width
            content.globeCanvas.requestPaint()
            wait(40)
            testRoot.width = originalWidth
            wait(20)
            verify(tinyCanvasWidth >= 0)
        }

        function test_globe_radius_guard_rejects_nonpositive_size() {
            compare(content.globePaintRadius(0, 158), 0)
            compare(content.globePaintRadius(-8, 158), 0)
            compare(content.globePaintRadius(260, 158), 71.1)
        }

        function test_globe_canvas_is_live_when_enabled() {
            verify(content.globeCanvas.visible)
            verify(content.globeCanvas.width > 0)
            verify(content.globeCanvas.height > 0)
        }

        function test_city_row_displays_solar_daylight_strip() {
            var row = content.cityList.itemAtIndex(0)
            verify(row !== null)
            var strip = findChild(row, "elsewhen-daylight-strip")
            verify(strip !== null, "each city card should contain its daylight strip")
            compare(strip.ready, true)
            compare(strip.sun.kind, "normal")
            compare(strip.sunMarks.length, 2)
        }

        function test_shift_click_current_moon_starts_phase_demo() {
            var oldNowMs = fakeService.nowMs
            fakeService.nowMs = Date.UTC(2024, 2, 20, 0, 0, 0)
            try {
                var row = content.cityList.itemAtIndex(0)
                var strip = findChild(row, "elsewhen-daylight-strip")
                var marker = findChild(strip, "elsewhen-daylight-marker")
                verify(strip !== null && marker !== null)
                compare(strip.litNow, false)
                var point = marker.mapToItem(strip.scrubArea, marker.width / 2, marker.height / 2)
                mouseClick(strip.scrubArea, point.x, point.y, Qt.LeftButton, Qt.ShiftModifier)
                tryVerify(function() { return content.moonShowing === true }, 350)
                tryCompare(content, "moonPhase", 0, 550)
                compare(strip.moonPhase, content.moonPhase)
                tryCompare(content, "moonShowStep", 1, 400)
                verify(content.moonShowing)
                content.stopMoonShow()
                compare(content.moonShowing, false)
                compare(content.moonDemo, -1)
                compare(content.moonPhase, Globe.moonPhase(content.effectiveMs))
                compare(strip.moonPhase, content.moonPhase)
            } finally {
                if (typeof content.stopMoonShow === "function") content.stopMoonShow()
                fakeService.nowMs = oldNowMs
            }
        }

        function test_dragging_strip_temporarily_shifts_city_clock() {
            if (content.displayRows === undefined) {
                fail("panel should compute display rows against the scrubbed instant")
                return
            }
            var row = content.cityList.itemAtIndex(0)
            var time = findChild(row, "elsewhen-city-time")
            verify(time !== null)
            compare(time.text, "1:00")
            var strip = findChild(row, "elsewhen-daylight-strip")
            verify(strip !== null)
            var width = strip.scrubArea.width
            mouseDrag(strip.scrubArea, Math.round(width / 2), 8, Math.round(width / 8), 0, Qt.LeftButton)
            verify(content.scrubMinutes > 60 && content.scrubMinutes < 180)
            var updated = content.cityList.itemAtIndex(0)
            var shiftedTime = findChild(updated, "elsewhen-city-time").text
            verify(shiftedTime.indexOf("3:") === 0)
            tryCompare(content, "scrubMinutes", 0, 3000)
            var restored = content.cityList.itemAtIndex(0)
            compare(findChild(restored, "elsewhen-city-time").text, "1:00")
        }

        function test_timezone_change_requires_an_explicit_confirmation() {
            fakeService.timezoneRequests = 0
            var requestedZone = content.timezoneTarget
            mouseClick(content.changeTimezoneButton)
            verify(content.timezoneConfirmationVisible)
            compare(fakeService.timezoneRequests, 0)
            verify(content.confirmTimezoneButton.visible)
            verify(content.confirmTimezoneButton.enabled)
            content.scrollArea.contentY = Math.max(0, content.scrollArea.contentHeight - content.scrollArea.height)
            wait(50)
            mouseClick(content.confirmTimezoneButton, content.confirmTimezoneButton.width / 2,
                       content.confirmTimezoneButton.height / 2)
            tryCompare(fakeService, "timezoneRequests", 1)
            compare(fakeService.timezoneTarget, requestedZone)
        }
    }
}
