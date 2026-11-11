import QtQuick
import QtQuick.Shapes

// Shared AI/Volume prototype: one filled/stroked silhouette renders the complete
// card outline and caret. There are no masks or separately joined border objects.
Item {
    id: surface

    required property var root
    required property real targetX
    // Shared animated progress from Theme; default keeps hot-reload construction safe.
    property real reveal: 0

    anchors.fill: parent
    z: 0

    readonly property bool pointsUp: root.barPosition !== "bottom"
    readonly property real centerX: Math.max(10, Math.min(width - 10,
        Math.round(targetX - parent.x)))
    readonly property real r: root.panelRadius
    readonly property real progress: Math.max(0, Math.min(1, reveal))
    readonly property real maxCaretDepth: 5
    readonly property real caretHalfWidth: 6 * progress
    readonly property real caretDepth: maxCaretDepth * progress
    readonly property real caretTangentControl: 3.75 * progress
    readonly property real caretTipControl: 1.75 * progress
    readonly property real topBaseY: maxCaretDepth + 0.5
    readonly property real topTipY: topBaseY - caretDepth
    readonly property real bottomBaseY: height - 0.5
    readonly property real bottomTipY: bottomBaseY + caretDepth
    readonly property int renderScale: 4

    property real targetY: sideTargetY
    readonly property real sideTargetY: {
        var names = {control: "launcher", workspace: "workspace", calendar: "calendar",
            weather: "weather", cpu: "cpu", gpu: "gpu", thermal: "thermal",
            aiUsage: "ai", mem: "memory", vol: "volume", network: "network",
            vpn: "vpn", bluetooth: "bluetooth", battery: "battery",
            brightness: "brightness", mpris: "mpris", notif: "notif",
            powerProfile: "power", storage: "storage", arch: "arch", tray: "tray",
            displayManager: "displayManager", wallpaperManager: "wallpaperManager"}
        for (var name in names)
            if (root[name + "Visible"] === true)
                return root.verticalAnchorY(names[name]) - parent.y
        return height / 2
    }

    // Rotate the complete silhouette so the caret and border remain one path.
    Shape {
        id: sideSurface
        visible: surface.root.barVertical
        width: surface.height
        height: surface.width
        x: surface.root.barPosition === "left" ? 0 : surface.width
        y: surface.root.barPosition === "left" ? surface.height : 0
        rotation: surface.root.barPosition === "left" ? -90 : 90
        transformOrigin: Item.TopLeft
        readonly property real tipCenter: Math.max(surface.r + 8,
            Math.min(width - surface.r - 8, surface.root.barPosition === "left"
                ? width - surface.targetY : surface.targetY))
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: surface.root.panelOuterBorderColor
            strokeWidth: surface.root.panelOuterBorderW
            fillColor: surface.root.bg
            joinStyle: ShapePath.RoundJoin
            startX: surface.r; startY: 0.5
            PathLine { x: sideSurface.tipCenter - surface.caretHalfWidth; y: 0.5 }
            PathCubic {
                x: sideSurface.tipCenter; y: 0.5 - surface.caretDepth
                control1X: sideSurface.tipCenter - surface.caretTangentControl; control1Y: 0.5
                control2X: sideSurface.tipCenter - surface.caretTipControl; control2Y: 0.5 - surface.caretDepth
            }
            PathCubic {
                x: sideSurface.tipCenter + surface.caretHalfWidth; y: 0.5
                control1X: sideSurface.tipCenter + surface.caretTipControl; control1Y: 0.5 - surface.caretDepth
                control2X: sideSurface.tipCenter + surface.caretTangentControl; control2Y: 0.5
            }
            PathLine { x: sideSurface.width - surface.r; y: 0.5 }
            PathArc { x: sideSurface.width - 0.5; y: surface.r; radiusX: surface.r; radiusY: surface.r }
            PathLine { x: sideSurface.width - 0.5; y: sideSurface.height - surface.r }
            PathArc { x: sideSurface.width - surface.r; y: sideSurface.height - 0.5; radiusX: surface.r; radiusY: surface.r }
            PathLine { x: surface.r; y: sideSurface.height - 0.5 }
            PathArc { x: 0.5; y: sideSurface.height - surface.r; radiusX: surface.r; radiusY: surface.r }
            PathLine { x: 0.5; y: surface.r }
            PathArc { x: surface.r; y: 0.5; radiusX: surface.r; radiusY: surface.r }
        }
    }

    Shape {
        x: 0
        y: -surface.maxCaretDepth
        width: surface.width
        height: surface.height + surface.maxCaretDepth
        visible: !surface.root.barVertical && surface.pointsUp
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 8
        layer.smooth: true
        layer.mipmap: true
        layer.textureSize: Qt.size(Math.ceil(width * surface.renderScale),
            Math.ceil(height * surface.renderScale))

        ShapePath {
            strokeColor: surface.root.panelOuterBorderColor
            strokeWidth: surface.root.panelOuterBorderW
            fillColor: surface.root.bg
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            startX: surface.r
            startY: surface.topBaseY
            PathLine {
                x: surface.centerX - surface.caretHalfWidth
                y: surface.topBaseY
            }
            PathCubic {
                x: surface.centerX; y: surface.topTipY
                control1X: surface.centerX - surface.caretTangentControl
                control1Y: surface.topBaseY
                control2X: surface.centerX - surface.caretTipControl
                control2Y: surface.topTipY
            }
            PathCubic {
                x: surface.centerX + surface.caretHalfWidth
                y: surface.topBaseY
                control1X: surface.centerX + surface.caretTipControl
                control1Y: surface.topTipY
                control2X: surface.centerX + surface.caretTangentControl
                control2Y: surface.topBaseY
            }
            PathLine { x: surface.width - surface.r; y: surface.topBaseY }
            PathArc { x: surface.width - 0.5; y: surface.r + surface.topBaseY; radiusX: surface.r; radiusY: surface.r }
            PathLine { x: surface.width - 0.5; y: surface.height + surface.maxCaretDepth - 0.5 - surface.r }
            PathArc { x: surface.width - surface.r; y: surface.height + surface.maxCaretDepth - 0.5; radiusX: surface.r; radiusY: surface.r }
            PathLine { x: surface.r; y: surface.height + surface.maxCaretDepth - 0.5 }
            PathArc { x: 0.5; y: surface.height + surface.maxCaretDepth - 0.5 - surface.r; radiusX: surface.r; radiusY: surface.r }
            PathLine { x: 0.5; y: surface.r + surface.topBaseY }
            PathArc { x: surface.r; y: surface.topBaseY; radiusX: surface.r; radiusY: surface.r }
        }
    }

    Shape {
        x: 0
        y: 0
        width: surface.width
        height: surface.height + surface.maxCaretDepth
        visible: !surface.root.barVertical && !surface.pointsUp
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 8
        layer.smooth: true
        layer.mipmap: true
        layer.textureSize: Qt.size(Math.ceil(width * surface.renderScale),
            Math.ceil(height * surface.renderScale))

        ShapePath {
            strokeColor: surface.root.panelOuterBorderColor
            strokeWidth: surface.root.panelOuterBorderW
            fillColor: surface.root.bg
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            startX: surface.r
            startY: 0.5
            PathLine { x: surface.width - surface.r; y: 0.5 }
            PathArc { x: surface.width - 0.5; y: surface.r + 0.5; radiusX: surface.r; radiusY: surface.r }
            PathLine { x: surface.width - 0.5; y: surface.height - surface.r - 0.5 }
            PathArc { x: surface.width - surface.r; y: surface.height - 0.5; radiusX: surface.r; radiusY: surface.r }
            PathLine {
                x: surface.centerX + surface.caretHalfWidth
                y: surface.bottomBaseY
            }
            PathCubic {
                x: surface.centerX
                y: surface.bottomTipY
                control1X: surface.centerX + surface.caretTangentControl
                control1Y: surface.bottomBaseY
                control2X: surface.centerX + surface.caretTipControl
                control2Y: surface.bottomTipY
            }
            PathCubic {
                x: surface.centerX - surface.caretHalfWidth
                y: surface.bottomBaseY
                control1X: surface.centerX - surface.caretTipControl
                control1Y: surface.bottomTipY
                control2X: surface.centerX - surface.caretTangentControl
                control2Y: surface.bottomBaseY
            }
            PathLine { x: surface.r; y: surface.height - 0.5 }
            PathArc { x: 0.5; y: surface.height - surface.r - 0.5; radiusX: surface.r; radiusY: surface.r }
            PathLine { x: 0.5; y: surface.r + 0.5 }
            PathArc { x: surface.r; y: 0.5; radiusX: surface.r; radiusY: surface.r }
        }
    }
}
