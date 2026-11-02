pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules" as Native

// Only the variant's presentation is defined here; controls and actions are shared.
Shared.NordVPNPanel {
    id: panel
    barBottom: panel.root.v2BarHeight
    gap: 6
    frameRadius: panel.root.panelRadius
    frameColor: "transparent"
    frameBorderColor: panel.root.panelBorder
    frameBorderWidth: 0
    buttonRadius: panel.root.panelButtonRadius
    surfaceComponent: Component {
        Item {
            Native.PillShadow { parent: panel.surfaceHost; theme: panel.root }
            Native.SidePanelPositioner { root: panel.root; target: panel.surfaceHost; anchorName: "vpn" }
            Native.ConnectedPanelSurface {
                parent: panel.surfaceHost
                z: -1
                root: panel.root
                ownerActive: panel.root.vpnVisible
                targetX: panel.root.vpnBarX
                reveal: panel.reveal
            }
        }
    }
}
