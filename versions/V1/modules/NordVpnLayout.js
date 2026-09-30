// .pragma library
// Pure layout migrations shared by V1/V2 BarSlot and exercised by Node tests.
function migrateV1Order(left, center, right) {
    if (right.indexOf("G16") >= 0) return { left: left, center: center, right: right }
    if (left.length !== 7 || center.length !== 1 || right.length !== 7) return null
    var seen = {}
    var all = left.concat(center, right)
    for (var i = 0; i < all.length; i++) {
        if (!/^G(?:[1-9]|1[0-5])$/.test(all[i]) || seen[all[i]]) return null
        seen[all[i]] = true
    }
    if (Object.keys(seen).length !== 15) return null
    return { left: left.slice(), center: center.slice(), right: right.concat(["G16"]) }
}

function migrateV2Entries(left, center, right) {
    var all = left.concat(center, right)
    var seen = {}
    for (var i = 0; i < all.length; i++) {
        var gid = all[i].gid
        if (gid === "") continue
        if (!/^G(?:[1-9]|1[0-9]|20)$/.test(gid) || seen[gid]) return null
        seen[gid] = true
    }
    var hasNordVpn = seen.G19 === true
    for (var n = 1; n <= (hasNordVpn ? 19 : 18); n++)
        if (!seen["G" + n]) return null

    var l = left.map(function (entry) { return ({ gid: entry.gid, extra: entry.extra }) })
    var c = center.map(function (entry) { return ({ gid: entry.gid, extra: entry.extra }) })
    var r = right.map(function (entry) { return ({ gid: entry.gid, extra: entry.extra }) })
    if (hasNordVpn) return { left: l, center: c, right: r }

    for (var j = 0; j < r.length; j++) {
        if (r[j].gid === "") {
            r[j].gid = "G19"
            return { left: l, center: c, right: r }
        }
    }
    for (var k = 0; k < l.length; k++) {
        if (l[k].gid === "") {
            l[k].gid = "G19"
            return { left: l, center: c, right: r }
        }
    }
    for (var m = 0; m < c.length; m++) {
        if (c[m].gid === "") {
            c[m].gid = "G19"
            return { left: l, center: c, right: r }
        }
    }
    return null
}

function swapModels(source, target, sourceIndex, targetIndex) {
    if (!source || !target || sourceIndex < 0 || targetIndex < 0
            || sourceIndex >= source.count || targetIndex >= target.count) return false
    var sourceGid = source.get(sourceIndex).gid
    var targetGid = target.get(targetIndex).gid
    source.setProperty(sourceIndex, "gid", targetGid)
    target.setProperty(targetIndex, "gid", sourceGid)
    return true
}
