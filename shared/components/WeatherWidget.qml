import QtQuick
import "../logic/WeatherWidgetLogic.js" as WeatherWidgetLogic
import Quickshell
import Quickshell.Io
import "../integrations/WeatherData.js" as WeatherData
import "../components" as CommonComponents

Item {
    id: rootMod
    required property var root
    required property color contentColor
    property string loadingGlyph: "·"

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

    function refresh(force) { return WeatherWidgetLogic.refresh(rootMod, {weatherProc: weatherProc}, force) }

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
        running: rootMod.locationReady && (rootMod.root.modWeather || rootMod.root.weatherVisible)
        repeat: true
        triggeredOnStart: true
        onTriggered: rootMod.refresh(false)
    }

    function minutesForClock(s) { return WeatherWidgetLogic.minutesForClock(rootMod, {}, s) }

    function isNight(sunrise, sunset) { return WeatherWidgetLogic.isNight(rootMod, {}, sunrise, sunset) }

    function glyphForCode(code, night) { return WeatherData.glyphForCode(code, night) }

    Text {
        id: ico
        anchors.centerIn: parent
        text: rootMod.weatherLoaded ? rootMod.weatherIcon
              : (rootMod.weatherUnavailable ? "?" : rootMod.loadingGlyph)
        color: rootMod.weatherUnavailable && !rootMod.weatherLoaded
               ? Qt.rgba(rootMod.contentColor.r, rootMod.contentColor.g, rootMod.contentColor.b, 0.4)
               : rootMod.contentColor
        font.family: rootMod.root.mono
        font.pixelSize: 14
    }

    Process {
        id: clickRunner
        command: ["bash", "-c", "notify-send -u low \"$(omarchy-weather-status)\""]
    }

    CommonComponents.TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

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
                rootMod.root.weatherVisible = !rootMod.root.weatherVisible;
            }
        }
    }
}
