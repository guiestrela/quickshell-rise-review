// Common behavior for variant-specific presentations.
.pragma library

function handleButton(riseOwner, riseEnvironment, button) {
    var riseState = riseOwner;

        riseEnvironment.tip.hide()
        if (button === riseEnvironment.Qt.MiddleButton) riseOwner.root.wallpaperManagerServiceApi.nextAll()
        else riseOwner.root.toggleWallpaperManager(riseOwner.screen, riseOwner)
    }
