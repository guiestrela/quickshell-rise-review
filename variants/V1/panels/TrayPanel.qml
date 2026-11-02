pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules" as Native

// Only the variant's presentation is defined here; controls and actions are shared.
Shared.TrayPanel {
    id: panel
    barBottom: 35
    gap: 8
    frameRadius: panel.root.pillRadius
    frameColor: panel.root.bg
    frameBorderColor: panel.root.pillBorder
    frameBorderWidth: panel.root.pillBorderW
    buttonRadius: panel.root.tileRadius
    surfaceComponent: Component {
        Item {
            Native.PillShadow { parent: panel.surfaceHost; theme: panel.root }
            Native.SidePanelPositioner { root: panel.root; target: panel.surfaceHost; anchorName: "tray" }
        }
    }
}
