pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root
    readonly property bool verticalCompact: root.barVertical === true || root.compactGpu

    visible: implicitWidth > 0.5
    implicitWidth: (root.modGpu && root.gpuAvailable) ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: (root.modGpu && root.gpuAvailable) ? 1 : 0
    Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    readonly property int percent: root.gpuPercent
    readonly property var history: root.gpuHistory
    readonly property int maxSamples: 30
    readonly property color contentColor: root.seal
    readonly property string tooltipText: (root.gpuName || "GPU") + " · " + percent + "%"
        + (root.gpuTemperatureC > 0 ? " · " + root.gpuTemperatureC + "°C" : "")

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: rootMod.root.pillH
        radius: rootMod.root.pillRadius
        color: rootMod.root.pill
        border.color: rootMod.root.pillBorder
        border.width: rootMod.root.pillBorderW
        PillShadow { theme: rootMod.root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: rootMod.verticalCompact ? 4 : 5

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !rootMod.verticalCompact
            text: "GPU"
            color: Qt.rgba(rootMod.root.ink.r, rootMod.root.ink.g, rootMod.root.ink.b, 0.6)
            font.family: rootMod.root.mono
            font.pixelSize: 12
            font.letterSpacing: 0.5
        }

        Canvas {
            id: wave
            visible: !rootMod.verticalCompact
            width: 36
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            property color tint: rootMod.root.seal
            onTintChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var h = rootMod.history
                if (h.length < 2) return

                var maxV = 0.25
                for (var n = 0; n < h.length; n++) {
                    if (h[n] > maxV) maxV = h[n]
                }
                maxV = Math.min(1, Math.max(0.25, maxV * 1.15))

                var pts = []
                for (var i = 0; i < h.length; i++) {
                    var x = (i / (rootMod.maxSamples - 1)) * width
                    var y = height - (h[i] / maxV) * height
                    pts.push({ x: x, y: y })
                }

                // fill
                ctx.beginPath()
                ctx.moveTo(pts[0].x, height)
                ctx.lineTo(pts[0].x, pts[0].y)
                for (var j = 1; j < pts.length; j++) {
                    var cx = (pts[j-1].x + pts[j].x) / 2
                    ctx.bezierCurveTo(cx, pts[j-1].y, cx, pts[j].y, pts[j].x, pts[j].y)
                }
                ctx.lineTo(pts[pts.length-1].x, height)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.12)
                ctx.fill()

                // stroke
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (var k = 1; k < pts.length; k++) {
                    var mx = (pts[k-1].x + pts[k].x) / 2
                    ctx.bezierCurveTo(mx, pts[k-1].y, mx, pts[k].y, pts[k].x, pts[k].y)
                }
                ctx.strokeStyle = tint
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.stroke()
            }

            Component.onCompleted: requestPaint()
            Connections {
                target: rootMod
                function onHistoryChanged() { wave.requestPaint() }
            }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: rootMod.root.barVertical !== true && (!rootMod.verticalCompact)
            text: String(Math.min(100, rootMod.percent)).padStart(2, '0') + "%"
            color: rootMod.root.seal
            font.family: rootMod.root.mono
            font.pixelSize: 12
        }

        Item {
            visible: rootMod.verticalCompact
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 13

            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("../assets/gpu-card.svg")
                sourceSize: Qt.size(54, 39)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(54, 39)
                layer.effect: ShaderEffect {
                    property color tintColor: rootMod.contentColor
                    fragmentShader: Qt.resolvedUrl("../shaders/logo-tint.frag.qsb")
                }
            }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: rootMod.root.barVertical !== true && (rootMod.verticalCompact)
            text: String(Math.min(100, rootMod.percent)).padStart(2, '0') + "%"
            color: rootMod.root.seal
            font.family: rootMod.root.mono
            font.pixelSize: 12
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: { tip.hide() }
        onClicked: { tip.hide(); rootMod.root.gpuVisible = !rootMod.root.gpuVisible }
    }
}
