// Pure append-only layout migrations for the Wallpapers bar group.
function migrateV1Order(left, center, right) {
    var has = right.indexOf("G17") >= 0 || left.indexOf("G17") >= 0 || center.indexOf("G17") >= 0
    if (has) return { left: left, center: center, right: right }
    if (left.length !== 7 || center.length !== 1 || right.length !== 8) return null
    var all = left.concat(center, right), seen = {}
    for (var i = 0; i < all.length; i++) {
        if (!/^G(?:[1-9]|1[0-6])$/.test(all[i]) || seen[all[i]]) return null
        seen[all[i]] = true
    }
    if (Object.keys(seen).length !== 16) return null
    return { left: left.slice(), center: center.slice(), right: right.concat(["G17"]) }
}
function migrateV2Entries(left, center, right) {
    var all = left.concat(center, right), seen = {}, has = false
    for (var i = 0; i < all.length; i++) {
        var id = all[i].gid
        if (id === "") continue
        if (!/^G(?:[1-9]|1[0-9]|20)$/.test(id) || seen[id]) return null
        seen[id] = true
    }
    has = seen.G20 === true
    for (var n = 1; n <= (has ? 20 : 19); n++)
        if (!seen["G" + n]) return null
    var l = left.map(function (e) { return { gid: e.gid, extra: e.extra } })
    var c = center.map(function (e) { return { gid: e.gid, extra: e.extra } })
    var r = right.map(function (e) { return { gid: e.gid, extra: e.extra } })
    if (has) return { left: l, center: c, right: r }
    for (var j = 0; j < r.length; j++) if (r[j].gid === "") {
        r[j].gid = "G20"; return { left: l, center: c, right: r }
    }
    for (var k = 0; k < l.length; k++) if (l[k].gid === "") {
        l[k].gid = "G20"; return { left: l, center: c, right: r }
    }
    for (var m = 0; m < c.length; m++) if (c[m].gid === "") {
        c[m].gid = "G20"; return { left: l, center: c, right: r }
    }
    return null
}
