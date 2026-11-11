pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules" as Native

// Shared controls and behavior; only the variant surface and geometry live here.
Shared.WallpaperManagerQuickPanel {
    id: panel
    frameX: Math.max(8, Math.min(panel.width - panel.surfaceHost.width - 8, panel.root.wallpaperManagerAnchorX - panel.surfaceHost.width / 2))
    frameY: Math.max(8, Math.min(panel.height - panel.surfaceHost.height - 8, panel.root.wallpaperManagerAnchorY + 8))
    frameColor: panel.root.paper
    frameBorderColor: panel.root.pillBorder
    frameBorderWidth: panel.root.pillBorderW
    frameRadius: panel.root.pillRadius
    buttonRadius: panel.root.tileRadius
    surfaceComponent: Component {
        Item {
            Native.PillShadow { parent: panel.surfaceHost; theme: panel.root }
            Native.SidePanelPositioner { root: panel.root; target: panel.surfaceHost; anchorName: "wallpaperManager" }
            Canvas {
                id: edgeAccent
                x: 8; y: -8
                width: panel.surfaceHost.width - 16; height: 10
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.beginPath()
                    ctx.moveTo(0, 9)
                    ctx.lineTo(width / 2 - 5, 9)
                    ctx.lineTo(width / 2, 1)
                    ctx.lineTo(width / 2 + 5, 9)
                    ctx.lineTo(width, 9)
                    ctx.strokeStyle = panel.root.seal
                    ctx.lineWidth = 1
                    ctx.shadowColor = panel.root.seal
                    ctx.shadowBlur = 7
                    ctx.stroke()
                }
                Connections {
                    target: panel.root
                    function onSealChanged() { edgeAccent.requestPaint() }
                }
            }
        }
    }
}
