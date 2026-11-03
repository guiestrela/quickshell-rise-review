pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules" as Native

// Shared controls and behavior; only the variant surface and geometry live here.
Shared.WallpaperManagerQuickPanel {
    id: panel
    readonly property int barBottom: panel.root.v2BarHeight
    readonly property int gap: 6
    Behavior on reveal {
        NumberAnimation {
            duration: panel.root.wallpaperManagerVisible ? 160 : 120
            easing.type: panel.root.wallpaperManagerVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    frameX: Math.round(Math.max(6, Math.min(panel.root.wallpaperManagerAnchorX - panel.surfaceHost.width / 2, panel.width - panel.surfaceHost.width - 6)))
    frameY: panel.root.barPosition === "bottom" ? (panel.height - panel.barBottom - panel.gap - panel.surfaceHost.height) + 2 * (1 - panel.reveal) : (panel.barBottom + panel.gap) - 2 * (1 - panel.reveal)
    frameColor: "transparent"
    frameBorderColor: panel.root.panelBorder
    frameBorderWidth: 0
    frameRadius: panel.reveal > 0.001 ? panel.root.panelRadius : 0
    buttonRadius: panel.root.panelButtonRadius
    surfaceComponent: Component {
        Item {
            Native.PillShadow { parent: panel.surfaceHost; theme: panel.root }
            Native.ConnectedPanelSurface {
                parent: panel.surfaceHost
                z: -1
                root: panel.root
                ownerActive: panel.root.wallpaperManagerVisible
                targetX: panel.root.wallpaperManagerAnchorX
                reveal: panel.reveal
            }
            Native.SidePanelPositioner { root: panel.root; target: panel.surfaceHost; anchorName: "wallpaperManager" }
        }
    }
}
