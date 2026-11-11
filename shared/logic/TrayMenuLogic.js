// Common behavior for variant-specific presentations.
.pragma library

function openSubmenu(riseOwner, riseEnvironment, entryHandle) {
    var riseState = riseOwner;

        if (!entryHandle) return
        if (typeof entryHandle.opened === "function") entryHandle.opened()
        riseOwner.menuStack = riseOwner.menuStack.concat([entryHandle])
    }

function goBack(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (riseOwner.menuStack.length <= 1) return
        var current = riseOwner.currentHandle
        if (current && typeof current.closed === "function") current.closed()
        riseOwner.menuStack = riseOwner.menuStack.slice(0, -1)
    }
