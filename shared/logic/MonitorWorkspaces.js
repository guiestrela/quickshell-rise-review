.pragma library

function parseBlocks(text) {
    var result = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var fields = lines[i].split("\t")
        if (fields.length >= 3 && fields[1] !== "") {
            var block = Number(fields[0])
            if (Number.isInteger(block) && block >= 0) result[fields[1]] = block
        }
    }
    return result
}

function blockFor(blocks, monitorName, activeWorkspaceId) {
    if (monitorName && blocks && blocks[monitorName] !== undefined)
        return Number(blocks[monitorName])
    var active = Number(activeWorkspaceId || 0)
    return active > 0 ? Math.floor((active - 1) / 10) : 0
}

function slotFor(workspaceId) {
    var id = Number(workspaceId)
    return id > 0 ? ((id - 1) % 10) + 1 : 0
}

function idFor(block, slot) {
    return Number(block) * 10 + Number(slot)
}

function guestIds(block, monitorName, workspaces) {
    if (!monitorName) return []
    var result = []
    var values = workspaces || []
    for (var i = 0; i < values.length; i++) {
        var id = Number(values[i].id)
        if (id > 0 && Math.floor((id - 1) / 10) !== Number(block)
                && values[i].monitor && values[i].monitor.name === monitorName)
            result.push(id)
    }
    return result.sort(function(a, b) { return a - b })
}

function slots(mode, block, activeWorkspaceId, workspaces) {
    var activeSlot = slotFor(activeWorkspaceId)
    if (mode !== "active") {
        var count = mode === "5" ? 5 : 10
        var fixed = []
        for (var i = 1; i <= count; i++) fixed.push(i)
        if (activeSlot > count) fixed.push(activeSlot)
        return fixed
    }

    var found = {}
    var values = workspaces || []
    for (var j = 0; j < values.length; j++) {
        var id = Number(values[j].id)
        if (id > 0 && Math.floor((id - 1) / 10) === Number(block))
            found[slotFor(id)] = true
    }
    if (activeSlot > 0) found[activeSlot] = true
    return Object.keys(found).map(Number).sort(function(a, b) { return a - b })
}
