pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules"

Shared.TrayMenu {
    id: panel
    barBottom: panel.root.v2BarHeight
    gap: 8
    cardRadius: panel.root.panelRadius
    cardBorderColor: panel.root.panelOuterBorderColor
    cardBorderWidth: panel.root.panelOuterBorderW
    rowRadius: panel.root.panelButtonRadius
    shadowComponent: Component {
        PillShadow { theme: panel.root }
    }
    positionerComponent: Component {
        SidePanelPositioner { root: panel.root; target: panel.cardTarget; anchorName: "tray" }
    }
}
