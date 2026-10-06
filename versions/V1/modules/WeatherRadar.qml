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
    property real zoom: 10.5
    readonly property int minZoom: 4
    readonly property int maxZoom: 12
    readonly property int radarMaxZoom: 7
    readonly property int tileZoom: Math.floor(zoom)
    readonly property real zoomScale: Math.pow(2, zoom - tileZoom)

    readonly property bool located: isFinite(latitude) && isFinite(longitude)
    readonly property bool tilesActive: root.weatherVisible
    implicitWidth: 276
    implicitHeight: 179

    function tileX() { return Math.floor((longitude + 180) / 360 * Math.pow(2, tileZoom)) }
    function tileY() {
        var lat = Math.max(-85, Math.min(85, latitude)) * Math.PI / 180
        return Math.floor((1 - Math.log(Math.tan(lat) + 1 / Math.cos(lat)) / Math.PI) / 2 * Math.pow(2, tileZoom))
    }

    function pixelOffsetX() {
        var count = Math.pow(2, tileZoom)
        return ((longitude + 180) / 360 * count * 256) - tileX() * 256
    }

    function pixelOffsetY() {
        var lat = Math.max(-85, Math.min(85, latitude)) * Math.PI / 180
        var count = Math.pow(2, tileZoom)
        var worldY = (1 - Math.log(Math.tan(lat) + 1 / Math.cos(lat)) / Math.PI) / 2 * count * 256
        return worldY - tileY() * 256
    }

    function setZoom(value) {
        radar.zoom = Math.max(radar.minZoom, Math.min(radar.maxZoom, Math.round(value * 4) / 4))
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
        Item {
            width: parent.width
            height: 14
            UiText {
            anchors.left: parent.left
                text: "LOCAL RADAR"
                color: radar.root.sumiHi
                font.family: radar.root.mono
                font.pixelSize: 9
                font.letterSpacing: 1
            }
            Item { width: 1; height: 1 }
            Row {
                anchors.right: parent.right
                spacing: 3
                UiText { text: radar.located ? "Z" + Number(radar.zoom).toFixed(2).replace(/\.00$/, "") : "LOCATION UNKNOWN"; color: radar.root.sumi; font.family: radar.root.mono; font.pixelSize: 8 }
                Rectangle {
                    width: 16; height: 14; radius: radar.root.tileRadius
                    color: zoomOut.containsMouse ? radar.root.fillHover : radar.root.fillIdle
                    border.color: radar.root.sep; border.width: 1
                    UiText { anchors.centerIn: parent; text: "−"; color: radar.root.ink; font.family: radar.root.mono; font.pixelSize: 11 }
                    MouseArea { id: zoomOut; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: radar.zoom > radar.minZoom; onClicked: radar.setZoom(radar.zoom - 0.25) }
                }
                Rectangle {
                    width: 16; height: 14; radius: radar.root.tileRadius
                    color: zoomIn.containsMouse ? radar.root.fillHover : radar.root.fillIdle
                    border.color: radar.root.sep; border.width: 1
                    UiText { anchors.centerIn: parent; text: "+"; color: radar.root.ink; font.family: radar.root.mono; font.pixelSize: 11 }
                    MouseArea { id: zoomIn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: radar.zoom < radar.maxZoom; onClicked: radar.setZoom(radar.zoom + 0.25) }
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 160
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
                    model: radar.tilesActive ? 9 : 0
                    delegate: Item {
                        required property int index
                        readonly property int dx: index % 3 - 1
                        readonly property int dy: Math.floor(index / 3) - 1
                        readonly property int count: Math.pow(2, radar.tileZoom)
                        readonly property int tx: ((radar.tileX() + dx) % count + count) % count
                        readonly property int ty: radar.tileY() + dy
                        x: ((dx + 1) * 256 - radar.pixelOffsetX()) * radar.zoomScale
                        y: ((dy + 1) * 256 - radar.pixelOffsetY()) * radar.zoomScale
                        width: 256 * radar.zoomScale
                        height: 256 * radar.zoomScale
                        visible: ty >= 0 && ty < count

                        Image {
                            anchors.fill: parent
                            source: radar.tilesActive && parent.visible ? "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/"
                                + radar.tileZoom + "/" + parent.ty + "/" + parent.tx : ""
                            asynchronous: true
                            cache: true
                            fillMode: Image.Stretch
                        }
                        Image {
                            anchors.fill: parent
                            visible: radar.radarPath !== "" && radar.zoom <= radar.radarMaxZoom
                            source: !radar.tilesActive || radar.radarPath === "" ? "" : radar.radarHost + radar.radarPath
                                + "/256/" + radar.tileZoom + "/" + parent.tx + "/" + parent.ty + "/2/1_1.png"
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
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                onWheel: function(event) {
                    radar.setZoom(radar.zoom + (event.angleDelta.y > 0 ? 0.25 : -0.25))
                    event.accepted = true
                }
            }
        }
    }
}
