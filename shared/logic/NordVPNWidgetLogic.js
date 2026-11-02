// Common behavior for variant-specific presentations.
.pragma library

function activate(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var point = riseOwner.mapToItem(null, riseOwner.width / 2, 0)
        riseEnvironment.root.setPanelAnchor("vpn", point.x, riseEnvironment.root.activePopupScreenName)
        riseEnvironment.root.vpnVisible = true
    }
