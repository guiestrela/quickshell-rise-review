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
    }

    QtObject {
        id: fakeService
        property var clockRows: [
            { label: "Paris", id: "Europe/Paris", time: "13:00", offset: "UTC+1", abbr: "CET" },
            { label: "Tokyo", id: "Asia/Tokyo", time: "21:00", offset: "UTC+9", abbr: "JST" }
        ]
        property var zoneOptions: [
            { label: "Paris", value: "Europe/Paris" },
            { label: "Tokyo", value: "Asia/Tokyo" },
            { label: "New York", value: "America/New_York" }
        ]
        property var cityData: [["Paris", "Europe/Paris", 48.85, 2.35, 1], ["Tokyo", "Asia/Tokyo", 35.68, 139.69, 1]]
        property var cities: [{ label: "Paris", id: "Europe/Paris" }, { label: "Tokyo", id: "Asia/Tokyo" }]
        property var worldData: [[-180, -80, 0, -80, 180, -80, 180, 80, 0, 80, -180, 80]]
        property double nowMs: Date.now()
        property bool staticDataReady: true
        property var preferenceData: ({ hour24: false, globeEnabled: true, smoothMotion: true })
        property string localZone: "Etc/UTC"
        property string lastError: ""
        property int refreshRequests: 0
        property int settingsWrites: 0
        property int cityAdds: 0
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
        function addCity(zone, label, place) { cityAdds++; return true }
        function removeCity(index) { cityRemoves++; return clockRows.length > 1 }
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

        function test_world_clock_rows_render() {
            compare(content.cityList.count, 2)
            verify(content.cityList.visible)
        }

        function test_city_row_controls_route_remove_and_reorder() {
            fakeService.moveRequests = 0
            fakeService.cityRemoves = 0
            var second = content.cityList.itemAtIndex(1)
            mouseClick(second.moveUpButton, second.moveUpButton.width / 2, second.moveUpButton.height / 2)
            compare(fakeService.moveRequests, 1)
            var first = content.cityList.itemAtIndex(0)
            mouseClick(first.removeButton, first.removeButton.width / 2, first.removeButton.height / 2)
            compare(fakeService.cityRemoves, 1)
        }

        function test_refresh_button_reaches_service() {
            mouseClick(content.refreshButton, content.refreshButton.width / 2, content.refreshButton.height / 2)
            compare(fakeService.refreshRequests, 1)
        }

        function test_hour_format_setting_is_persisted() {
            fakeService.settingsWrites = 0
            mouseClick(content.hour24Button, content.hour24Button.width / 2, content.hour24Button.height / 2)
            compare(fakeService.preferenceData.hour24, true)
            compare(fakeService.settingsWrites, 1)
        }

        function test_offline_zone_search_and_add() {
            content.zoneSearchInput.text = "new york"
            compare(content.searchText, "new york")
            compare(content.searchResults.length, 1)
            tryCompare(content.searchList, "count", 1)
            mouseClick(content.addZoneButton, content.addZoneButton.width / 2, content.addZoneButton.height / 2)
            compare(fakeService.cityAdds, 1)
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
