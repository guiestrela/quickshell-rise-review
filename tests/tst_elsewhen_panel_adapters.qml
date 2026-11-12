import QtQuick
import QtTest
import "variants/V1/panels" as V1
import "variants/V2/panels" as V2

Item {
    id: testRoot
    width: 800
    height: 800
    property string selectedVariant: "v1"
    property string captureDir: ""
    property bool captureDone: false
    property bool captureSaved: false

    QtObject {
        id: theme
        property var elsewhenService: fakeService
        property bool elsewhenVisible: false
        property real elsewhenBarX: 320
        property var activePopupScreen: ({ name: "DP-1", width: 800, height: 800 })
        property string barPosition: "top"
        property bool barVertical: false
        property int verticalBarWidth: 40
        property int v2BarHeight: 40
        property color bg: "#1d2021"
        property color ink: "#ebdbb2"
        property color seal: "#d79921"
        property color sep: "#504945"
        property color fillIdle: "#282828"
        property color fillHover: "#3c3836"
        property color fillActive: "#504945"
        property color panelBorder: "#504945"
        property color panelOuterBorderColor: "#504945"
        property real panelOuterBorderW: 1
        property real panelRadius: 12
        property real panelButtonRadius: 7
        property real pillRadius: 10
        property color pillBorder: "#504945"
        property real pillBorderW: 1
        property real tileRadius: 7
        property string mono: "monospace"
        property bool styleShadow: false
        property color pillShadow: "#000000"
        property real panelInsetX: 0
        function verticalAnchorY(name) { return 400 }
        function setPanelInsetX(x) { panelInsetX = x }
    }

    QtObject {
        id: fakeService
        property var clockRows: [
            { label: "Paris", id: "Europe/Paris", time: "13:00", date: "Wed, Mar 20", dayLabel: "Wednesday", offset: "UTC+1", relative: "+1h", abbr: "CET", ready: true, offsetMinutes: 60, progress: 13 / 24, lit: true },
            { label: "Tokyo", id: "Asia/Tokyo", time: "21:00", date: "Wed, Mar 20", dayLabel: "Wednesday", offset: "UTC+9", relative: "+9h", abbr: "JST", ready: true, offsetMinutes: 540, progress: 21 / 24, lit: false }
        ]
        property var zoneOptions: [
            { label: "Paris", value: "Europe/Paris" },
            { label: "Tokyo", value: "Asia/Tokyo" }
        ]
        property var cityData: [["Paris", "Europe/Paris", 48.85, 2.35, 1], ["Tokyo", "Asia/Tokyo", 35.68, 139.69, 1]]
        property var weather: ({})
        property bool weatherRunning: false
        property bool active: false
        property bool cityDataReady: true
        property var cities: [{ label: "Paris", id: "Europe/Paris", people: ["Alice"] }, { label: "Tokyo", id: "Asia/Tokyo", people: ["Tokyo team"] }]
        property var worldData: [[-180, -80, 0, -80, 180, -80, 180, 80, 0, 80, -180, 80]]
        property double nowMs: Date.UTC(2024, 2, 20, 12, 0, 0)
        property bool staticDataReady: true
        property var preferenceData: ({ hour24: true, globeEnabled: true, smoothMotion: true })
        property string localZone: "Etc/UTC"
        property string lastError: ""
        property string catalogError: ""
        property string timezoneError: ""
        property int refreshRequests: 0
        function refresh() { refreshRequests++; return true }
        function updateSetting(name, value) {
            var next = Object.assign({}, preferenceData)
            next[name] = value
            preferenceData = next
            return true
        }
        function searchZones(query, limit) {
            var q = String(query || "").toLowerCase()
            return zoneOptions.filter(function(option) {
                return option.label.toLowerCase().indexOf(q) >= 0 || option.value.toLowerCase().indexOf(q) >= 0
            }).slice(0, limit)
        }
        function addCity(zone, label, place) { return true }
        function removeCity(index) { return true }
        function moveCity(from, to) { return true }
        function requestTimezoneChange(zone) { return true }
    }

    Component { id: v1Panel; V1.ElsewhenPanel { root: theme } }
    Component { id: v2Panel; V2.ElsewhenPanel { root: theme } }
    Loader {
        id: panelLoader
        width: testRoot.width
        height: testRoot.height
        sourceComponent: testRoot.selectedVariant === "v1" ? v1Panel : v2Panel
    }

    TestCase {
        name: "ElsewhenPanelAdapters"
        when: windowShown

        function load(variant, vertical, position) {
            theme.elsewhenVisible = false
            panelLoader.sourceComponent = null
            wait(1)
            testRoot.selectedVariant = variant
            theme.barVertical = vertical
            theme.barPosition = position
            panelLoader.sourceComponent = variant === "v1" ? v1Panel : v2Panel
            wait(30)
            theme.elsewhenVisible = true
            wait(80)
            verify(panelLoader.item !== null)
            verify(panelLoader.item.surfaceHost.width > 0)
            verify(panelLoader.item.surfaceHost.height > 0)
        }

        function captureScene(name) {
            if (testRoot.captureDir === "") return
            testRoot.captureDone = false
            testRoot.captureSaved = false
            var card = testRoot
            var accepted = card.grabToImage(function(result) {
                testRoot.captureSaved = result.saveToFile(testRoot.captureDir + "/" + name + ".png")
                testRoot.captureDone = true
            })
            verify(accepted)
            tryVerify(function() { return testRoot.captureDone }, 5000)
            verify(testRoot.captureSaved)
        }

        function test_v1_horizontal_renders_clock_rows_and_anchors() {
            load("v1", false, "top")
            compare(panelLoader.item.surfaceHost.width, 340)
            compare(panelLoader.item.surfaceHost.x,
                    Math.round(Math.max(8, Math.min(theme.elsewhenBarX - panelLoader.item.surfaceHost.width / 2,
                                                   testRoot.width - panelLoader.item.surfaceHost.width - 8))))
            verify(findChild(panelLoader.item, "elsewhen-city-list") !== null)
            compare(fakeService.refreshRequests, 0)
            captureScene("v1-horizontal")
        }

        function test_v1_vertical_positions_left_of_content() {
            load("v1", true, "left")
            compare(panelLoader.item.surfaceHost.x, theme.verticalBarWidth + 8)
            verify(Math.abs(panelLoader.item.surfaceHost.y - (400 - panelLoader.item.surfaceHost.height / 2)) < 1)
            captureScene("v1-vertical")
        }

        function test_v2_horizontal_connected_surface_tracks_owner_anchor() {
            load("v2", false, "top")
            verify(panelLoader.item.surfaceHost.x > 8)
            verify(theme.panelInsetX >= 0)
            verify(findChild(panelLoader.item, "elsewhen-city-list") !== null)
            captureScene("v2-horizontal")
        }

        function test_v2_vertical_positions_right_and_keeps_content() {
            load("v2", true, "right")
            compare(panelLoader.item.surfaceHost.x,
                    testRoot.width - theme.verticalBarWidth - panelLoader.item.surfaceHost.width - 6)
            verify(findChild(panelLoader.item, "elsewhen-city-list") !== null)
            compare(fakeService.refreshRequests, 0)
            captureScene("v2-vertical")
        }
    }
}
