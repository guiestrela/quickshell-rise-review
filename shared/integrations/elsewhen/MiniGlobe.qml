import QtQuick
import "./GlobeModel.js" as Globe

Canvas {
    id: globe

    property real spin: 0
    property var worldData: []
    property color ink: "#ebdbb2"
    property color land: "#d79921"

    onSpinChanged: requestPaint()
    onWorldDataChanged: requestPaint()
    onInkChanged: requestPaint()
    onLandChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        var cx = width / 2
        var cy = height / 2
        var radius = Math.max(0, Math.min(width, height) * 0.47)
        ctx.clearRect(0, 0, width, height)
        if (radius <= 0) return
        ctx.save()
        ctx.beginPath()
        ctx.arc(cx, cy, radius, 0, Math.PI * 2)
        ctx.fillStyle = "rgba(0, 0, 0, 0.18)"
        ctx.fill()
        ctx.clip()

        for (var ringIndex = 0; ringIndex < globe.worldData.length; ringIndex++) {
            var ring = globe.worldData[ringIndex]
            if (!Array.isArray(ring) || ring.length < 8) continue
            var clipped = Globe.clipRingToDisc(ring, globe.spin, 0, radius * 0.96)
            if (clipped.length < 3) continue
            ctx.beginPath()
            ctx.moveTo(cx + clipped[0].x, cy + clipped[0].y)
            for (var pointIndex = 1; pointIndex < clipped.length; pointIndex++)
                ctx.lineTo(cx + clipped[pointIndex].x, cy + clipped[pointIndex].y)
            ctx.closePath()
            ctx.fillStyle = globe.land.toString()
            ctx.fill()
            ctx.strokeStyle = globe.ink.toString()
            ctx.lineWidth = 0.35
            ctx.stroke()
        }

        for (var latitude = -60; latitude <= 60; latitude += 30) {
            ctx.beginPath()
            var started = false
            for (var longitude = -180; longitude <= 180; longitude += 8) {
                var projected = Globe.project(latitude, longitude, globe.spin, 0, radius)
                if (!projected.visible) { started = false; continue }
                if (!started) { ctx.moveTo(cx + projected.x, cy + projected.y); started = true }
                else ctx.lineTo(cx + projected.x, cy + projected.y)
            }
            ctx.strokeStyle = globe.ink.toString()
            ctx.globalAlpha = 0.42
            ctx.lineWidth = 0.3
            ctx.stroke()
        }
        ctx.restore()
        ctx.beginPath()
        ctx.arc(cx, cy, radius, 0, Math.PI * 2)
        ctx.strokeStyle = globe.ink.toString()
        ctx.lineWidth = 1
        ctx.stroke()
    }
}
