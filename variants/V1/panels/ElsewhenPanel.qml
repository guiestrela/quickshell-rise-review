pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules" as Native

Shared.ElsewhenPanel {
    id: panel
    barBottom: 35
    gap: 8
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
    frameRadius: panel.root.pillRadius
    frameColor: panel.root.bg
    frameBorderColor: panel.root.pillBorder
    frameBorderWidth: panel.root.pillBorderW
    buttonRadius: panel.root.tileRadius
    actionButtonStyleOverride: ({
        fillIdle: panel.root.fillIdle,
        fillHover: panel.root.fillHover,
        ink: panel.root.fg,
        seal: panel.root.seal,
        sep: panel.root.sep,
        mono: panel.root.mono
    })
    surfaceComponent: Component {
        Item {
            Native.PillShadow { parent: panel.surfaceHost; theme: panel.root }
            Native.SidePanelPositioner { root: panel.root; target: panel.surfaceHost; anchorName: "elsewhen" }
        }
    }
}
