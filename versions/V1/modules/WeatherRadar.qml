import QtQuick
import Quickshell
import Quickshell.Io

// Compact Rise-styled map built from public Esri and RainViewer tiles.
// Coordinates are supplied by the current weather report; no location is
// sent to an additional geocoding service.
Item {
    id: radar
    required property var root
    property real latitude: NaN
    property real longitude: NaN
    property string radarHost: "https://tilecache.rainviewer.com"
    property string radarPath: ""
    property int zoom: 6

    readonly property bool located: isFinite(latitude) && isFinite(longitude)
    implicitWidth: 276
    implicitHeight: 148

    function tileX() { return Math.floor((longitude + 180) / 360 * Math.pow(2, zoom)) }
    function tileY() {
        var lat = Math.max(-85, Math.min(85, latitude)) * Math.PI / 180
        return Math.floor((1 - Math.log(Math.tan(lat) + 1 / Math.cos(lat)) / Math.PI) / 2 * Math.pow(2, zoom))
    }

    Process {
        id: metadata
        command: ["curl", "-fsS", "--max-time", "8", "https://api.rainviewer.com/public/weather-maps.json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(String(this.text || ""))
                    var frames = data.radar && data.radar.past ? data.radar.past : []
                    var frame = frames.length ? frames[frames.length - 1] : null
                    var host = String(data.host || "")
                    var path = String(frame && frame.path || "")
                    if (/^https:\/\/(?:[A-Za-z0-9-]+\.)*rainviewer\.com(?::443)?$/.test(host)
                        && /^\/v2\/radar\/[A-Za-z0-9_-]+$/.test(path)) {
                        radar.radarHost = host
                        radar.radarPath = path
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 600000
        running: radar.visible && radar.located
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!metadata.running) metadata.running = true
    }

    Column {
        anchors.fill: parent
        spacing: 5
        Row {
            width: parent.width
            height: 14
            UiText {
                text: "LOCAL RADAR"
                color: radar.root.sumiHi
                font.family: radar.root.mono
                font.pixelSize: 9
                font.letterSpacing: 1
            }
            Item { width: 1; height: 1 }
            UiText {
                anchors.right: parent.right
                text: radar.located ? "RAINVIEWER" : "LOCATION UNKNOWN"
                color: radar.root.sumi
                font.family: radar.root.mono
                font.pixelSize: 8
            }
        }
        Rectangle {
            width: parent.width
            height: 129
            radius: radar.root.tileRadius
            clip: true
            color: radar.root.paper
            border.color: radar.root.sep
            border.width: 1

            Text {
                anchors.centerIn: parent
                visible: !radar.located
                text: "Weather location is unavailable"
                color: radar.root.sumi
                font.family: radar.root.mono
                font.pixelSize: 9
            }

            Item {
                anchors.centerIn: parent
                width: 768
                height: 768
                visible: radar.located
                Repeater {
                    model: 9
                    delegate: Item {
                        required property int index
                        readonly property int dx: index % 3 - 1
                        readonly property int dy: Math.floor(index / 3) - 1
                        readonly property int count: Math.pow(2, radar.zoom)
                        readonly property int tx: ((radar.tileX() + dx) % count + count) % count
                        readonly property int ty: radar.tileY() + dy
                        x: (dx + 1) * 256
                        y: (dy + 1) * 256
                        width: 256
                        height: 256
                        visible: ty >= 0 && ty < count

                        Image {
                            anchors.fill: parent
                            source: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/"
                                + radar.zoom + "/" + parent.ty + "/" + parent.tx
                            asynchronous: true
                            cache: true
                            fillMode: Image.Stretch
                        }
                        Image {
                            anchors.fill: parent
                            visible: radar.radarPath !== ""
                            source: radar.radarPath === "" ? "" : radar.radarHost + radar.radarPath
                                + "/256/" + radar.zoom + "/" + parent.tx + "/" + parent.ty + "/2/1_1.png"
                            asynchronous: true
                            cache: false
                            opacity: 0.58
                            fillMode: Image.Stretch
                        }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 8; height: 8; radius: 4
                    color: radar.root.seal
                    border.color: radar.root.paper
                    border.width: 2
                }
            }
        }
    }
}
