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
        property var notificationMessages: []
        function notify(message) { notificationMessages = notificationMessages.concat([message]) }
    }

    QtObject {
        id: fakeService
        signal timezoneChanged(string zone)
        signal timezoneChangeFailed(string zone, string error)
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
        property var probe: ({
            "Europe/Paris": { offsetMinutes: 60, abbr: "CET" },
            "Asia/Tokyo": { offsetMinutes: 540, abbr: "JST" }
        })
        property bool active: false
        property bool cityDataReady: true
        property bool settingsReady: true
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
        property int profileRequests: 0
        function requestProfiles() {
            if (!active || !settingsReady) return false
            profileRequests++
            return true
        }
        function requestWeather(keys, points) { return false }
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

        function test_timezone_notifications_through_both_adapters() {
            for (var variant of ["v1", "v2"]) {
                load(variant, false, "top")
                theme.notificationMessages = []
                fakeService.timezoneChanged("Europe/Paris")
                compare(theme.notificationMessages.length, 1)
                verify(theme.notificationMessages[0].indexOf("Europe/Paris") >= 0)
                fakeService.timezoneChangeFailed("Asia/Tokyo", "fixture denied")
                compare(theme.notificationMessages.length, 2)
                verify(theme.notificationMessages[1].indexOf("Asia/Tokyo") >= 0)
            }
        }

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

        function test_profile_request_survives_service_activation_ordering() {
            load("v1", false, "top")
            theme.elsewhenVisible = false
            fakeService.active = false
            fakeService.profileRequests = 0
            wait(20)
            theme.elsewhenVisible = true
            fakeService.active = true
            wait(50)
            compare(fakeService.profileRequests, 1)
            theme.elsewhenVisible = false
            fakeService.active = false
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

        function test_timezone_confirmation_render_all_adapters() {
            for (var variant of ["v1", "v2"]) {
                for (var vertical of [false, true]) {
                    load(variant, vertical, vertical ? "left" : "top")
                    var content = findChild(panelLoader.item, "elsewhen-panel-content")
                    var zoom = findChild(content, "elsewhen-globe-zoom")
                    mouseClick(zoom, zoom.width / 2, zoom.height / 2)
                    tryCompare(content.globeCanvas, "height", 300, 1000)
                    content.timezoneTarget = "America/Sao_Paulo"
                    content.timezoneConfirmationVisible = true
                    wait(60)
                    content.scrollArea.contentY = Math.max(0, content.scrollArea.contentHeight - content.scrollArea.height)
                    wait(60)
                    var message = findChild(content, "elsewhen-timezone-confirmation-message")
                    verify(message !== null && !message.truncated)
                    var buttons = content.confirmTimezoneButton.parent.children
                    for (var button of buttons) {
                        if (button.label !== "Confirm" && button.label !== "Cancel") continue
                        var point = button.mapToItem(panelLoader.item.surfaceHost, 0, 0)
                        verify(point.x >= 0 && point.x + button.width <= panelLoader.item.surfaceHost.width)
                        verify(point.y >= 0 && point.y + button.height <= panelLoader.item.surfaceHost.height)
                    }
                    captureScene(variant + (vertical ? "-vertical" : "-horizontal") + "-timezone-confirmation")
                }
            }
        }

        function test_v1_hover_greeting_render() {
            var oldNowMs = fakeService.nowMs
            var oldProbe = fakeService.probe
            var row = null
            try {
                load("v1", false, "top")
                const content = findChild(panelLoader.item, "elsewhen-panel-content")
                verify(content !== null)
                row = content.cityList.itemAtIndex(0)
                verify(row !== null)
                compare(row.rowData.id, "Europe/Paris")
                fakeService.nowMs = Date.UTC(2024, 2, 20, 8, 0, 0)
                fakeService.probe = Object.assign({}, oldProbe, {
                    "Europe/Paris": { offsetMinutes: 60, abbr: "CET" }
                })
                wait(40)
                const greetingLine = findChild(row, "elsewhen-city-greeting-line")
                verify(greetingLine !== null)
                const greetingText = findChild(greetingLine, "elsewhen-city-greeting-text")
                verify(greetingText !== null)
                mouseMove(row, row.width / 2, row.height / 2)
                tryVerify(function() { return row.hovered }, 500)
                tryCompare(greetingLine, "visible", true, 500)
                compare(greetingText.text, "Bonjour")
                captureScene("v1-hover-greeting")
            } finally {
                mouseMove(testRoot, testRoot.width - 1, testRoot.height - 1)
                if (row !== null) tryVerify(function() { return !row.hovered }, 500)
                fakeService.nowMs = oldNowMs
                fakeService.probe = oldProbe
            }
        }

        function test_v1_here_search_render() {
            load("v1", false, "top")
            var content = findChild(panelLoader.item, "elsewhen-panel-content")
            var hereButton = findChild(content, "elsewhen-here-search-button")
            verify(content !== null && hereButton !== null)
            mouseClick(hereButton, hereButton.width / 2, hereButton.height / 2)
            compare(content.searchMode, "here")
            content.zoneSearchInput.text = "Paris"
            tryCompare(content.searchList, "count", 1)
            captureScene("v1-here-search")
        }

        function test_v2_expanded_globe_and_jump_search_render() {
            var oldLocalZone = fakeService.localZone
            var content = null
            fakeService.localZone = "Europe/Paris"
            try {
                load("v2", false, "top")
                content = findChild(panelLoader.item, "elsewhen-panel-content")
                var zoomButton = findChild(content, "elsewhen-globe-zoom")
                verify(content !== null && zoomButton !== null)
                mouseClick(zoomButton, zoomButton.width / 2, zoomButton.height / 2)
                tryCompare(content.globeCanvas, "height", 300, 1000)
                tryVerify(function() { return content.globeFooterPlace !== null }, 1000)
                compare(findChild(content, "elsewhen-globe-footer-city").text, "Paris")
                captureScene("v2-expanded-globe")
                content.startJumpSearch()
                content.zoneSearchInput.text = "Paris"
                tryCompare(content.searchList, "count", 1)
                captureScene("v2-globe-jump-search")
            } finally {
                if (content && typeof content.stopMoonShow === "function") content.stopMoonShow()
                fakeService.localZone = oldLocalZone
            }
        }

        function test_v2_hero_globe_opening_spin_render() {
            var oldLocalZone = fakeService.localZone
            fakeService.localZone = "Europe/Paris"
            try {
                load("v2", false, "top")
                var content = findChild(panelLoader.item, "elsewhen-panel-content")
                var heroButton = findChild(content, "elsewhen-hero-globe-button")
                verify(content !== null && heroButton !== null)
                verify(findChild(content, "elsewhen-hero-globe-icon") !== null)
                tryVerify(function() { return content.heroSpin !== 0 }, 300)
                captureScene("v2-opening-spin")
                tryVerify(function() { return Math.abs(content.heroSpin - 2.35) < 0.1 }, 1800)
                mouseClick(heroButton)
                compare(content.globeExpanded, true)
                mouseClick(heroButton)
                compare(content.globeExpanded, false)
            } finally {
                fakeService.localZone = oldLocalZone
            }
        }

        function test_v2_moon_show_renders_in_night_footer() {
            var oldLocalZone = fakeService.localZone
            var oldNowMs = fakeService.nowMs
            fakeService.localZone = "Asia/Tokyo"
            fakeService.nowMs = Date.UTC(2024, 2, 20, 19, 0, 0)
            var content = null
            var oldSelectionKey = ""
            var oldSelectionLabel = ""
            var oldSelectionZone = ""
            var oldGlobeExpanded = false
            try {
                load("v2", false, "top")
                content = findChild(panelLoader.item, "elsewhen-panel-content")
                verify(content !== null)
                if (content === null) return
                oldSelectionKey = content.globeSelectionKey
                oldSelectionLabel = content.globeSelectionLabel
                oldSelectionZone = content.globeSelectionZone
                oldGlobeExpanded = content.globeExpanded
                var row = content.cityList.itemAtIndex(1)
                var strip = findChild(row, "elsewhen-daylight-strip")
                var marker = findChild(strip, "elsewhen-daylight-marker")
                verify(strip !== null && marker !== null)
                compare(strip.litNow, false)
                var point = marker.mapToItem(strip.scrubArea, marker.width / 2, marker.height / 2)
                mouseClick(strip.scrubArea, point.x, point.y, Qt.LeftButton, Qt.ShiftModifier)
                tryVerify(function() { return content.moonShowing }, 350)
                tryCompare(content, "moonShowStep", 2, 1500)
                tryVerify(function() { return Math.abs(content.moonDemo - 0.25) < 0.005 }, 600)
                compare(strip.moonPhase, content.moonPhase)
                // Select Tokyo for the render fixture so row and globe footer are visible together.
                var selectedPlace = null
                var places = content.globePlaces()
                for (var i = 0; i < places.length; i++)
                    if (places[i].id === "Asia/Tokyo" && places[i].tracked) selectedPlace = places[i]
                verify(selectedPlace !== null)
                if (selectedPlace === null) return
                content.globeSelectionKey = selectedPlace.key
                content.globeSelectionLabel = selectedPlace.label
                content.globeSelectionZone = selectedPlace.id
                tryVerify(function() { return content.globeFooterPlace !== null }, 500)
                compare(findChild(content, "elsewhen-globe-footer-city").text, "Tokyo")
                var rowAndFooterMoon = findChild(content, "elsewhen-globe-footer-moon")
                verify(rowAndFooterMoon !== null)
                compare(rowAndFooterMoon.visible, true)
                compare(rowAndFooterMoon.phase, content.moonPhase)
                captureScene("v2-moon-show-row")

                var zoomButton = findChild(content, "elsewhen-globe-zoom")
                verify(zoomButton !== null)
                mouseClick(zoomButton, zoomButton.width / 2, zoomButton.height / 2)
                tryCompare(content.globeCanvas, "height", 300, 1000)
                tryVerify(function() { return content.globeFooterPlace !== null }, 1000)
                compare(findChild(content, "elsewhen-globe-footer-city").text, "Tokyo")
                compare(content.globeFooterDaylight, false)
                var footerMoon = findChild(content, "elsewhen-globe-footer-moon")
                verify(footerMoon !== null)
                compare(footerMoon.visible, true)
                compare(footerMoon.phase, content.moonPhase)
                captureScene("v2-moon-show")

                tryCompare(content, "moonShowing", false, 5000)
                compare(content.moonDemo, -1)
                compare(footerMoon.phase, content.moonPhase)
            } finally {
                if (content && typeof content.stopMoonShow === "function") content.stopMoonShow()
                if (content) {
                    content.globeSelectionKey = oldSelectionKey
                    content.globeSelectionLabel = oldSelectionLabel
                    content.globeSelectionZone = oldSelectionZone
                    content.globeExpanded = oldGlobeExpanded
                }
                fakeService.localZone = oldLocalZone
                fakeService.nowMs = oldNowMs
            }
        }
    }
}
