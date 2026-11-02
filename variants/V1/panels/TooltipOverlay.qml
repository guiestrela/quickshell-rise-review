pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules"

Shared.TooltipOverlay {
    id: overlay
    barBottom: 35
    gap: 6
    surfaceColor: overlay.root.barBg
    surfaceBorderColor: overlay.root.pillBorder
    surfaceBorderWidth: overlay.root.pillBorderW
    surfaceRadius: overlay.root.pillRadius
    shadowComponent: Component {
        PillShadow { theme: overlay.root }
    }
}
