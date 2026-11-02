import QtQuick
import "../logic/WeatherPanelValuesLogic.js" as WeatherPanelValuesLogic
import "../logic/WeatherPanelLogic.js" as WeatherPanelLogic
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../components" as CommonComponents

PanelWindow {
    id: wxPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-weather"

    required property int barBottom
    required property int gap
    required property real frameRadius
    required property color frameColor
    required property color frameBorderColor
    required property real frameBorderWidth
    required property real buttonRadius
    property real revealShift: 0
    property Component surfaceComponent
    readonly property Item surfaceHost: card

    property string temp: ""
    property string feels: ""
    property string desc: ""
    property string location: ""
    property string humidity: ""
    property string wind: ""
    property string locationQuery: ""
    property string locationDraft: ""
    property string pendingLocation: ""
    property bool locationWritePending: false
    property var locationSuggestions: []
    property int suggestionIndex: 0
    property string pendingSuggestionQuery: ""
    property string activeSuggestionQuery: ""
    property real latitude: NaN
    property real longitude: NaN
    property var    forecastDays: []
    property bool   refreshing: false

    function refresh() { return WeatherPanelValuesLogic.refresh(wxPanel, {wxData: wxData}) }

    function setConfiguredLocation(value, latitudeValue, longitudeValue) {
        var next = String(value || "").trim().slice(0, 80)
        if (/[\r\n\u0000-\u001f]/.test(next)) return
        var lat = parseFloat(latitudeValue)
        var lon = parseFloat(longitudeValue)
        var hasCoordinates = isFinite(lat) && isFinite(lon)
        locationQuery = hasCoordinates ? lat + "," + lon : next
        locationDraft = next
        locationSuggestions = []
        suggestionIndex = 0
        pendingLocation = JSON.stringify({ name: next, latitude: hasCoordinates ? lat : null, longitude: hasCoordinates ? lon : null })
        locationWritePending = true
        if (!locationSettingsDirectory.running) locationSettingsDirectory.running = true
        else weatherLocationFile.setText(pendingLocation + "\n")
        if (wxData.running) wxData.running = false
        wxPanel.temp = ""
        wxPanel.location = ""
        wxPanel.forecastDays = []
        Qt.callLater(wxPanel.refresh)
    }

    function requestLocationSuggestions() {
        var query = String(locationDraft || "").trim()
        if (query.length < 2) {
            locationSuggestions = []
            suggestionIndex = 0
            return
        }
        pendingSuggestionQuery = query
        if (locationSuggest.running) return
        startLocationSuggestions()
    }

    function startLocationSuggestions() { return WeatherPanelLogic.startLocationSuggestions(wxPanel, {locationSuggest: locationSuggest}) }

    function chooseSuggestion(suggestion) { return WeatherPanelLogic.chooseSuggestion(wxPanel, {}, suggestion) }

    function weatherUrl() {
        var coordinates = String(locationQuery || "").split(",")
        if (coordinates.length === 2 && isFinite(parseFloat(coordinates[0])) && isFinite(parseFloat(coordinates[1]))) {
            return "https://api.open-meteo.com/v1/forecast?latitude=" + coordinates[0]
                + "&longitude=" + coordinates[1]
                + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code"
                + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
                + "&forecast_days=3&timezone=auto"
        }
        var path = locationQuery === "" ? "" : "/" + encodeURIComponent(locationQuery)
        return "https://wttr.in" + path + "?format=j1"
    }

    function openMeteoWttrCode(code) {
        var n = parseInt(code) || 0
        if (n === 0) return 113
        if (n === 1 || n === 2) return 116
        if (n === 3) return 119
        if (n === 45 || n === 48) return 143
        if (n >= 51 && n <= 57) return 266
        if (n >= 61 && n <= 67 || n >= 80 && n <= 82) return 308
        if (n >= 71 && n <= 77 || n >= 85 && n <= 86) return 338
        if (n >= 95) return 389
        return 119
    }

    function openMeteoDescription(code) {
        var n = parseInt(code) || 0
        if (n === 0) return "Clear sky"
        if (n === 1 || n === 2) return "Partly cloudy"
        if (n === 3) return "Overcast"
        if (n === 45 || n === 48) return "Fog"
        if (n >= 51 && n <= 67 || n >= 80 && n <= 82) return "Rain"
        if (n >= 71 && n <= 77 || n >= 85 && n <= 86) return "Snow"
        if (n >= 95) return "Thunderstorm"
        return "Unknown"
    }

    // data is fetched in °C / km·h; convert on display per root.weatherImperial
    function tConv(c) { return WeatherPanelLogic.tConv(wxPanel, {root: root}, c) }
    function wConv(kmh) { return WeatherPanelLogic.wConv(wxPanel, {root: root}, kmh) }
    function glyphForCode(code) { return WeatherPanelLogic.glyphForCode(wxPanel, {}, code) }
    function dayLabel(dateStr, index) { return WeatherPanelLogic.dayLabel(wxPanel, {}, dateStr, index) }
    function dayRange(day) { return WeatherPanelLogic.dayRange(wxPanel, {root: root}, day) }
    function chanceOfRain(day) { return WeatherPanelLogic.chanceOfRain(wxPanel, {}, day) }
    function forecastCode(day) { return WeatherPanelLogic.forecastCode(wxPanel, {}, day) }
    function parseReport(raw) {
        var d = JSON.parse(raw)
        if (d.current && d.current.temperature_2m !== undefined) {
            var openCurrent = d.current
            var openCode = parseInt(openCurrent.weather_code) || 0
            wxPanel.temp = String(Math.round(openCurrent.temperature_2m))
            wxPanel.feels = String(Math.round(openCurrent.apparent_temperature))
            wxPanel.desc = openMeteoDescription(openCode)
            wxPanel.humidity = String(Math.round(openCurrent.relative_humidity_2m))
            wxPanel.wind = String(Math.round(openCurrent.wind_speed_10m))
            wxPanel.location = wxPanel.locationDraft
            wxPanel.latitude = parseFloat(String(locationQuery).split(",")[0])
            wxPanel.longitude = parseFloat(String(locationQuery).split(",")[1])
            var openDays = []
            var daily = d.daily || {}
            for (var oi = 0; oi < (daily.time || []).length && oi < 3; oi++) {
                openDays.push({ date: daily.time[oi], min: daily.temperature_2m_min[oi], max: daily.temperature_2m_max[oi], code: openMeteoWttrCode(daily.weather_code[oi]), rain: daily.precipitation_probability_max[oi] || 0 })
            }
            wxPanel.forecastDays = openDays
            return true
        }
        var current = d.current_condition && d.current_condition[0] ? d.current_condition[0] : null
        var area = d.nearest_area && d.nearest_area[0] ? d.nearest_area[0] : null
        if (!current) return false

        wxPanel.temp = current.temp_C || ""
        wxPanel.feels = current.FeelsLikeC || ""
        wxPanel.desc = current.weatherDesc && current.weatherDesc[0] ? current.weatherDesc[0].value || "" : ""
        wxPanel.humidity = current.humidity || ""
        wxPanel.wind = current.windspeedKmph || ""
        wxPanel.location = wxPanel.locationDraft !== "" ? wxPanel.locationDraft
            : (area && area.areaName && area.areaName[0] ? area.areaName[0].value || "" : "")
        wxPanel.latitude = area ? parseFloat(String(area.latitude || "")) : NaN
        wxPanel.longitude = area ? parseFloat(String(area.longitude || "")) : NaN

        var days = []
        var reportDays = d.weather || []
        for (var i = 0; i < reportDays.length && i < 3; i++) {
            var day = reportDays[i]
            days.push({
                date: day.date || "",
                min: day.mintempC || "",
                max: day.maxtempC || "",
                code: forecastCode(day),
                desc: "",
                rain: chanceOfRain(day)
            })
        }
        wxPanel.forecastDays = days
        return true
    }

    property real reveal: root.weatherVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.weatherVisible ? 160 : 120
            easing.type: root.weatherVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.weatherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.weatherVisible = false }

    Rectangle {
        id: card
        width: 300
        height: col.implicitHeight + 24
        radius: wxPanel.reveal > 0.001 ? wxPanel.frameRadius : 0
        color: wxPanel.frameColor
        border.color: wxPanel.frameBorderColor
        border.width: wxPanel.frameBorderWidth
        Loader { anchors.fill:parent; sourceComponent:wxPanel.surfaceComponent }
        x: Math.round(Math.max(6, Math.min(root.weatherBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) + wxPanel.revealShift : (barBottom + gap) - wxPanel.revealShift
        opacity: wxPanel.reveal
        focus: root.weatherVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.weatherVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 24
                CommonComponents.UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Weather"
                    color: root.ink; font.family: root.mono; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                CommonComponents.UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.weatherVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Item {
                width: parent.width
                height: 36
                CommonComponents.UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: wxPanel.temp !== "" ? wxPanel.tConv(wxPanel.temp) + "°" + (root.weatherImperial ? "F" : "C") : "—"
                    color: root.seal; font.family: root.mono; font.pixelSize: 26; font.weight: Font.Medium
                }
                CommonComponents.UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: wxPanel.desc
                    color: root.ink; font.family: root.mono; font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                    width: parent.width * 0.55; wrapMode: Text.WordWrap
                }
            }

            Column {
                width: parent.width
                spacing: 4
                Row {
                    width: parent.width
                    visible: wxPanel.location !== ""
                    CommonComponents.UiText { text: "Location"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    CommonComponents.UiText { text: wxPanel.location; color: root.ink; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.6; elide: Text.ElideRight }
                }
                Row {
                    width: parent.width
                    visible: wxPanel.feels !== ""
                    CommonComponents.UiText { text: "Feels like"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    CommonComponents.UiText { text: wxPanel.tConv(wxPanel.feels) + "°" + (root.weatherImperial ? "F" : "C"); color: root.ink; font.family: root.mono; font.pixelSize: 11 }
                }
                Row {
                    width: parent.width
                    visible: wxPanel.humidity !== ""
                    CommonComponents.UiText { text: "Humidity"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    CommonComponents.UiText { text: wxPanel.humidity + "%"; color: root.ink; font.family: root.mono; font.pixelSize: 11 }
                }
                Row {
                    width: parent.width
                    visible: wxPanel.wind !== ""
                    CommonComponents.UiText { text: "Wind"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    CommonComponents.UiText { text: wxPanel.wConv(wxPanel.wind); color: root.ink; font.family: root.mono; font.pixelSize: 11 }
                }
            }

            Row {
                width: parent.width
                height: 26
                spacing: 6
                TextInput {
                    id: locationEditor
                    width: parent.width - 74
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    leftPadding: 7; rightPadding: 7
                    color: root.ink
                    selectionColor: root.seal
                    selectedTextColor: root.paper
                    font.family: root.mono; font.pixelSize: 10
                    clip: true
                    text: wxPanel.locationDraft
                    onTextEdited: {
                        wxPanel.locationDraft = text
                        suggestionIndex = 0
                        locationSuggestDebounce.restart()
                    }
                    onAccepted: wxPanel.chooseSuggestion(wxPanel.locationSuggestions.length > 0
                        ? wxPanel.locationSuggestions[wxPanel.suggestionIndex]
                        : { name: text })
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Down && wxPanel.locationSuggestions.length > 0) {
                            wxPanel.suggestionIndex = Math.min(wxPanel.suggestionIndex + 1, wxPanel.locationSuggestions.length - 1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up && wxPanel.locationSuggestions.length > 0) {
                            wxPanel.suggestionIndex = Math.max(0, wxPanel.suggestionIndex - 1)
                            event.accepted = true
                        }
                    }
                    Rectangle {
                        z: -1; anchors.fill: parent; radius: root.tileRadius
                        color: root.fillIdle; border.color: root.sep; border.width: 1
                    }
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        visible: locationEditor.text === "" && !locationEditor.activeFocus
                        text: "City or place · blank = automatic"
                        color: root.sumi; font.family: root.mono; font.pixelSize: 9
                    }
                }
                Rectangle {
                    width: 68; height: parent.height; radius: root.tileRadius
                    color: locationApplyMouse.containsMouse ? root.fillHover : root.fillIdle
                    border.color: locationApplyMouse.containsMouse ? root.seal : root.sep
                    border.width: 1
                    CommonComponents.UiText { anchors.centerIn: parent; text: "SET"; color: root.seal; font.family: root.mono; font.pixelSize: 9 }
                    MouseArea {
                        id: locationApplyMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wxPanel.setConfiguredLocation(locationEditor.text)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 2
                visible: wxPanel.locationSuggestions.length > 0
                Repeater {
                    model: wxPanel.locationSuggestions
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: 28
                        radius: root.tileRadius
                        color: index === wxPanel.suggestionIndex ? root.fillHover : root.fillIdle
                        border.color: index === wxPanel.suggestionIndex ? root.seal : root.sep
                        border.width: 1
                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 7
                            anchors.right: parent.right; anchors.rightMargin: 7
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            CommonComponents.UiText { width: parent.width; text: modelData.name; color: root.ink; font.family: root.mono; font.pixelSize: 10; elide: Text.ElideRight }
                            CommonComponents.UiText { width: parent.width; text: modelData.description; color: root.sumiHi; font.family: root.mono; font.pixelSize: 8; elide: Text.ElideRight }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wxPanel.chooseSuggestion(modelData)
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Column {
                width: parent.width
                spacing: 5
                visible: wxPanel.forecastDays.length > 0

                CommonComponents.UiText {
                    text: "3-DAY FORECAST"
                    color: root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }

                Repeater {
                    model: wxPanel.forecastDays
                    delegate: Item {
                        width: col.width
                        height: 24
                        property var day: modelData

                        CommonComponents.UiText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 66
                            text: wxPanel.dayLabel(day.date || "", index)
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 76
                            anchors.verticalCenter: parent.verticalCenter
                            text: wxPanel.glyphForCode(day.code)
                            color: root.seal
                            font.family: root.mono
                            font.pixelSize: 14
                        }
                        CommonComponents.UiText {
                            anchors.left: parent.left
                            anchors.leftMargin: 106
                            anchors.verticalCenter: parent.verticalCenter
                            width: 76
                            text: wxPanel.dayRange(day)
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 11
                        }
                        CommonComponents.UiText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 76
                            text: (day.rain !== undefined ? Math.round(day.rain) + "% rain" : "")
                            color: root.sumiHi
                            font.family: root.mono
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep; visible: wxPanel.forecastDays.length > 0 }

            CommonComponents.WeatherRadar {
                width: parent.width
                root: wxPanel.root
                latitude: wxPanel.latitude
                longitude: wxPanel.longitude
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Row {
                width: parent.width
                height: 28
                spacing: 6
                // Refresh (primary)
                Rectangle {
                    width: root.evenW((parent.width - parent.spacing) / 2)
                    height: 28; radius: wxPanel.buttonRadius
                    color: wxPanel.refreshing ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.45)
                           : wxBtnMa.containsMouse ? root.fillPrimaryHover : root.seal
                    Behavior on color { ColorAnimation { duration: 120 } }
                    CommonComponents.UiText {
                        anchors.centerIn: parent
                        text: wxPanel.refreshing ? "Refreshing…" : "Refresh"
                        color: root.paper; font.family: root.mono; font.pixelSize: 11
                    }
                    MouseArea {
                        id: wxBtnMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        enabled: !wxPanel.refreshing
                        onClicked: wxPanel.refresh()
                    }
                }
                // Unit toggle (secondary): shows the unit you'd switch TO
                Rectangle {
                    width: root.evenW((parent.width - parent.spacing) / 2)
                    height: 28; radius: wxPanel.buttonRadius
                    color: unitMa.containsMouse ? root.fillHover : root.fillIdle
                    border.color: unitMa.containsMouse ? root.seal : root.sep
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    CommonComponents.UiText {
                        anchors.centerIn: parent
                        text: root.weatherImperial ? "metric" : "imperial"
                        color: unitMa.containsMouse ? root.seal : root.ink
                        font.family: root.mono; font.pixelSize: 11
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: unitMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.weatherImperial = !root.weatherImperial
                    }
                }
            }
        }
    }

    Process {
        id: wxData
        command: ["curl", "-fs", "--max-time", "5", wxPanel.weatherUrl()]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var txt = String(this.text || "").trim()
                if (txt === "") return
                try {
                    wxPanel.parseReport(txt)
                } catch (e) {
                    // Keep the last valid panel data on transient weather failures.
                }
            }
        }
        onExited: wxPanel.refreshing = false
    }

    Timer {
        id: locationSuggestDebounce
        interval: 300
        repeat: false
        onTriggered: wxPanel.requestLocationSuggestions()
    }

    Process {
        id: locationSuggest
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var results = []
                try {
                    var data = JSON.parse(String(this.text || "{}"))
                    var rows = data.results || []
                    for (var i = 0; i < rows.length; i++) {
                        var row = rows[i]
                        if (!row || !row.name || row.feature_code === "PCLI") continue
                        results.push({ name: String(row.name), description: [row.admin1, row.country].filter(function(v) { return !!v }).join(", "), latitude: row.latitude, longitude: row.longitude, population: Number(row.population) || 0 })
                    }
                    results.sort(function(a, b) { return b.population - a.population })
                    results = results.slice(0, 5)
                } catch (e) {}
                wxPanel.locationSuggestions = results
                if (wxPanel.pendingSuggestionQuery !== wxPanel.activeSuggestionQuery)
                    Qt.callLater(wxPanel.startLocationSuggestions)
            }
        }
    }

    FileView {
        id: weatherLocationFile
        path: Quickshell.env("HOME") + "/.cache/quickshell-rise/weather-location"
        atomicWrites: true
        printErrors: false
        onLoaded: {
            var raw = String(text() || "").trim()
            var stored = null
            try { stored = JSON.parse(raw) } catch (e) {}
            var name = stored && typeof stored.name === "string" ? stored.name.trim() : raw.slice(0, 80)
            var lat = stored ? parseFloat(stored.latitude) : NaN
            var lon = stored ? parseFloat(stored.longitude) : NaN
            var hasStoredCoordinates = isFinite(lat) && isFinite(lon)
            wxPanel.locationQuery = hasStoredCoordinates ? lat + "," + lon : name
            wxPanel.locationDraft = name
            if (wxPanel.visible) wxPanel.refresh()
        }
    }
    Process {
        id: locationSettingsDirectory
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell-rise"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0 || !wxPanel.locationWritePending) return
            weatherLocationFile.setText(wxPanel.pendingLocation + "\n")
            wxPanel.locationWritePending = false
        }
    }

    onVisibleChanged: { if (visible && wxPanel.temp === "") wxPanel.refresh() }
}
