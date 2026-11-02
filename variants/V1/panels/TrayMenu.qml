pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules"

Shared.TrayMenu {
    id: panel
    barBottom: 35
    gap: 8
    cardRadius: panel.root.pillRadius
    cardBorderColor: panel.root.pillBorder
    cardBorderWidth: panel.root.pillBorderW
    rowRadius: panel.root.tileRadius
    shadowComponent: Component {
        PillShadow { theme: panel.root }
    }
    positionerComponent: Component {
        SidePanelPositioner { root: panel.root; target: panel.cardTarget; anchorName: "tray" }
    }
}
