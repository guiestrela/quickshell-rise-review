// Common behavior for variant-specific presentations.
.pragma library

function nextWallpaper(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (riseOwner.configured) riseOwner.root.shuffleWallpapers()
        else riseOwner.openPicker()
    }
