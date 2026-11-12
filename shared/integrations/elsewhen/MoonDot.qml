import QtQuick
import "GlobeModel.js" as Globe

Item {
    id: root
    property real phase: 0
    property color color: "white"

    onPhaseChanged: moonCanvas.requestPaint()
    onColorChanged: moonCanvas.requestPaint()

    Canvas {
        id: moonCanvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var radius = Math.min(width, height) / 2
            if (radius <= 0) return
            ctx.translate(width / 2, height / 2)
            ctx.beginPath()
            ctx.arc(0, 0, radius, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, 0.22).toString()
            ctx.fill()
            var lit = Globe.moonLitOutline(root.phase, radius, 28)
            if (lit.length > 2) {
                ctx.beginPath()
                ctx.moveTo(lit[0].x, lit[0].y)
                for (var i = 1; i < lit.length; i++) ctx.lineTo(lit[i].x, lit[i].y)
                ctx.closePath()
                ctx.fillStyle = root.color.toString()
                ctx.fill()
            }
        }
    }
}
