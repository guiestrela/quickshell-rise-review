import QtQuick
import Quickshell
import Quickshell.Io
import "../integrations/WeatherData.js" as WeatherData

Item {
    id: rootMod
    required property var root

    property string weatherIcon: "·"
    property string weatherPlace: ""
    property string weatherTemp: ""
    property string weatherDesc: ""
    property bool weatherLoaded: false
    property bool weatherUnavailable: false
    property var locationSettings: ({})
    property bool locationReady: false
    property int locationGeneration: 0
    property int requestGeneration: -1
    property var requestSettings: ({})
    property bool refreshPending: false

    FileView {
        id: locationFile
        path: Quickshell.env("HOME") + "/.cache/quickshell-rise/weather-location"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var raw = String(text() || "").trim(), settings = null
            try { settings = JSON.parse(raw) } catch (e) {}
            var wasReady = rootMod.locationReady
            rootMod.locationSettings = settings && typeof settings === "object" ? settings : {name: raw.slice(0,80)}
            rootMod.locationGeneration += 1
            rootMod.locationReady = true
            if (wasReady && (rootMod.root.modWeather || rootMod.root.weatherVisible)) rootMod.refresh(true)
        }
        onLoadFailed: { rootMod.locationReady = true }
    }

    // honor the global imperial toggle in the widget tooltip too (the panel already converts);
    // the fetch stores temp in °C, so convert here when imperial is set
    readonly property string weatherTempStr: root.weatherImperial
        ? (Math.round((parseFloat(weatherTemp) || 0) * 9 / 5 + 32) + "°F")
        : (weatherTemp + "°C")
    readonly property string tooltipText: weatherUnavailable
        ? (weatherLoaded
            ? "Weather stale · " + ((weatherPlace ? weatherPlace + " · " : "") + weatherTempStr + (weatherDesc ? " / " + weatherDesc : ""))
            : "Weather offline")
        : (weatherLoaded
            ? (weatherPlace ? weatherPlace + " · " : "") + weatherTempStr + (weatherDesc ? " / " + weatherDesc : "")
            : "Weather…")

    implicitWidth: root.modWeather ? ico.implicitWidth : 0
    implicitHeight: 28

    function refresh(force) {
        if (weatherProc.running) {
            if (force) rootMod.refreshPending = true
            return
        }
        rootMod.requestSettings = rootMod.locationSettings
        rootMod.requestGeneration = rootMod.locationGeneration
        weatherProc.running = true
    }

    Process {
        id: weatherProc
        running: false
        onExited: {
            if (rootMod.refreshPending) {
                rootMod.refreshPending = false
                Qt.callLater(function() { rootMod.refresh(false) })
            }
        }
        command: ["curl", "-fsS", "--max-time", "5", WeatherData.weatherUrl(rootMod.requestSettings)]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (rootMod.requestGeneration !== rootMod.locationGeneration) return
                const txt = String(this.text || "").trim()
                if (txt === "") {
                    rootMod.weatherUnavailable = true
                    return
                }
                try {
                    const d = WeatherData.normalize(JSON.parse(txt), rootMod.requestSettings)
                    const current = d.current_condition && d.current_condition[0] ? d.current_condition[0] : null
                    const area = d.nearest_area && d.nearest_area[0] ? d.nearest_area[0] : null
                    const astronomy = d.weather && d.weather[0] && d.weather[0].astronomy
                        ? d.weather[0].astronomy[0]
                        : null
                    if (!current) {
                        rootMod.weatherUnavailable = true
                        return
                    }

                    rootMod.weatherIcon = rootMod.glyphForCode(
                        current.weatherCode,
                        typeof d.isNight === "boolean" ? d.isNight : rootMod.isNight(astronomy ? astronomy.sunrise : "", astronomy ? astronomy.sunset : "")
                    )
                    rootMod.weatherTemp = current.temp_C || ""
                    rootMod.weatherDesc = current.weatherDesc && current.weatherDesc[0]
                        ? current.weatherDesc[0].value || ""
                        : ""
                    rootMod.weatherPlace = area && area.areaName && area.areaName[0]
                        ? area.areaName[0].value || ""
                        : ""
                    rootMod.weatherLoaded = true
                    rootMod.weatherUnavailable = false
                } catch (e) {
                    rootMod.weatherUnavailable = true
                }
            }
        }
    }

    Timer {
        interval: 60000
        running: rootMod.locationReady && (root.modWeather || root.weatherVisible)
        repeat: true
        triggeredOnStart: true
        onTriggered: rootMod.refresh(false)
    }

    function minutesForClock(s) {
        const m = String(s || "").match(/^(\d{1,2}):(\d{2})\s*([AP]M)$/i)
        if (!m) return -1
        let h = parseInt(m[1]) || 0
        const min = parseInt(m[2]) || 0
        const ap = m[3].toUpperCase()
        if (ap === "PM" && h !== 12) h += 12
        if (ap === "AM" && h === 12) h = 0
        return h * 60 + min
    }

    function isNight(sunrise, sunset) {
        const rise = minutesForClock(sunrise)
        const set = minutesForClock(sunset)
        if (rise < 0 || set < 0) return false
        const now = new Date()
        const mins = now.getHours() * 60 + now.getMinutes()
        return mins < rise || mins >= set
    }

    function glyphForCode(code, night) {
        const n = parseInt(code) || 0
        if (n === 113) return night ? String.fromCodePoint(0xe32b) : String.fromCodePoint(0xe30d)
        if (n === 116) return night ? String.fromCodePoint(0xe32e) : String.fromCodePoint(0xe302)
        if (n === 119 || n === 122) return String.fromCodePoint(0xe33d)
        if (n === 143 || n === 248 || n === 260) return String.fromCodePoint(0xe313)
        if (n === 176 || n === 263 || n === 266 || n === 293 || n === 296 || n === 353) return night ? String.fromCodePoint(0xe333) : String.fromCodePoint(0xe308)
        if (n === 179 || n === 227 || n === 230 || n === 323 || n === 326 || n === 368) return night ? String.fromCodePoint(0xe327) : String.fromCodePoint(0xe30a)
        if (n === 182 || n === 185 || n === 281 || n === 284 || n === 311 || n === 314 || n === 317 || n === 320 || n === 350 || n === 362 || n === 365 || n === 374 || n === 377) return String.fromCodePoint(0xe3ad)
        if (n === 200 || n === 386 || n === 389 || n === 392 || n === 395) return String.fromCodePoint(0xe31d)
        if (n === 299 || n === 302 || n === 305 || n === 308 || n === 356 || n === 359) return String.fromCodePoint(0xe318)
        if (n === 329 || n === 332 || n === 335 || n === 338 || n === 371) return String.fromCodePoint(0xe31a)
        return String.fromCodePoint(0xe33d)
    }

    Text {
        id: ico
        anchors.centerIn: parent
        text: rootMod.weatherLoaded ? rootMod.weatherIcon
              : (rootMod.weatherUnavailable ? "?" : "·")
        color: rootMod.weatherUnavailable && !rootMod.weatherLoaded
               ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4)
               : root.ink
        font.family: root.mono
        font.pixelSize: 14
    }

    Process {
        id: clickRunner
        command: ["bash", "-c", "notify-send -u low \"$(omarchy-weather-status)\""]
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: { if (rootMod.tooltipText) tip.show(); }
        onExited: { tip.hide(); }
        onClicked: (e) => {
            tip.hide();
            if (e.button === Qt.RightButton) {
                rootMod.refresh(true);
            } else {
                root.weatherVisible = !root.weatherVisible;
            }
        }
    }
}
