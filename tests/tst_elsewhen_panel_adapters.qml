import QtQuick
import QtTest
import qs.Commons as Commons
import "shared/integrations/elsewhen/Model.js" as Model
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

    FontMetrics {
        id: originalTextFieldMetrics
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.body
    }

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
        property real fillHoverAlpha: 0.12
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
        property string formatLocale: "en_US"
        property var words: null
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
        property int localOffsetMinutes: 0
        property string lastError: ""
        property string catalogError: ""
        property string timezoneError: ""
        property int refreshRequests: 0
        property int cityAdds: 0
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
        function addCity(zone, label, place) { cityAdds++; return true }
        function setHere(here, rows) { return true }
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

        function test_shell_locale_words_and_style_reach_every_adapter() {
            var oldPrefs = fakeService.preferenceData
            var oldLocale = Commons.I18n.formatLocale
            var oldStrings = Commons.I18n.strings
            var oldScale = Commons.Style.testScale
            try {
                var prefs = Object.assign({}, oldPrefs)
                delete prefs.hour24
                fakeService.preferenceData = prefs
                Commons.I18n.strings = {"elsewhen.world":"Mundo", "elsewhen.clock":"Relogio",
                    "elsewhen.here":"Aqui sao %1", "elsewhen.hereIn":"Aqui sao %1 em %2"}
                for (var variant of ["v1", "v2"]) {
                    for (var vertical of [false, true]) {
                        load(variant, vertical, vertical ? "left" : "top")
                        var content = findChild(panelLoader.item, "elsewhen-panel-content")
                        Commons.I18n.formatLocale = "en_GB"
                        compare(fakeService.formatLocale, "en_GB")
                        compare(content.hour24, true)
                        Commons.I18n.formatLocale = "en_US"
                        compare(content.hour24, false)
                        Commons.I18n.formatLocale = "pt_BR"
                        compare(content.hour24, true)
                        compare(findChild(content, "elsewhen-world-title").text, "Mundo")
                        compare(findChild(content, "elsewhen-clock-title").text, "Relogio")
                        verify(content.hereLine.indexOf("Aqui sao") === 0)
                        compare(content.displayRows[0].date, new Date(2024, 2, 20, 12)
                            .toLocaleString(Qt.locale("pt_BR"), "ddd MMM d"))
                        Commons.Style.testScale = 2
                        compare(content.globeStageHeight, Commons.Style.space(378))
                        compare(findChild(content, "elsewhen-world-title").font.pixelSize, Commons.Style.font.title)
                        compare(findChild(content, "elsewhen-here-city").pixelSize, Commons.Style.font.caption)
                        Commons.Style.testScale = 1
                    }
                }
            } finally {
                fakeService.preferenceData = oldPrefs
                Commons.I18n.formatLocale = oldLocale
                Commons.I18n.strings = oldStrings
                Commons.Style.testScale = oldScale
            }
        }

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

        function captureGlobeLabelProbe(content, kind, labelText, zone, spin, viewLat) {
            if (testRoot.captureDir === "") return null
            content.globeSpin = spin
            content.globeViewLat = viewLat
            verify(waitForRendering(panelLoader.item, 3000))
            tryVerify(function() { return !content.globeReduced }, 2000)
            var radius = content.globePaintRadius(content.globeCanvas.width,
                content.globeCanvas.height)
            var scene = content.globeScene(radius)
            var probe = null
            for (var i = 0; i < scene.labels.length; i++) {
                var place = scene.places[scene.labels[i].index]
                if (place.label === labelText && place.id === zone) {
                    probe = scene.labels[i]
                    break
                }
            }
            verify(probe !== null, "visible label for pixel probe: " + labelText)
            var topLeft = content.globeCanvas.mapToItem(testRoot,
                content.globeCanvas.width / 2 + probe.box.x,
                content.globeDiscCenterY + probe.box.y)
            var captureName = "v2-globe-label-" + kind
            var baselineName = captureName + "-no-labels"
            console.log("ELSEWHEN_LABEL_PROBE=" + JSON.stringify({
                kind: kind, label: labelText, zone: zone, image: captureName,
                baseline: baselineName,
                x: topLeft.x, y: topLeft.y, w: probe.box.w, h: probe.box.h
            }))
            verify(waitForRendering(panelLoader.item, 3000))
            captureScene(captureName)
            var dragX = content.globeDragArea.width / 2
            var dragY = content.globeDragArea.height / 2
            mousePress(content.globeDragArea, dragX, dragY)
            mouseMove(content.globeDragArea, dragX + 4, dragY)
            tryVerify(function() { return content.globeReduced }, 500,
                "the no-label baseline is captured during actual pointer motion")
            content.globeSpin = spin
            content.globeViewLat = viewLat
            verify(waitForRendering(panelLoader.item, 3000))
            captureScene(baselineName)
            mouseRelease(content.globeDragArea, dragX + 4, dragY)
            tryVerify(function() { return !content.globeReduced }, 1000,
                "static label rendering returns after the baseline capture")
            return { x: topLeft.x, y: topLeft.y, w: probe.box.w, h: probe.box.h }
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

        function test_v2_elsewhen_connected_surface_uses_owner_and_anchor() {
            load("v2", false, "top")
            var surface = findChild(panelLoader.item, "elsewhen-connected-panel-surface")
            verify(surface !== null, "V2 Elsewhen should render the connected V2 panel surface")
            try {
                theme.elsewhenVisible = false
                wait(1)
                compare(surface.ownerActive, false)
                compare(surface.reveal, 0)
                compare(surface.progress, 0)
                theme.elsewhenVisible = true
                verify(waitForRendering(panelLoader.item, 3000))
                compare(surface.ownerActive, true)
                compare(surface.targetX, theme.elsewhenBarX)
                compare(surface.reveal, panelLoader.item.reveal)
                compare(surface.progress, 1)
                verify(surface.visible)
                verify(surface.pointsUp)
                verify(Math.abs(surface.width - panelLoader.item.surfaceHost.width) < 0.5)
                compare(panelLoader.item.frameRadius, theme.panelRadius)
                captureScene("v2-elsewhen-connected-surface-open")
            } finally {
                theme.elsewhenVisible = false
            }
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

        function test_reduced_screen_width_render() {
            var oldWidth = testRoot.width
            var oldScreen = theme.activePopupScreen
            var oldBarX = theme.elsewhenBarX
            try {
                testRoot.width = 300
                theme.activePopupScreen = ({ name: "DP-1", width: 300, height: 800 })
                theme.elsewhenBarX = 150
                for (var variant of ["v1", "v2"]) {
                    load(variant, false, "top")
                    compare(panelLoader.item.surfaceHost.width, 284)
                    verify(waitForRendering(panelLoader.item, 3000),
                        "reduced-width panel must render before capture")
                    captureScene(variant + "-narrow-width")
                }
            } finally {
                testRoot.width = oldWidth
                theme.activePopupScreen = oldScreen
                theme.elsewhenBarX = oldBarX
            }
        }

        function test_timezone_confirmation_render_all_adapters() {
            for (var variant of ["v1", "v2"]) {
                for (var vertical of [false, true]) {
                    load(variant, vertical, vertical ? "left" : "top")
                    var content = findChild(panelLoader.item, "elsewhen-panel-content")
                    var heroButton = findChild(content, "elsewhen-hero-globe-button")
                    verify(content !== null && heroButton !== null)
                    mouseClick(heroButton, heroButton.width / 2, heroButton.height / 2)
                    compare(content.globeExpanded, true)
                    tryCompare(content.globeCanvas, "height", 378, 1000)
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
                var heroButton = findChild(content, "elsewhen-hero-globe-button")
                verify(content !== null && heroButton !== null)
                mouseClick(heroButton, heroButton.width / 2, heroButton.height / 2)
                compare(content.globeExpanded, true)
                tryCompare(content.globeCanvas, "height", 378, 1000)
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

                var heroButton = findChild(content, "elsewhen-hero-globe-button")
                verify(heroButton !== null)
                mouseClick(heroButton, heroButton.width / 2, heroButton.height / 2)
                compare(content.globeExpanded, true)
                tryCompare(content.globeCanvas, "height", 378, 1000)
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

        function test_initial_list_hides_globe_and_search_controls() {
            for (var variant of ["v1", "v2"]) {
                load(variant, false, "top")
                var content = findChild(panelLoader.item, "elsewhen-panel-content")
                verify(content !== null)
                compare(content.globeExpanded, false)
                verify(content.cityList.visible)
                verify(findChild(content, "elsewhen-add-city").visible)
                compare(content.globeCanvas.parent.visible, false)
                compare(content.zoneSearchInput.parent.visible, false)
                compare(content.hour24Button.visible, false)
                compare(content.globeToggleButton.visible, false)
                compare(content.changeTimezoneButton.visible, false)
                compare(content.globeZoomButton.visible, false)
            }
        }

        function test_options_disclosure_renders_controls_in_bounds() {
            var oldPreferences = fakeService.preferenceData
            var oldRefreshRequests = fakeService.refreshRequests
            try {
                for (var variant of ["v1", "v2"]) {
                    fakeService.preferenceData = Object.assign({}, oldPreferences,
                        { hour24: true, globeEnabled: true })
                    fakeService.refreshRequests = 0
                    load(variant, false, "top")
                    var content = findChild(panelLoader.item, "elsewhen-panel-content")
                    var row = findChild(content, "elsewhen-options-row")
                    verify(content !== null && row !== null)
                    verify(findChild(content, "elsewhen-clock-options") === null)
                    content.forceActiveFocus()
                    keyClick(Qt.Key_O)
                    compare(content.optionsExpanded, true)
                    verify(row.visible && row.height >= 28)
                    var header = findChild(content, "elsewhen-world-clock-header")
                    verify(header !== null)
                    verify(waitForRendering(panelLoader.item, 3000),
                        "disclosed options must render before pointer input")
                    verify(row.y >= header.height,
                        "disclosed actions must be positioned below the header before clicking")
                    for (var control of [content.refreshButton, content.hour24Button,
                            content.globeToggleButton, content.changeTimezoneButton, content.globeZoomButton]) {
                        if (control.available === false) continue
                        var point = control.mapToItem(panelLoader.item.surfaceHost, 0, 0)
                        verify(point.x >= 0 && point.x + control.width <= panelLoader.item.surfaceHost.width)
                        verify(point.y >= 0 && point.y + control.height <= panelLoader.item.surfaceHost.height)
                    }
                    captureScene(variant + "-options-disclosure")
                    mouseClick(content.hour24Button, content.hour24Button.width / 2, content.hour24Button.height / 2)
                    compare(fakeService.preferenceData.hour24, false)
                    mouseClick(content.refreshButton, content.refreshButton.width / 2, content.refreshButton.height / 2)
                    compare(fakeService.refreshRequests, 1)
                    mouseClick(content.globeToggleButton, content.globeToggleButton.width / 2,
                        content.globeToggleButton.height / 2)
                    compare(fakeService.preferenceData.globeEnabled, false)
                    verify(!content.globeCanvas.visible)
                    mouseClick(content.globeToggleButton, content.globeToggleButton.width / 2,
                        content.globeToggleButton.height / 2)
                    compare(fakeService.preferenceData.globeEnabled, true)
                    mouseClick(content.globeZoomButton, content.globeZoomButton.width / 2,
                        content.globeZoomButton.height / 2)
                    compare(content.globeExpanded, true)
                    compare(content.optionsExpanded, false)
                    verify(waitForRendering(panelLoader.item, 3000),
                        "expanded globe must settle with options collapsed")
                    content.forceActiveFocus()
                    keyClick(Qt.Key_O)
                    compare(content.optionsExpanded, true)
                    verify(waitForRendering(panelLoader.item, 3000),
                        "collapsed options must reopen over the globe")
                    compare(content.globeZoomButton.label, "Back")
                    mouseClick(content.globeZoomButton, content.globeZoomButton.width / 2,
                        content.globeZoomButton.height / 2)
                    compare(content.globeExpanded, false)
                    compare(content.optionsExpanded, false)
                    tryCompare(content.globeCanvas, "height", 0, 1000)
                    captureScene(variant + "-globe-returned")
                }
            } finally {
                fakeService.preferenceData = oldPreferences
                fakeService.refreshRequests = oldRefreshRequests
            }
        }

        function test_list_city_rows_match_original_density() {
            for (var variant of ["v1", "v2"]) {
                load(variant, false, "top")
                var content = findChild(panelLoader.item, "elsewhen-panel-content")
                verify(content !== null)
                verify(waitForRendering(panelLoader.item, 3000))
                for (var index = 0; index < 2; index++) {
                    var row = content.cityList.itemAtIndex(index)
                    verify(row !== null)
                    verify(Math.abs(row.height - 88.75) <= 2)
                }
                var firstRow = content.cityList.itemAtIndex(0)
                var secondRow = content.cityList.itemAtIndex(1)
                compare(Math.round(secondRow.y - firstRow.y - firstRow.height), 6)
            }
        }

        function test_hero_mini_globe_uses_the_original_foreground_land() {
            load("v1", false, "top")
            var content = findChild(panelLoader.item, "elsewhen-panel-content")
            var miniGlobe = findChild(content, "elsewhen-hero-globe-icon")
            verify(miniGlobe !== null)
            compare(miniGlobe.land.toString(), content.palette.ink.toString(),
                "the original MiniGlobe uses foreground for its land fill")
        }

        function test_reference_header_and_city_actions_have_no_extra_controls() {
            for (var variant of ["v1", "v2"]) {
                load(variant, false, "top")
                var content = findChild(panelLoader.item, "elsewhen-panel-content")
                verify(content !== null)
                compare(findChild(content, "elsewhen-clock-options"), null,
                    "the reference header has no ellipsis/options control")
                var addCity = findChild(content, "elsewhen-add-city")
                verify(addCity !== null && addCity.visible,
                    "the reference panel keeps its Add city action below the list")
                compare(addCity.height, 28)
                var expectedActionRadius = variant === "v1" ? theme.tileRadius : theme.panelButtonRadius
                compare(addCity.radius, expectedActionRadius)
                compare(addCity.Accessible.name, "Add city")

                var hero = findChild(content, "elsewhen-hero-globe-button")
                verify(hero !== null && hero.enabled)
                var heroPointerAreas = hero.children.filter(function(child) {
                    return child.containsMouse !== undefined
                })
                compare(heroPointerAreas.length, 1)
                mouseMove(hero, hero.width / 2, hero.height / 2)
                tryVerify(function() { return heroPointerAreas[0].containsMouse }, 500)
                var hoverSurfaces = hero.children.filter(function(child) {
                    return child.color !== undefined
                        && child.color.toString() === content.palette.fillHover.toString()
                })
                compare(hoverSurfaces.length, 0,
                    "the original hero globe has no hover-fill tile")
                var titleRow = findChild(content, "elsewhen-world-title-row")
                verify(titleRow !== null)
                var worldWord = findChild(content, "elsewhen-world-title")
                var clockWord = findChild(content, "elsewhen-clock-title")
                verify(worldWord !== null && clockWord !== null)
                var referenceGlobeSize = Math.round(Commons.Style.font.display * 1.3)
                compare(Math.round(hero.width), referenceGlobeSize,
                    "the hero globe uses Omarchy HeroTitle sizing")
                compare(Math.round(titleRow.height), referenceGlobeSize,
                    "the World Clock title row follows the original hero height")
                compare(Math.round(worldWord.y + worldWord.height / 2), Math.round(titleRow.height / 2),
                    "World is vertically centered against the hero globe")
                compare(Math.round(clockWord.y + clockWord.height / 2), Math.round(titleRow.height / 2),
                    "Clock is vertically centered against the hero globe")
                mouseClick(hero, hero.width / 2, hero.height / 2)
                tryCompare(content.globeCanvas, "height", 378, 1500)
                var jump = findChild(content, "elsewhen-globe-jump")
                verify(jump !== null && jump.visible)
                compare(jump.radius, expectedActionRadius)
            }
        }

        function test_city_action_buttons_activate_by_keyboard() {
            for (var variant of ["v1", "v2"]) {
                load(variant, false, "top")
                var content = findChild(panelLoader.item, "elsewhen-panel-content")
                verify(content !== null)
                var addCity = findChild(content, "elsewhen-add-city")
                verify(addCity !== null && addCity.visible)
                addCity.forceActiveFocus()
                keyClick(Qt.Key_Return)
                tryCompare(content, "searchMode", "add", 500)
                tryVerify(function() { return content.zoneSearchInput.activeFocus }, 500)

                content.searchMode = ""
                content.searchText = ""
                content.forceActiveFocus()
                verify(waitForRendering(panelLoader.item, 3000))
                var hero = findChild(content, "elsewhen-hero-globe-button")
                verify(hero !== null && hero.enabled)
                mouseClick(hero, hero.width / 2, hero.height / 2)
                tryCompare(content.globeCanvas, "height", 378, 1500)
                var jump = findChild(content, "elsewhen-globe-jump")
                verify(jump !== null && jump.visible)
                jump.forceActiveFocus()
                keyClick(Qt.Key_Space)
                tryCompare(content, "searchMode", "jump", 500)
                tryVerify(function() { return content.zoneSearchInput.activeFocus }, 500)
                content.searchMode = ""
                content.searchText = ""
                content.forceActiveFocus()
            }
        }

        function test_city_action_buttons_remain_in_bounds_narrow_and_vertical() {
            var saved = {
                width: testRoot.width,
                height: testRoot.height,
                screen: theme.activePopupScreen,
                barX: theme.elsewhenBarX,
                barPosition: theme.barPosition,
                barVertical: theme.barVertical,
                visible: theme.elsewhenVisible
            }
            var scenarios = [
                { variant: "v1", vertical: false, width: 300, position: "top" },
                { variant: "v1", vertical: true, width: 414, position: "left" },
                { variant: "v2", vertical: false, width: 300, position: "top" },
                { variant: "v2", vertical: true, width: 414, position: "right" }
            ]
            try {
                for (var scenario of scenarios) {
                    testRoot.width = scenario.width
                    testRoot.height = 774
                    theme.activePopupScreen = ({ name: "DP-1", width: scenario.width, height: 774 })
                    theme.elsewhenBarX = Math.round(scenario.width / 2)
                    load(scenario.variant, scenario.vertical, scenario.position)
                    var surface = panelLoader.item.surfaceHost
                    var content = findChild(panelLoader.item, "elsewhen-panel-content")
                    verify(content !== null)
                    verify(waitForRendering(panelLoader.item, 3000),
                        "city-action geometry must settle before bounds are checked")
                    var addCity = findChild(content, "elsewhen-add-city")
                    verify(addCity !== null && addCity.visible)
                    var addPoint = addCity.mapToItem(surface, 0, 0)
                    verify(addPoint.x >= 0 && addPoint.x + addCity.width <= surface.width)
                    verify(addPoint.y >= 0 && addPoint.y + addCity.height <= surface.height)
                    var layout = scenario.vertical ? "vertical" : "narrow"
                    captureScene(scenario.variant + "-" + layout + "-add-city-action")

                    var hero = findChild(content, "elsewhen-hero-globe-button")
                    verify(hero !== null && hero.enabled)
                    mouseClick(hero, hero.width / 2, hero.height / 2)
                    tryCompare(content.globeCanvas, "height", 378, 1500)
                    content.globeCanvas.requestPaint()
                    verify(waitForRendering(panelLoader.item, 3000),
                        "expanded globe geometry must settle before Jump bounds are checked")
                    var jump = findChild(content, "elsewhen-globe-jump")
                    verify(jump !== null && jump.visible)
                    var jumpPoint = jump.mapToItem(surface, 0, 0)
                    verify(jumpPoint.x >= 0 && jumpPoint.x + jump.width <= surface.width)
                    verify(jumpPoint.y >= 0 && jumpPoint.y + jump.height <= surface.height)
                    captureScene(scenario.variant + "-" + layout + "-jump-city-action")
                    content.forceActiveFocus()
                }
            } finally {
                theme.elsewhenVisible = false
                testRoot.width = saved.width
                testRoot.height = saved.height
                theme.activePopupScreen = saved.screen
                theme.elsewhenBarX = saved.barX
                theme.barPosition = saved.barPosition
                theme.barVertical = saved.barVertical
                theme.elsewhenVisible = saved.visible
            }
        }

        function test_city_action_buttons_follow_variant_style_and_focus() {
            var saved = {
                fillIdle: theme.fillIdle,
                fillHoverAlpha: theme.fillHoverAlpha,
                ink: theme.ink,
                seal: theme.seal,
                sep: theme.sep,
                mono: theme.mono,
                tileRadius: theme.tileRadius,
                panelButtonRadius: theme.panelButtonRadius
            }
            try {
                theme.fillIdle = "#20242b"
                theme.fillHoverAlpha = 0.27
                theme.ink = "#d4dbe8"
                theme.seal = "#8aaeff"
                theme.sep = "#596275"
                theme.mono = "monospace"
                theme.tileRadius = 4
                theme.panelButtonRadius = 9
                var hoverFill = Qt.rgba(theme.seal.r, theme.seal.g, theme.seal.b,
                    theme.fillHoverAlpha)
                for (var variant of ["v1", "v2"]) {
                    load(variant, false, "top")
                    var content = findChild(panelLoader.item, "elsewhen-panel-content")
                    verify(content !== null)
                    var stylePalette = content.palette
                    var expectedRadius = variant === "v1" ? theme.tileRadius : theme.panelButtonRadius
                    var addCity = findChild(content, "elsewhen-add-city")
                    verify(addCity !== null && addCity.visible)
                    compare(addCity.radius, expectedRadius)
                    compare(addCity.color.toString(), stylePalette.fillIdle.toString())
                    compare(addCity.border.width, 1)
                    compare(addCity.border.color.toString(), stylePalette.sep.toString())
                    compare(addCity.activeFocusOnTab, true)
                    compare(addCity.Accessible.role, Accessible.Button)
                    compare(addCity.Accessible.name, "Add city")
                    var addLabel = addCity.children.filter(function(child) {
                        return child.text !== undefined && child.font !== undefined
                    })[0]
                    verify(addLabel !== undefined)
                    compare(addLabel.text, content.tr("elsewhen.addCity", "Add city"))
                    compare(addLabel.color.toString(), stylePalette.ink.toString())
                    compare(addLabel.font.family, stylePalette.mono)
                    compare(addLabel.font.pixelSize, 11)

                    mouseMove(addCity, addCity.width / 2, addCity.height / 2)
                    tryCompare(addCity, "color", hoverFill, 500)
                    compare(addCity.border.color.toString(), theme.seal.toString())
                    compare(addLabel.color.toString(), theme.seal.toString())
                    mouseMove(testRoot, testRoot.width - 2, testRoot.height - 2)
                    addCity.forceActiveFocus()
                    tryVerify(function() { return addCity.activeFocus }, 500)
                    compare(addCity.color.toString(), hoverFill.toString())
                    compare(addCity.border.color.toString(), theme.seal.toString())
                    compare(addLabel.color.toString(), theme.seal.toString())

                    var hero = findChild(content, "elsewhen-hero-globe-button")
                    verify(hero !== null && hero.enabled)
                    mouseClick(hero, hero.width / 2, hero.height / 2)
                    tryCompare(content.globeCanvas, "height", 378, 1500)
                    var jump = findChild(content, "elsewhen-globe-jump")
                    verify(jump !== null && jump.visible)
                    compare(jump.radius, expectedRadius)
                    compare(jump.color.toString(), stylePalette.fillIdle.toString())
                    compare(jump.border.width, 1)
                    compare(jump.border.color.toString(), stylePalette.sep.toString())
                    compare(jump.activeFocusOnTab, true)
                    compare(jump.Accessible.role, Accessible.Button)
                    compare(jump.Accessible.name, content.tr("elsewhen.jumpToCity", "Jump to a city"))
                    var jumpLabel = jump.children.filter(function(child) {
                        return child.text !== undefined && child.font !== undefined
                    })[0]
                    verify(jumpLabel !== undefined)
                    compare(jumpLabel.text, content.tr("elsewhen.jumpToCity", "Jump to a city"))
                    compare(jumpLabel.color.toString(), stylePalette.ink.toString())
                    compare(jumpLabel.font.family, stylePalette.mono)
                    compare(jumpLabel.font.pixelSize, 11)
                    mouseMove(jump, jump.width / 2, jump.height / 2)
                    tryCompare(jump, "color", hoverFill, 500)
                    compare(jump.border.color.toString(), theme.seal.toString())
                    compare(jumpLabel.color.toString(), theme.seal.toString())
                    mouseMove(testRoot, testRoot.width - 2, testRoot.height - 2)
                    content.forceActiveFocus()
                }
            } finally {
                theme.fillIdle = saved.fillIdle
                theme.fillHoverAlpha = saved.fillHoverAlpha
                theme.ink = saved.ink
                theme.seal = saved.seal
                theme.sep = saved.sep
                theme.mono = saved.mono
                theme.tileRadius = saved.tileRadius
                theme.panelButtonRadius = saved.panelButtonRadius
            }
        }

        function test_city_rows_render_original_weather_glyphs() {
            var oldWeather = fakeService.weather
            var oldPreferences = fakeService.preferenceData
            try {
                fakeService.weather = {
                    "Paris|Europe/Paris": { c: 16, w: 0 },
                    "Tokyo|Asia/Tokyo": { c: 16, w: 3 }
                }
                fakeService.preferenceData = Object.assign({}, oldPreferences, { units: "C" })
                for (var variant of ["v1", "v2"]) {
                    load(variant, false, "top")
                    var content = findChild(panelLoader.item, "elsewhen-panel-content")
                    var row = content.cityList.itemAtIndex(0)
                    var glyph = findChild(row, "elsewhen-weather-glyph")
                    verify(glyph !== null, "city row must render the original weather glyph slot")
                    compare(glyph.text, "\udb81\udda8")
                    compare(findChild(row, "elsewhen-weather-temperature").text, "16°C")
                }
            } finally {
                fakeService.weather = oldWeather
                fakeService.preferenceData = oldPreferences
            }
        }

        function test_city_rows_use_original_phase_fill_and_bar_config_daylight_color() {
            var oldRows = fakeService.clockRows
            var oldProbe = fakeService.probe
            var oldSeal = theme.seal
            try {
                fakeService.probe = ({})
                fakeService.clockRows = [
                    { label: "Paris", id: "Europe/Paris", ready: true, phase: "day", lit: true },
                    { label: "Tokyo", id: "Asia/Tokyo", ready: true, phase: "night", lit: false }
                ]
                theme.seal = "#7aa2f7"
                for (var variant of ["v1", "v2"]) {
                    load(variant, false, "top")
                    var content = findChild(panelLoader.item, "elsewhen-panel-content")
                    var dayRow = content.cityList.itemAtIndex(0)
                    var nightRow = content.cityList.itemAtIndex(1)
                    compare(dayRow.border.width, 0)
                    compare(nightRow.border.width, 0)
                    verify(dayRow.color.toString() !== nightRow.color.toString(),
                        "city row fills must reflect daylight phase")
                    var strip = findChild(dayRow, "elsewhen-daylight-strip")
                    verify(strip !== null)
                    compare(content.daylightMarker.toString(), theme.seal.toString(),
                        "globe daylight points must use the configured bar color")
                    compare(strip.daylightMarker.toString(), theme.seal.toString(),
                        "daylight strip points must use the configured bar color")
                    theme.seal = "#e6a8d7"
                    compare(content.daylightMarker.toString(), theme.seal.toString(),
                        "globe points must react when the configured bar color changes")
                    compare(strip.daylightMarker.toString(), theme.seal.toString(),
                        "strip points must react when the configured bar color changes")
                }
            } finally {
                theme.seal = oldSeal
                fakeService.clockRows = oldRows
                fakeService.probe = oldProbe
            }
        }

        function test_three_city_reference_fixture_and_globe_toggle_states() {
            var saved = {
                width: testRoot.width,
                height: testRoot.height,
                screen: theme.activePopupScreen,
                barX: theme.elsewhenBarX,
                v2BarHeight: theme.v2BarHeight,
                cities: fakeService.cities,
                clockRows: fakeService.clockRows,
                cityData: fakeService.cityData,
                weather: fakeService.weather,
                probe: fakeService.probe,
                localZone: fakeService.localZone,
                localOffsetMinutes: fakeService.localOffsetMinutes,
                nowMs: fakeService.nowMs,
                formatLocale: fakeService.formatLocale,
                preferenceData: fakeService.preferenceData
            }
            try {
                testRoot.width = 366
                testRoot.height = 498
                theme.activePopupScreen = ({ name: "DP-1", width: 366, height: 498 })
                theme.elsewhenBarX = 178
                theme.v2BarHeight = 0
                fakeService.formatLocale = "en_US"
                fakeService.localZone = "America/Sao_Paulo"
                fakeService.localOffsetMinutes = -180
                fakeService.nowMs = Date.UTC(2026, 10, 14, 14, 2, 0)
                fakeService.cities = [
                    { label: "Brasília", id: "America/Sao_Paulo", lat: -15.77972, lon: -47.92972 },
                    { label: "Sydney", id: "Australia/Sydney", lat: -33.8688, lon: 151.2093 },
                    { label: "Tokyo", id: "Asia/Tokyo", lat: 35.6762, lon: 139.6503 }
                ]
                fakeService.cityData = [
                    ["Brasília", "America/Sao_Paulo", -15.77972, -47.92972, 1],
                    ["Sydney", "Australia/Sydney", -33.8688, 151.2093, 1],
                    ["Tokyo", "Asia/Tokyo", 35.6762, 139.6503, 1]
                ]
                fakeService.probe = ({})
                fakeService.clockRows = [
                    { label: "Brasília", id: "America/Sao_Paulo", time: "11:02", date: "Sat Nov 14", dayLabel: "", meridiem: "AM", abbr: "-03", relative: "", ready: true, offsetMinutes: -180, progress: 0.55, lit: true, phase: "day" },
                    { label: "Sydney", id: "Australia/Sydney", time: "1:02", date: "Sun Nov 15", dayLabel: "Tomorrow", meridiem: "AM", abbr: "AEDT", relative: "+14h", ready: true, offsetMinutes: 660, progress: 0.04, lit: false, phase: "night" },
                    { label: "Tokyo", id: "Asia/Tokyo", time: "11:02", date: "Sat Nov 14", dayLabel: "", meridiem: "PM", abbr: "JST", relative: "+12h", ready: true, offsetMinutes: 540, progress: 0.96, lit: false, phase: "night" }
                ]
                fakeService.weather = {
                    "Brasília|America/Sao_Paulo": { c: 26, w: 0 },
                    "Sydney|Australia/Sydney": { c: 20, w: 2 },
                    "Tokyo|Asia/Tokyo": { c: 13, w: 3 }
                }
                fakeService.preferenceData = {
                    hour24: false, globeEnabled: true, smoothMotion: true, units: "C", offsetMode: "home",
                    here: { name: "Brasília", zone: "America/Sao_Paulo", lat: -15.77972, lon: -47.92972 }
                }
                for (var variant of ["v1", "v2"]) {
                    fakeService.preferenceData = Object.assign({}, fakeService.preferenceData, { globeEnabled: true })
                    load(variant, false, "top")
                    var content = findChild(panelLoader.item, "elsewhen-panel-content")
                    compare(content.cityList.count, 3)
                    tryCompare(content.cityList, "count", 3)
                    for (var i = 0; i < 3; i++) {
                        var row = content.cityList.itemAtIndex(i)
                        verify(row !== null)
                        verify(findChild(row, "elsewhen-weather-glyph").visible)
                        verify(findChild(row, "elsewhen-weather-temperature").text !== "")
                    }
                    verify(waitForRendering(panelLoader.item, 3000))
                    captureScene(variant + "-reference-three-city-default")
                    content.forceActiveFocus()
                    keyClick(Qt.Key_O)
                    compare(content.optionsExpanded, true)
                    verify(waitForRendering(panelLoader.item, 3000))
                    var optionRow = findChild(content, "elsewhen-options-row")
                    var header = findChild(content, "elsewhen-world-clock-header")
                    verify(optionRow !== null && header !== null)
                    compare(content.width, content.parent.width - 24)
                    compare(content.cityList.width, content.width - 6)
                    compare(Math.round(optionRow.y - header.y - header.height), 14)
                    compare(Math.round(content.cityList.y - optionRow.y - optionRow.height), 14)
                    captureScene(variant + "-reference-three-city-options")
                    compare(content.globeToggleButton.label, "Hide globe")
                    mouseClick(content.globeToggleButton, content.globeToggleButton.width / 2,
                        content.globeToggleButton.height / 2)
                    compare(fakeService.preferenceData.globeEnabled, false)
                    compare(content.globeToggleButton.label, "Show globe")
                    verify(!content.globeZoomButton.available)
                    verify(waitForRendering(panelLoader.item, 3000))
                    captureScene(variant + "-reference-three-city-globe-disabled")
                }
            } finally {
                testRoot.width = saved.width
                testRoot.height = saved.height
                theme.activePopupScreen = saved.screen
                theme.elsewhenBarX = saved.barX
                theme.v2BarHeight = saved.v2BarHeight
                fakeService.cities = saved.cities
                fakeService.clockRows = saved.clockRows
                fakeService.cityData = saved.cityData
                fakeService.weather = saved.weather
                fakeService.probe = saved.probe
                fakeService.localZone = saved.localZone
                fakeService.localOffsetMinutes = saved.localOffsetMinutes
                fakeService.nowMs = saved.nowMs
                fakeService.formatLocale = saved.formatLocale
                fakeService.preferenceData = saved.preferenceData
            }
        }

        function test_omarchy_content_palette_and_v2_connected_panel_style() {
            var saved = {
                bg: theme.bg,
                panelBorder: theme.panelBorder,
                panelOuterBorderColor: theme.panelOuterBorderColor,
                panelOuterBorderW: theme.panelOuterBorderW,
                panelRadius: theme.panelRadius,
                panelButtonRadius: theme.panelButtonRadius,
                pillBorder: theme.pillBorder,
                pillBorderW: theme.pillBorderW,
                pillRadius: theme.pillRadius,
                tileRadius: theme.tileRadius
            }
            try {
                for (var variant of ["v1", "v2"]) {
                    load(variant, false, "top")
                    var content = findChild(panelLoader.item, "elsewhen-panel-content")
                    var row = content.cityList.itemAtIndex(0)
                    verify(row !== null)
                    compare(row.foreground, Commons.Color.popups.text)
                    compare(row.surfaceBase, Commons.Color.popups.background)
                    compare(row.fontFamily, Commons.Style.font.family)
                }
                theme.bg = "#191a28"
                theme.pillBorder = "#bb9af7"
                theme.pillBorderW = 2
                theme.pillRadius = 13
                theme.tileRadius = 4
                load("v1", false, "top")
                compare(panelLoader.item.frameColor.toString(), theme.bg.toString())
                compare(panelLoader.item.frameBorderColor.toString(), theme.pillBorder.toString())
                compare(panelLoader.item.frameBorderWidth, theme.pillBorderW)
                compare(panelLoader.item.frameRadius, theme.pillRadius)
                compare(panelLoader.item.buttonRadius, theme.tileRadius)

                theme.panelBorder = "#7aa2f7"
                theme.panelOuterBorderColor = "#bb9af7"
                theme.panelOuterBorderW = 2
                theme.panelRadius = 9
                theme.panelButtonRadius = 5
                load("v2", false, "top")
                compare(panelLoader.item.frameColor.a, 0)
                compare(panelLoader.item.frameBorderColor.toString(), theme.panelBorder.toString())
                compare(panelLoader.item.frameBorderWidth, 0)
                compare(panelLoader.item.buttonRadius, theme.panelButtonRadius)
                verify(findChild(panelLoader.item, "elsewhen-connected-panel-surface") !== null,
                    "V2 Elsewhen frame must use the shared connected panel surface")
            } finally {
                theme.bg = saved.bg
                theme.panelBorder = saved.panelBorder
                theme.panelOuterBorderColor = saved.panelOuterBorderColor
                theme.panelOuterBorderW = saved.panelOuterBorderW
                theme.panelRadius = saved.panelRadius
                theme.panelButtonRadius = saved.panelButtonRadius
                theme.pillBorder = saved.pillBorder
                theme.pillBorderW = saved.pillBorderW
                theme.pillRadius = saved.pillRadius
                theme.tileRadius = saved.tileRadius
            }
        }

        function test_six_city_reference_fixture_and_capture() {
            var saved = {
                width: testRoot.width,
                height: testRoot.height,
                screen: theme.activePopupScreen,
                barX: theme.elsewhenBarX,
                barHeight: theme.v2BarHeight,
                bg: theme.bg,
                ink: theme.ink,
                seal: theme.seal,
                sep: theme.sep,
                fillIdle: theme.fillIdle,
                fillHover: theme.fillHover,
                fillActive: theme.fillActive,
                panelBorder: theme.panelBorder,
                panelOuterBorderColor: theme.panelOuterBorderColor,
                panelRadius: theme.panelRadius,
                panelButtonRadius: theme.panelButtonRadius,
                pillRadius: theme.pillRadius,
                pillBorder: theme.pillBorder,
                tileRadius: theme.tileRadius,
                mono: theme.mono,
                cities: fakeService.cities,
                cityData: fakeService.cityData,
                probe: fakeService.probe,
                weather: fakeService.weather,
                localZone: fakeService.localZone,
                localOffsetMinutes: fakeService.localOffsetMinutes,
                nowMs: fakeService.nowMs,
                formatLocale: fakeService.formatLocale,
                preferenceData: fakeService.preferenceData
            }
            try {
                testRoot.width = 414
                testRoot.height = 774
                theme.activePopupScreen = ({ name: "DP-1", width: 414, height: 774 })
                theme.elsewhenBarX = 212
                theme.v2BarHeight = 51
                theme.bg = "#1a1b26"
                theme.ink = "#a9b1d6"
                theme.seal = "#7aa2f7"
                theme.sep = "#414868"
                theme.fillIdle = "#1a1b26"
                theme.fillHover = "#24283b"
                theme.fillActive = "#292e42"
                theme.panelBorder = "#7aa2f7"
                theme.panelOuterBorderColor = "#7aa2f7"
                theme.panelRadius = 6
                theme.panelButtonRadius = 6
                theme.pillRadius = 6
                theme.pillBorder = "#414868"
                theme.tileRadius = 6
                theme.mono = "monospace"
                fakeService.formatLocale = "en_US"
                fakeService.localZone = "America/New_York"
                fakeService.localOffsetMinutes = -240
                fakeService.nowMs = Date.UTC(2020, 9, 20, 18, 48, 0)
                fakeService.cities = [
                    { label: "Cincinnati", id: "America/New_York", lat: 39.1031, lon: -84.5120, people: ["Jamie Example", "Sam Taylor", "Alex Morgan"] },
                    { label: "Copenhagen", id: "Europe/Copenhagen", lat: 55.6761, lon: 12.5683, people: ["Morgan Example"] },
                    { label: "Amsterdam", id: "Europe/Amsterdam", lat: 52.3676, lon: 4.9041, people: ["Taylor Example"] },
                    { label: "Brisbane", id: "Australia/Brisbane", lat: -27.4698, lon: 153.0251, people: ["Jordan Example"] },
                    { label: "Tokyo", id: "Asia/Tokyo", lat: 35.6762, lon: 139.6503, people: ["Riley Example"] },
                    { label: "Toronto", id: "America/Toronto", lat: 43.6532, lon: -79.3832, people: ["Kai Example"] }
                ]
                var referenceCityData = [
                    ["Cincinnati", "America/New_York", 39.1031, -84.5120, 1],
                    ["Copenhagen", "Europe/Copenhagen", 55.6761, 12.5683, 1],
                    ["Amsterdam", "Europe/Amsterdam", 52.3676, 4.9041, 1],
                    ["Brisbane", "Australia/Brisbane", -27.4698, 153.0251, 1],
                    ["Tokyo", "Asia/Tokyo", 35.6762, 139.6503, 1],
                    ["Toronto", "America/Toronto", 43.6532, -79.3832, 1]
                ]
                fakeService.cityData = testRoot.captureDir === ""
                    ? referenceCityData : referenceCityData.concat(fakeService.cityData)
                fakeService.probe = {
                    "America/New_York": { offsetMinutes: -240, abbr: "EDT" },
                    "Europe/Copenhagen": { offsetMinutes: 120, abbr: "CEST" },
                    "Europe/Amsterdam": { offsetMinutes: 120, abbr: "CEST" },
                    "Australia/Brisbane": { offsetMinutes: 600, abbr: "AEST" },
                    "Asia/Tokyo": { offsetMinutes: 540, abbr: "JST" },
                    "America/Toronto": { offsetMinutes: -240, abbr: "EDT" }
                }
                fakeService.weather = {
                    "Cincinnati|America/New_York": { c: 23, w: 0 },
                    "Copenhagen|Europe/Copenhagen": { c: 10.5, w: 3 },
                    "Amsterdam|Europe/Amsterdam": { c: 11, w: 2 },
                    "Brisbane|Australia/Brisbane": { c: 16, w: 3 },
                    "Tokyo|Asia/Tokyo": { c: 18.5, w: 0 },
                    "Toronto|America/Toronto": { c: 16.5, w: 0 }
                }
                fakeService.preferenceData = {
                    hour24: true, globeEnabled: true, smoothMotion: true, units: "F", offsetMode: "here",
                    here: { name: "Fort Lauderdale", zone: "America/New_York", lat: 26.1224, lon: -80.1373 }
                }
                for (var variant of ["v1", "v2"]) {
                    fakeService.nowMs = Date.UTC(2020, 9, 20, 18, 48, 0)
                    fakeService.preferenceData = Object.assign({}, fakeService.preferenceData, { hour24: true })
                    load(variant, false, "top")
                    var content = findChild(panelLoader.item, "elsewhen-panel-content")
                    verify(content !== null)
                    tryCompare(content.cityList, "count", 6)
                    var referenceHeader = findChild(content, "elsewhen-world-clock-header")
                    var firstRow = content.cityList.itemAtIndex(0)
                    verify(referenceHeader !== null && firstRow !== null)
                    verify(waitForRendering(panelLoader.item, 3000))
                    var headerBottom = referenceHeader.mapToItem(content.scrollArea, 0, 0).y
                        + referenceHeader.height
                    var firstRowTop = firstRow.mapToItem(content.scrollArea, 0, 0).y
                    compare(Math.round(firstRowTop - headerBottom), 19,
                        "reference has the original header-to-first-row breathing room")
                    compare(panelLoader.item.surfaceHost.height, 680,
                        "the six-city fixture matches Omarchy's 680px panel cap")
                    compare(panelLoader.item.surfaceHost.width, 340,
                        "the six-city fixture matches the source video's native panel width")
                    var addCityAction = findChild(content, "elsewhen-add-city")
                    verify(addCityAction !== null && addCityAction.visible)
                    var addCityPoint = addCityAction.mapToItem(content.scrollArea, 0, 0)
                    verify(addCityPoint.y >= content.scrollArea.height,
                        "Add city stays fully below the initial six-city viewport")
                    verify(content.scrollArea.contentHeight > content.scrollArea.height,
                        "six-city content remains scrollable")
                    try {
                        var maxScroll = content.scrollArea.contentHeight - content.scrollArea.height
                        verify(maxScroll > 0)
                        var wheelPoint = content.scrollArea.mapToItem(testRoot,
                            content.scrollArea.width / 2, content.scrollArea.height / 2)
                        for (var scrollStep = 0; scrollStep < 10; scrollStep++) {
                            mouseWheel(testRoot, wheelPoint.x, wheelPoint.y, 0, -120,
                                Qt.NoButton, Qt.NoModifier)
                            wait(20)
                        }
                        tryVerify(function() { return content.scrollArea.contentY >= maxScroll - 2 },
                            1000, "wheel events must reach the bottom of the six-city list")
                        var addVisiblePoint = addCityAction.mapToItem(content.scrollArea, 0, 0)
                        verify(addVisiblePoint.y >= 0
                            && addVisiblePoint.y + addCityAction.height <= content.scrollArea.height,
                            "scrolling reveals all of Add city inside the viewport")
                        verify(waitForRendering(panelLoader.item, 3000),
                            "six-city Add city geometry settles before capture")
                        captureScene(variant + "-six-city-add-visible")
                        var addClickPoint = addCityAction.mapToItem(testRoot,
                            addCityAction.width / 2, addCityAction.height / 2)
                        mouseMove(testRoot, addClickPoint.x, addClickPoint.y)
                        wait(30)
                        mouseClick(testRoot, addClickPoint.x, addClickPoint.y,
                            Qt.LeftButton, Qt.NoModifier)
                        tryCompare(content, "searchMode", "add", 500,
                            "real pointer activation opens Add city search")
                        var zoneSearchInput = findChild(content, "elsewhen-zone-search")
                        verify(zoneSearchInput !== null && zoneSearchInput.visible)
                        tryCompare(zoneSearchInput, "activeFocus", true, 500,
                            "Add city search receives keyboard focus")
                        keyClick(Qt.Key_T, Qt.ShiftModifier)
                        keyClick(Qt.Key_O)
                        keyClick(Qt.Key_K)
                        keyClick(Qt.Key_Y)
                        keyClick(Qt.Key_O)
                        tryCompare(zoneSearchInput, "text", "tokyo", 500)
                        compare(content.searchText, "tokyo")
                        verify(waitForRendering(panelLoader.item, 3000),
                            "six-city search layout settles before capture")
                        captureScene(variant + "-six-city-add-search")
                    } finally {
                        content.searchMode = ""
                        content.searchText = ""
                        content.scrollArea.contentY = 0
                        content.forceActiveFocus()
                    }
                    for (var i = 0; i < 6; i++) {
                        var row = content.cityList.itemAtIndex(i)
                        verify(row !== null)
                        verify(findChild(row, "elsewhen-weather-glyph").visible)
                        verify(findChild(row, "elsewhen-weather-temperature").text !== "")
                    }
                    content.scrubMinutes = 238
                    mouseMove(firstRow, firstRow.width / 2, firstRow.height / 2)
                    tryVerify(function() { return firstRow.hovered }, 500)
                    tryVerify(function() { return content.hereLine.indexOf("18:46") >= 0
                        && content.hereLine.indexOf("+3h 58m") >= 0 }, 500,
                        "unexpected reference time: " + content.hereLine)
                    compare(firstRow.rowData.time, "18:46")
                    var greeting = findChild(firstRow, "elsewhen-city-greeting-text")
                    var removeAction = findChild(firstRow, "elsewhen-city-remove")
                    var peopleAction = findChild(firstRow, "elsewhen-people-edit")
                    tryCompare(greeting, "visible", true, 500)
                    compare(greeting.text, "Good evening")
                    tryCompare(removeAction, "visible", true, 500)
                    tryCompare(peopleAction, "visible", true, 500)
                    var peopleGlyphs = peopleAction.children.filter(function(child) {
                        return child.text !== undefined
                    })
                    compare(peopleGlyphs.length, 1,
                        "the people action exposes one icon glyph")
                    compare(peopleGlyphs[0].text, "\udb80\udc14",
                        "the people action uses Omarchy's account-plus icon")
                    var referenceActionFill = Model.mix(content.palette.bg, content.palette.ink, 0.14)
                    var referenceActionBorder = Model.mix(content.palette.bg, content.palette.ink, 0.35)
                    compare(removeAction.color.toString(), referenceActionFill.toString())
                    compare(removeAction.border.color.toString(), referenceActionBorder.toString())
                    compare(peopleAction.color.toString(), referenceActionFill.toString())
                    compare(peopleAction.border.color.toString(), referenceActionBorder.toString())
                    var referenceActionSize = Commons.Style.font.bodySmall
                        + (Commons.Style.space(22) - Commons.Style.font.bodySmall) * 0.85
                    var removePoint = removeAction.mapToItem(firstRow, 0, 0)
                    var peoplePoint = peopleAction.mapToItem(firstRow, 0, 0)
                    compare(Math.round(removeAction.width), Math.round(referenceActionSize))
                    var removeCenterOffset = removePoint.x + removeAction.width / 2 - firstRow.width
                    var peopleCenterOffset = peoplePoint.x + peopleAction.width / 2 - firstRow.width
                    verify(Math.abs(removeCenterOffset - (-Commons.Style.space(22) * 5 / 24)) <= 1,
                        "the remove control stays on the reference row corner")
                    verify(Math.abs(peopleCenterOffset - (-Commons.Style.space(22) * 5 / 24
                        - referenceActionSize - Commons.Style.space(5))) <= 1,
                        "the people control stays beside the remove control")
                    verify(removePoint.x + removeAction.width > firstRow.width,
                        "the reference remove control straddles the row's right edge")
                    compare(Math.round(removePoint.y + removeAction.height / 2), 0,
                        "the reference action controls straddle the row's top edge")
                    verify(waitForRendering(panelLoader.item, 3000))
                    captureScene(variant + "-reference-six-city-list")
                    content.scrubMinutes = 0
                    var timeText = findChild(firstRow, "elsewhen-city-time")
                    verify(timeText !== null)
                    compare(timeText.text, "14:48")
                    mouseClick(timeText, timeText.width / 2, timeText.height / 2)
                    tryCompare(content, "hour24", false, 500)
                    tryCompare(timeText, "text", "2:48", 500)
                    compare(content.displayRows[0].meridiem, "PM")
                    mouseMove(testRoot, testRoot.width - 1, testRoot.height - 1)
                    tryVerify(function() { return !firstRow.hovered }, 500)
                    var hero = findChild(content, "elsewhen-hero-globe-button")
                    verify(hero !== null && hero.visible)
                    mouseClick(hero, hero.width / 2, hero.height / 2)
                    tryCompare(content, "globeExpanded", true, 1500)
                    tryCompare(content.globeCanvas, "height", 378, 1500)
                    tryVerify(function() { return !content.globeReduced }, 2000)
                    content.globeSpin = 139.6503
                    content.globeViewLat = 35.6762
                    verify(waitForRendering(panelLoader.item, 3000))
                    var globeRadius = content.globePaintRadius(content.globeCanvas.width,
                        content.globeCanvas.height)
                    var globeScene = content.globeScene(globeRadius)
                    var tokyoIndex = -1
                    for (var placeIndex = 0; placeIndex < globeScene.places.length; placeIndex++) {
                        var place = globeScene.places[placeIndex]
                        if (place.label === "Tokyo" && place.id === "Asia/Tokyo") tokyoIndex = placeIndex
                    }
                    verify(tokyoIndex >= 0, "fixture catalog includes Tokyo")
                    var tokyoMarker = null
                    for (var markerIndex = 0; markerIndex < globeScene.plotted.length; markerIndex++)
                        if (globeScene.plotted[markerIndex].index === tokyoIndex)
                            tokyoMarker = globeScene.plotted[markerIndex]
                    verify(tokyoMarker !== null, "Tokyo is visible on the globe")
                    var tokyoPoint = content.globeCanvas.mapToItem(content.globeDragArea,
                        content.globeCanvas.width / 2 + tokyoMarker.x,
                        content.globeDiscCenterY + tokyoMarker.y)
                    mouseClick(content.globeDragArea, tokyoPoint.x, tokyoPoint.y)
                    tryVerify(function() { return content.globeFooterPlace
                        && content.globeFooterPlace.label === "Tokyo" }, 1000)
                    compare(content.globeFooterBadge, "tracked")
                    fakeService.nowMs = Date.UTC(2020, 9, 20, 18, 49, 0)
                    tryVerify(function() { return !content.globeReduced }, 2000)
                    var stableScene = content.globeScene(content.globePaintRadius(
                        content.globeCanvas.width, content.globeCanvas.height))
                    if (testRoot.captureDir !== "")
                        verify(stableScene.labels.length > 8,
                            "the full reference catalog shows more than eight static globe labels")
                    else
                        verify(stableScene.labels.length > 0,
                            "the minimal six-city fixture retains static globe labels")
                    compare(content.globeSeaInk.toString(), content.palette.ink.toString(),
                        "city labels over the sea use foreground ink")
                    compare(content.globeLandInk.toString(), content.palette.bg.toString(),
                        "city labels over land use the popup surface ink")
                    verify(waitForRendering(panelLoader.item, 3000))
                    captureScene(variant + "-reference-six-city-globe")
                    if (variant === "v2" && testRoot.captureDir !== "") {
                        captureGlobeLabelProbe(content, "land", "Cincinnati", "America/New_York",
                            -84.5120, 39.1031)
                        captureGlobeLabelProbe(content, "sea", "Honolulu", "Pacific/Honolulu",
                            -157.8583, 21.3069)
                        captureGlobeLabelProbe(content, "coast", "Brisbane", "Australia/Brisbane",
                            153.0251, -27.4698)
                    }
                    content.globeSpin = -84.5120
                    content.globeViewLat = 39.1031
                    verify(waitForRendering(panelLoader.item, 3000))
                    tryVerify(function() { return !content.globeReduced }, 2000)
                    var labelScene = content.globeScene(content.globePaintRadius(
                        content.globeCanvas.width, content.globeCanvas.height))
                    var cincinnatiLabel = null
                    for (var labelIndex = 0; labelIndex < labelScene.labels.length; labelIndex++) {
                        var labelPlace = labelScene.places[labelScene.labels[labelIndex].index]
                        if (labelPlace.label === "Cincinnati" && labelPlace.id === "America/New_York")
                            cincinnatiLabel = labelScene.labels[labelIndex]
                    }
                    verify(cincinnatiLabel !== null, "tracked land label retains a visible hitbox")
                    var labelPoint = content.globeCanvas.mapToItem(content.globeDragArea,
                        content.globeCanvas.width / 2 + cincinnatiLabel.box.x + cincinnatiLabel.box.w / 2,
                        content.globeDiscCenterY + cincinnatiLabel.box.y + cincinnatiLabel.box.h / 2)
                    var labelLocal = content.globeCanvas.mapFromItem(content.globeDragArea,
                        labelPoint.x, labelPoint.y)
                    verify(Math.abs(labelLocal.x - (content.globeCanvas.width / 2
                        + cincinnatiLabel.box.x + cincinnatiLabel.box.w / 2)) < 0.5)
                    verify(Math.abs(labelLocal.y - (content.globeDiscCenterY
                        + cincinnatiLabel.box.y + cincinnatiLabel.box.h / 2)) < 0.5)
                    mouseMove(content.globeDragArea, labelPoint.x, labelPoint.y)
                    mousePress(content.globeDragArea, labelPoint.x, labelPoint.y,
                        Qt.LeftButton, Qt.NoModifier)
                    compare(content.globeReduced, false,
                        "a stationary label click keeps its hitbox while smoothMotion is enabled")
                    verify(content.globeScene(content.globePaintRadius(
                        content.globeCanvas.width, content.globeCanvas.height)).labels.length > 0)
                    mouseRelease(content.globeDragArea, labelPoint.x, labelPoint.y,
                        Qt.LeftButton, Qt.NoModifier)
                    tryCompare(content, "timezoneTarget", "America/New_York", 1000,
                        "real pointer hit on the label box selects its city")
                    compare(content.globeSelectionLabel, "Cincinnati")
                    tryVerify(function() { return !content.globeReduced }, 2000)
                    var dragX = content.globeDragArea.width / 2
                    var dragY = content.globeDragArea.height / 2
                    mousePress(content.globeDragArea, dragX, dragY)
                    compare(content.globeReduced, false,
                        "a stationary pointer-down is not globe motion")
                    mouseMove(content.globeDragArea, dragX + 12, dragY)
                    compare(content.globeReduced, true,
                        "smoothMotion removes labels during actual globe movement")
                    compare(content.globeScene(80).labels.length, 0)
                    mouseRelease(content.globeDragArea, dragX + 12, dragY)
                    tryVerify(function() { return !content.globeReduced }, 2000)
                    verify(content.globeScene(content.globePaintRadius(
                        content.globeCanvas.width, content.globeCanvas.height)).labels.length > 0,
                        "static globe labels return after drag motion settles")
                }
            } finally {
                testRoot.width = saved.width
                testRoot.height = saved.height
                theme.activePopupScreen = saved.screen
                theme.elsewhenBarX = saved.barX
                theme.v2BarHeight = saved.barHeight
                theme.bg = saved.bg
                theme.ink = saved.ink
                theme.seal = saved.seal
                theme.sep = saved.sep
                theme.fillIdle = saved.fillIdle
                theme.fillHover = saved.fillHover
                theme.fillActive = saved.fillActive
                theme.panelBorder = saved.panelBorder
                theme.panelOuterBorderColor = saved.panelOuterBorderColor
                theme.panelRadius = saved.panelRadius
                theme.panelButtonRadius = saved.panelButtonRadius
                theme.pillRadius = saved.pillRadius
                theme.pillBorder = saved.pillBorder
                theme.tileRadius = saved.tileRadius
                theme.mono = saved.mono
                fakeService.cities = saved.cities
                fakeService.cityData = saved.cityData
                fakeService.probe = saved.probe
                fakeService.weather = saved.weather
                fakeService.localZone = saved.localZone
                fakeService.localOffsetMinutes = saved.localOffsetMinutes
                fakeService.nowMs = saved.nowMs
                fakeService.formatLocale = saved.formatLocale
                fakeService.preferenceData = saved.preferenceData
            }
        }

        function test_add_city_access_after_wheeling_full_city_list() {
            var saved = {
                width: testRoot.width,
                height: testRoot.height,
                screen: theme.activePopupScreen,
                barX: theme.elsewhenBarX,
                barHeight: theme.v2BarHeight,
                cities: fakeService.cities,
                cityData: fakeService.cityData,
                preferences: fakeService.preferenceData
            }
            try {
                testRoot.width = 414
                testRoot.height = 774
                theme.activePopupScreen = ({ name: "DP-1", width: 414, height: 774 })
                theme.elsewhenBarX = 212
                theme.v2BarHeight = 51
                var cities = []
                var cityData = []
                for (var cityIndex = 0; cityIndex < 18; cityIndex++) {
                    var label = "City " + (cityIndex + 1)
                    cities.push({ label: label, id: "Etc/UTC", people: [] })
                    cityData.push([label, "Etc/UTC", 0, 0, 1])
                }
                fakeService.cities = cities
                fakeService.cityData = cityData
                fakeService.preferenceData = Object.assign({}, fakeService.preferenceData, {
                    globeEnabled: true, smoothMotion: true
                })
                for (var variant of ["v1", "v2"]) {
                    load(variant, false, "top")
                    var content = findChild(panelLoader.item, "elsewhen-panel-content")
                    verify(content !== null)
                    tryCompare(content.cityList, "count", 18)
                    compare(panelLoader.item.surfaceHost.height, 680)
                    verify(content.scrollArea.contentHeight > content.scrollArea.height,
                        "the full list must overflow the panel and remain scrollable")
                    var addCity = findChild(content, "elsewhen-add-city")
                    verify(addCity !== null && addCity.visible)
                    var maxScroll = content.scrollArea.contentHeight - content.scrollArea.height
                    var wheelPoint = content.scrollArea.mapToItem(testRoot,
                        content.scrollArea.width / 2, content.scrollArea.height / 2)
                    for (var step = 0; step < 50; step++) {
                        mouseWheel(testRoot, wheelPoint.x, wheelPoint.y, 0, -120,
                            Qt.NoButton, Qt.NoModifier)
                        wait(20)
                    }
                    tryVerify(function() { return content.scrollArea.contentY >= maxScroll - 2 },
                        1000, "real wheel events reach the end of the full city list; y="
                            + content.scrollArea.contentY + " max=" + maxScroll)
                    var addPoint = addCity.mapToItem(content.scrollArea, 0, 0)
                    verify(addPoint.y >= 0 && addPoint.y + addCity.height <= content.scrollArea.height,
                        "the entire Add city control is visible after scrolling the full list")
                    verify(waitForRendering(panelLoader.item, 3000),
                        "full-list Add city geometry settles before capture")
                    captureScene(variant + "-full-list-add-city-visible")
                    var clickPoint = addCity.mapToItem(testRoot,
                        addCity.width / 2, addCity.height / 2)
                    mouseMove(testRoot, clickPoint.x, clickPoint.y)
                    wait(30)
                    mouseClick(testRoot, clickPoint.x, clickPoint.y, Qt.LeftButton, Qt.NoModifier)
                    tryCompare(content, "searchMode", "add", 500)
                    var input = findChild(content, "elsewhen-zone-search")
                    verify(input !== null && input.visible)
                    tryCompare(input, "activeFocus", true, 500)
                    keyClick(Qt.Key_T, Qt.ShiftModifier)
                    keyClick(Qt.Key_O)
                    keyClick(Qt.Key_K)
                    keyClick(Qt.Key_Y)
                    keyClick(Qt.Key_O)
                    tryCompare(input, "text", "tokyo", 500)
                    tryCompare(content.searchList, "count", 1, 500,
                        "the active search offers the Tokyo zone in the full-list state")
                    tryCompare(content.searchList, "visible", true, 500)
                    for (var searchScrollStep = 0; searchScrollStep < 3; searchScrollStep++) {
                        mouseWheel(testRoot, wheelPoint.x, wheelPoint.y, 0, -120,
                            Qt.NoButton, Qt.NoModifier)
                        wait(20)
                    }
                    verify(waitForRendering(panelLoader.item, 3000),
                        "full-list search result geometry settles after scrolling")
                    var searchResult = content.searchList.itemAtIndex(0)
                    verify(searchResult !== null)
                    var searchResultPoint = searchResult.mapToItem(content.scrollArea, 0, 0)
                    verify(searchResultPoint.y >= 0
                        && searchResultPoint.y + searchResult.height <= content.scrollArea.height,
                        "the Tokyo result becomes entirely visible after scrolling; y="
                            + searchResultPoint.y + " h=" + searchResult.height
                            + " viewport=" + content.scrollArea.height
                            + " scrollY=" + content.scrollArea.contentY
                            + " content=" + content.scrollArea.contentHeight)
                    tryCompare(input, "activeFocus", true, 500,
                        "keyboard focus remains in search while results scroll into view")
                    captureScene(variant + "-full-list-add-city-search")
                    keyClick(Qt.Key_Escape)
                    tryCompare(input, "text", "", 500,
                        "Escape first clears the active city query")
                    compare(content.searchMode, "add")
                    keyClick(Qt.Key_Escape)
                    tryCompare(content, "searchMode", "", 500,
                        "closing the cleared search returns to the scrollable list state")
                    verify(addCity.visible,
                        "Add city is restored after dismissing the keyboard search")
                    verify(waitForRendering(panelLoader.item, 3000),
                        "search dismissal must settle list geometry before the next scroll")
                    var restoredMaxScroll = content.scrollArea.contentHeight
                        - content.scrollArea.height
                    for (var restoreStep = 0; restoreStep < 50; restoreStep++) {
                        mouseWheel(testRoot, wheelPoint.x, wheelPoint.y, 0, -120,
                            Qt.NoButton, Qt.NoModifier)
                        wait(20)
                    }
                    tryVerify(function() {
                        return content.scrollArea.contentY >= restoredMaxScroll - 2
                    }, 1000, "the list remains scrollable again after search closes")
                    var restoredAddPoint = addCity.mapToItem(content.scrollArea, 0, 0)
                    verify(restoredAddPoint.y >= 0
                        && restoredAddPoint.y + addCity.height <= content.scrollArea.height,
                        "the entire Add city control is accessible again after search closes")
                }
            } finally {
                testRoot.width = saved.width
                testRoot.height = saved.height
                theme.activePopupScreen = saved.screen
                theme.elsewhenBarX = saved.barX
                theme.v2BarHeight = saved.barHeight
                fakeService.cities = saved.cities
                fakeService.cityData = saved.cityData
                fakeService.preferenceData = saved.preferences
            }
        }

        function test_expanded_globe_radius_matches_original_geometry() {
            for (var variant of ["v1", "v2"]) {
                load(variant, false, "top")
                var content = findChild(panelLoader.item, "elsewhen-panel-content")
                verify(content !== null)
                content.forceActiveFocus()
                keyClick(Qt.Key_O)
                verify(waitForRendering(panelLoader.item, 3000))
                mouseClick(content.globeZoomButton, content.globeZoomButton.width / 2,
                    content.globeZoomButton.height / 2)
                tryCompare(content.globeCanvas, "height", 378, 1500)
                tryCompare(content.globeCanvas, "width", 310, 1500)
                var availableHeight = content.globeCanvas.height - content.globeFooterHeight
                    - content.globeJumpButtonHeight - content.globeJumpGap
                var mapSize = Math.min(content.globeCanvas.width, availableHeight)
                compare(Math.round(content.globePaintRadius(content.globeCanvas.width,
                    content.globeCanvas.height)),
                    Math.round(Math.max(40, mapSize / 2 - Commons.Style.space(6))))
            }
        }

        function test_expanded_globe_uses_original_chrome_and_jump_action() {
            for (var variant of ["v1", "v2"]) {
                load(variant, false, "top")
                var content = findChild(panelLoader.item, "elsewhen-panel-content")
                var heroButton = findChild(content, "elsewhen-hero-globe-button")
                verify(content !== null && heroButton !== null)
                mouseClick(heroButton, heroButton.width / 2, heroButton.height / 2)
                compare(content.globeExpanded, true)
                verify(waitForRendering(panelLoader.item, 3000),
                    "expanded globe must settle before chrome inspection")
                var heroMouseAreas = heroButton.children.filter(function(child) {
                    return child.containsMouse !== undefined
                })
                var exitIcons = heroButton.children.filter(function(child) {
                    return child.text === "×"
                })
                compare(heroMouseAreas.length, 1)
                compare(exitIcons.length, 1)
                tryVerify(function() { return exitIcons[0].visible }, 500)
                verify(heroMouseAreas[0].containsMouse,
                    "expanding the globe leaves the pointer over the hero control")
                var stage = findChild(content, "elsewhen-globe-stage")
                verify(stage !== null)
                tryCompare(stage, "height", 378, 1500)
                tryCompare(content.globeCanvas, "height", 378, 1500)
                compare(Math.round(content.globeDiscCenterY), Math.round(
                    (content.globeCanvas.height - content.globeFooterHeight
                        - content.globeJumpButtonHeight - content.globeJumpGap) / 2))
                compare(stage.color.a, 0)
                compare(stage.border.width, 0)
                var jump = findChild(content, "elsewhen-globe-jump")
                verify(jump !== null)
                verify(jump.visible)
                content.forceActiveFocus()
                var referenceJumpHeight = Math.ceil(originalTextFieldMetrics.height
                    + 2 * Commons.Style.spacing.inputPaddingY
                    + 2 * Commons.Style.normalBorderWidth)
                compare(Math.round(jump.height), referenceJumpHeight,
                    "Jump to city matches the original TextField height")
                compare(jump.border.width, 1)
                compare(jump.border.color.toString(), content.palette.sep.toString(),
                    "Jump to city uses the popup palette border token")
                var point = jump.mapToItem(panelLoader.item.surfaceHost, 0, 0)
                verify(point.x >= 0 && point.x + jump.width <= panelLoader.item.surfaceHost.width)
                mouseClick(jump, jump.width / 2, jump.height / 2)
                compare(content.searchMode, "jump")
            }
        }

        function test_add_city_button_searches_and_adds_selected_result() {
            for (var variant of ["v1", "v2"]) {
                load(variant, false, "top")
                var content = findChild(panelLoader.item, "elsewhen-panel-content")
                verify(content !== null)
                var addCity = findChild(content, "elsewhen-add-city")
                verify(addCity !== null && addCity.visible)
                compare(addCity.height, 28)
                compare(addCity.radius, variant === "v1" ? theme.tileRadius : theme.panelButtonRadius)
                compare(addCity.color.toString(), content.palette.fillIdle.toString())
                compare(addCity.border.width, 1)
                compare(addCity.border.color.toString(), content.palette.sep.toString(),
                    "Add city uses the popup palette border token")
                var oldAdds = fakeService.cityAdds
                mouseClick(addCity, addCity.width / 2, addCity.height / 2)
                compare(content.searchMode, "add")
                verify(content.zoneSearchInput.parent.visible)
                content.zoneSearchInput.text = "Paris"
                tryCompare(content.searchList, "count", 1)
                content.scrollArea.contentY = Math.max(0,
                    content.scrollArea.contentHeight - content.scrollArea.height)
                wait(60)
                verify(waitForRendering(panelLoader.item, 3000),
                    "add-city results must render before visual capture")
                captureScene(variant + "-add-city-search")
                var addZone = content.addZoneButton
                verify(addZone !== null && addZone.available)
                mouseClick(addZone, addZone.width / 2, addZone.height / 2)
                tryCompare(fakeService, "cityAdds", oldAdds + 1)
                compare(content.searchMode, "")
            }
        }
    }
}
