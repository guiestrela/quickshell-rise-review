// Common behavior for variant-specific presentations.
.pragma library

function refresh(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (riseEnvironment.wxData.running) return
        riseState.refreshing = true
        riseEnvironment.wxData.running = true
    }
