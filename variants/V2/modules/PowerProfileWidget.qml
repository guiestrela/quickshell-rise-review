pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as Shared

Shared.PowerProfileWidget {
    id: widget
    showPrefix: false
    showIcon: true
    showShortName: false
    rowSpacing: 4
    profileColor: widget.root.widgetHasFill("G14") ? widget.root.widgetContrastColor("G14") : (widget.isPowerSaver ? widget.root.indigo : widget.root.seal)
}
