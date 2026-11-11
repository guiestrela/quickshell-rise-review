// Common behavior for variant-specific presentations.
.pragma library

function cells(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        void(riseState.revision)
        var out = []
        for (var r = 0; r < riseEnvironment.models.length; r++) {
            for (var i = 0; i < riseEnvironment.models[r].count; i++) {
                var gid = riseEnvironment.models[r].get(i).gid
                if (gid || riseOwner.root.barUnlocked) out.push({gid: gid, region: r, index: i})
            }
        }
        return out
    }

function regionStart(riseOwner, riseEnvironment, region) {
    var riseState = riseOwner;

        if (region === 0) return 0
        var bottom = riseEnvironment.stack.height - riseState.regionHeight(2)
        if (region === 2) return bottom
        var centerHeight = riseState.regionHeight(1)
        return Math.max(riseState.regionHeight(0) + 12,
            Math.min((riseEnvironment.stack.height - centerHeight) / 2, bottom - centerHeight - 12))
    }

function layoutSnapshot(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var out = []
        for (var i = 0; i < riseEnvironment.items.count; i++) {
            var cell = riseEnvironment.items.objectAt(i)
            if (cell && cell.visible) out.push({gid: cell.gid, region: cell.modelData.region, y: cell.mapToItem(riseEnvironment.stack, 0, 0).y, height: cell.height})
        }
        return out
    }
