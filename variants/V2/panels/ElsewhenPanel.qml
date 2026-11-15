pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules" as Native

Shared.ElsewhenPanel {
    id: panel
    barBottom: panel.root.v2BarHeight
    gap: 6
    contentPaletteOverride: ({
        bg: panel.root.bg,
        ink: panel.root.fg,
        accent: panel.root.accent,
        seal: panel.root.seal,
        sep: panel.root.sep,
        fillIdle: panel.root.fillIdle,
        fillHover: panel.root.fillHover,
        sumi: panel.root.muted
    })
    actionButtonStyleOverride: ({
        fillIdle: panel.root.fillIdle,
        fillHover: panel.root.fillHover,
        ink: panel.root.fg,
        seal: panel.root.seal,
        sep: panel.root.sep,
        mono: panel.root.mono
    })
    frameRadius: panel.reveal > 0.001 ? panel.root.panelRadius : 0
    frameColor: "transparent"
    frameBorderColor: panel.root.panelBorder
    frameBorderWidth: 0
    buttonRadius: panel.root.panelButtonRadius
    revealShift: 2 * (1 - panel.reveal)
    surfaceComponent: Component {
        Item {
            Native.PillShadow { parent: panel.surfaceHost; theme: panel.root }
            Native.ConnectedPanelSurface {
                objectName: "elsewhen-connected-panel-surface"
                parent: panel.surfaceHost
                z: -1
                root: panel.root
                surfaceFillColor: panel.root.barBg
                ownerActive: panel.root.elsewhenVisible
                targetX: panel.root.elsewhenBarX
                reveal: panel.reveal
            }
            Native.SidePanelPositioner { root: panel.root; target: panel.surfaceHost; anchorName: "elsewhen" }
        }
    }
}
