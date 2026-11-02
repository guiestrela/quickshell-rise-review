pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules"

Shared.TooltipOverlay {
    id: overlay
    barBottom: overlay.root.v2BarHeight
    gap: 6
    useTooltipYForVertical: true
    surfaceColor: overlay.root.bg
    surfaceBorderColor: overlay.root.panelOuterBorderColor
    surfaceBorderWidth: overlay.root.panelOuterBorderW
    surfaceRadius: overlay.root.panelRadius
    shadowComponent: Component {
        PillShadow { theme: overlay.root }
    }
}
