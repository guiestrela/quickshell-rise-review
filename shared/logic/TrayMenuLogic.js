// Common behavior for variant-specific presentations.
.pragma library

function openSubmenu(riseOwner, riseEnvironment, entryHandle, openerComponent) {
    var riseState = riseOwner;

        if (!entryHandle || !entryHandle.hasChildren || !openerComponent) return
        var opener = openerComponent.createObject(riseOwner, { menu: entryHandle })
        if (!opener) return
        var stack = riseOwner.menuStack.slice()
        stack.push({ opener: opener, title: String(entryHandle.text || "") })
        riseOwner.menuStack = stack
    }

function goBack(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (riseOwner.menuStack.length === 0) return
        var stack = riseOwner.menuStack.slice()
        var current = stack.pop()
        riseOwner.menuStack = stack
        if (current && current.opener) current.opener.destroy()
    }

function resetSubmenus(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var stack = riseOwner.menuStack
        riseOwner.menuStack = []
        for (var i = stack.length - 1; i >= 0; i--)
            if (stack[i] && stack[i].opener) stack[i].opener.destroy()
    }
