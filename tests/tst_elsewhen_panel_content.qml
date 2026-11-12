import QtQuick
import QtTest
import "../shared/panels" as Panels

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
        property color fillIdle: "#282828"
        property color fillHover: "#3c3836"
        property string mono: "monospace"
        property bool elsewhenVisible: true
    }

    QtObject {
        id: fakeService
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
        function requestTimezoneChange(zone) { timezoneRequests++; timezoneTarget = zone; return true }
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

        function test_city_click_focuses_city_and_rotates_globe_without_drag() {
            var second = content.cityList.itemAtIndex(1)
            verify(second !== null)
            var previousTarget = content.timezoneTarget
            var previousFocusId = content.keyboardFocusId
            var previousSpin = content.globeSpin
            try {
                compare(previousTarget, "Europe/Paris")
                fakeService.moveRequests = 0
                mouseClick(second, 24, 27, Qt.LeftButton)
                compare(content.timezoneTarget, "Asia/Tokyo")
                compare(content.keyboardFocusId, "Asia/Tokyo")
                compare(second.keyboardFocused, true)
                tryVerify(function() { return Math.abs(content.globeSpin - 139.69) < 0.5 }, 800)
                compare(content.draggingCityIndex, -1)
                compare(fakeService.moveRequests, 0)
            } finally {
                content.timezoneTarget = previousTarget
                content.keyboardFocusId = previousFocusId
                content.globeSpin = previousSpin
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
            fakeTheme.elsewhenVisible = true
            content.scrubMinutes = 0
            content.timezoneConfirmationVisible = false
            content.peopleEditIndex = -1
            content.zoneSearchInput.text = ""
            content.forceActiveFocus()
            keyClick(Qt.Key_Escape)
            compare(fakeTheme.elsewhenVisible, false)
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

        function test_custom_city_coordinates_override_timezone_catalog_on_globe() {
            var brasilia = { label: "Brasília", id: "America/Sao_Paulo", lat: -15.7939, lon: -47.8828 }
            var place = content.placeForCity(brasilia)
            verify(place !== null)
            compare(place.lat, -15.7939)
            compare(place.lon, -47.8828)
        }

        function test_globe_can_be_hidden_and_restored() {
            mouseClick(content.globeToggleButton)
            compare(fakeService.preferenceData.globeEnabled, false)
            verify(!content.globeCanvas.visible)
            mouseClick(content.globeToggleButton)
            compare(fakeService.preferenceData.globeEnabled, true)
            verify(content.globeCanvas.visible)
        }

        function test_globe_drag_rotates_projection() {
            var before = content.globeSpin
            mouseDrag(content.globeDragArea, 40, 80, 32, 0, Qt.LeftButton)
            verify(content.globeSpin !== before)
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
            compare(fakeService.timezoneTarget, "Europe/Paris")
        }
    }
}
