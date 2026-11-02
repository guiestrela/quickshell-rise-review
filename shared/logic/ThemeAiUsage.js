// Shared behavior; owner is the active variant, environment supplies QML services.
.pragma library

function aiWindowLabel(riseOwner, riseEnvironment, minutes) {
    var riseState = riseOwner;

        if (minutes === 300) return "5h"
        if (minutes === 10080) return "Weekly"
        if (minutes > 0 && minutes % 1440 === 0) return (minutes / 1440) + "d"
        if (minutes > 0 && minutes % 60 === 0) return (minutes / 60) + "h"
        return minutes > 0 ? minutes + "m" : "window"
    }

function aiCodexWindowFromCache(riseOwner, riseEnvironment, w) {
    var riseState = riseOwner;

        w = w || {}
        var minutes = parseInt(w.minutes) || 0
        return {
            kind: String(w.kind || ""),
            minutes: minutes,
            label: String(w.label || riseOwner.aiWindowLabel(minutes)),
            pct: riseOwner.aiPct(w.utilization),
            resetTs: parseInt(w.reset) || 0
        }
    }

function aiCodexWindowsFromArray(riseOwner, riseEnvironment, arr) {
    var riseState = riseOwner;

        var out = []
        if (!arr || arr.length === undefined) return out
        for (var i = 0; i < arr.length; i++) {
            out.push(riseOwner.aiCodexWindowFromCache(arr[i]))
        }
        return out
    }

function aiCodexLegacyWindowsFromCache(riseOwner, riseEnvironment, d) {
    var riseState = riseOwner;

        var out = []
        if (!d) return out
        var has5 = d["5h-utilization"] !== undefined && String(d["5h-utilization"]) !== ""
        var has7 = d["7d-utilization"] !== undefined && String(d["7d-utilization"]) !== ""
        if (has5 || parseInt(d["5h-reset"]) > 0)
            out.push({ kind: "primary", minutes: 300, label: "5h", pct: riseOwner.aiPct(d["5h-utilization"]), resetTs: parseInt(d["5h-reset"]) || 0 })
        if (has7 || parseInt(d["7d-reset"]) > 0)
            out.push({ kind: "secondary", minutes: 10080, label: "Weekly", pct: riseOwner.aiPct(d["7d-utilization"]), resetTs: parseInt(d["7d-reset"]) || 0 })
        return out
    }

function aiCodexBucketsFromCache(riseOwner, riseEnvironment, d) {
    var riseState = riseOwner;

        var buckets = []
        if (d && parseInt(d.schemaVersion) === 3 && d.buckets && d.buckets.length !== undefined) {
            for (var i = 0; i < d.buckets.length; i++) {
                var b = d.buckets[i] || {}
                var windows = riseOwner.aiCodexWindowsFromArray(b.windows)
                if (windows.length === 0) continue
                buckets.push({
                    id: String(b.id || ""),
                    label: String(b.label || b.id || "Codex"),
                    isGeneral: b.isGeneral === true,
                    windows: windows,
                    plan: String(b.plan || ""),
                    rateLimitReachedType: String(b.rateLimitReachedType || "")
                })
            }
        } else if (d && parseInt(d.schemaVersion) === 2 && d.windows && d.windows.length !== undefined) {
            var win2 = riseOwner.aiCodexWindowsFromArray(d.windows)
            if (win2.length > 0)
                buckets.push({ id: "codex", label: "Codex", isGeneral: true, windows: win2, plan: String(d._plan || "") })
        } else {
            var legacy = riseOwner.aiCodexLegacyWindowsFromCache(d)
            if (legacy.length > 0)
                buckets.push({ id: "codex", label: "Codex", isGeneral: true, windows: legacy, plan: String((d && d._plan) || "") })
        }
        return buckets
    }

function aiCodexGeneralBucket(riseOwner, riseEnvironment, buckets) {
    var riseState = riseOwner;

        for (var i = 0; i < buckets.length; i++) {
            if (buckets[i].isGeneral === true || buckets[i].id === "codex") return buckets[i]
        }
        return { windows: [] }
    }

function aiPlanLabel(riseOwner, riseEnvironment, plan) {
    var riseState = riseOwner;

        var p = String(plan || "").toLowerCase()
        if (p === "prolite") return "Pro Lite"
        if (p === "pro") return "Pro"
        if (p === "plus") return "Plus"
        if (p === "team" || p === "business") return "Business"
        if (p === "enterprise") return "Enterprise"
        if (p === "edu") return "Edu"
        if (p === "free") return "Free"
        return String(plan || "")
    }

function aiApplyCodexCache(riseOwner, riseEnvironment, d, ageOk) {
    var riseState = riseOwner;

        var buckets = riseOwner.aiCodexBucketsFromCache(d)
        var general = riseOwner.aiCodexGeneralBucket(buckets)
        var windows = general.windows || []
        riseOwner.aiCxHas = windows.length > 0
        riseOwner.aiCxFresh = ageOk && d._source !== "stale"
        riseOwner.aiCxBuckets = buckets
        riseOwner.aiCxWindows = windows
        riseOwner.aiCxPlan = riseOwner.aiPlanLabel(d._plan || general.plan || "")
        riseOwner.aiCxPct5h = 0; riseOwner.aiCxPct7d = 0
        riseOwner.aiCxReset5hTs = 0; riseOwner.aiCxReset7dTs = 0
        riseOwner.aiCxQuotaPct = 0
        riseOwner.aiCxQuotaLabel = ""
        riseOwner.aiCxLimitStatus = String(d.status || "")
        riseOwner.aiCxLimitReachedType = String(d._limit_reached_type || general.rateLimitReachedType || "")
        for (var i = 0; i < windows.length; i++) {
            var w = windows[i]
            if (i === 0) {
                riseOwner.aiCxPrimaryPct = w.pct
                riseOwner.aiCxPrimaryLabel = w.label
                riseOwner.aiCxPrimaryResetTs = w.resetTs
            }
            if (w.minutes === 300) { riseOwner.aiCxPct5h = w.pct; riseOwner.aiCxReset5hTs = w.resetTs }
            else if (w.minutes === 10080) { riseOwner.aiCxPct7d = w.pct; riseOwner.aiCxReset7dTs = w.resetTs }
            if (w.pct > riseOwner.aiCxQuotaPct) {
                riseOwner.aiCxQuotaPct = w.pct
                riseOwner.aiCxQuotaLabel = String(general.label || "Codex") + " " + String(w.label || "window")
            }
        }
        if (windows.length === 0) {
            riseOwner.aiCxPrimaryPct = 0
            riseOwner.aiCxPrimaryLabel = ""
            riseOwner.aiCxPrimaryResetTs = 0
        }
        var cxRateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
        riseOwner.aiCxRate = cxRateH > 0 ? cxRateH + "k tok/h" : ""
        riseOwner.aiCxToday = parseInt(d._today_tokens) || 0
        riseOwner.aiCxTokens = ""
    }

function aiCodexStatusLabel(riseOwner, riseEnvironment, status, reachedType) {
    var riseState = riseOwner;

        if (status === "rejected")
            return reachedType ? "reached (" + reachedType + ")" : "reached"
        if (status === "allowed_warning") return "warning"
        if (status === "allowed") return "ok (not reached)"
        return "unknown"
    }

function aiFmtReset(riseOwner, riseEnvironment, ts) {
    var riseState = riseOwner;

        void riseState.aiClockTick
        var now = Date.now() / 1000
        if (!(ts > now)) return ""
        var mins = Math.round((ts - now) / 60)
        if (mins < 60) return mins + "m"
        var h = Math.floor(mins / 60), m = mins % 60
        if (h < 24) return h + "h " + m + "m"
        var d = Math.floor(h / 24); return d + "d " + (h % 24) + "h"
    }

function aiFmtResetClock(riseOwner, riseEnvironment, ts) {
    var riseState = riseOwner;

        void riseState.aiClockTick
        if (!(ts > Date.now() / 1000)) return ""
        var d = new Date(ts * 1000)
        var now = new Date()
        var day0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
        var resetDay0 = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
        var dayDelta = Math.round((resetDay0 - day0) / 86400000)
        var time = riseState.aiPad2(d.getHours()) + ":" + riseState.aiPad2(d.getMinutes())
        if (dayDelta <= 0) return time
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days[d.getDay()] + " " + time
    }

function aiFmtResetDetail(riseOwner, riseEnvironment, ts) {
    var riseState = riseOwner;

        var rel = riseState.aiFmtReset(ts)
        var clock = riseState.aiFmtResetClock(ts)
        return rel && clock ? rel + " • " + clock : (rel || clock)
    }

function aiApplyCopilotCache(riseOwner, riseEnvironment, d, ageOk) {
    var riseState = riseOwner;

        if (!d) { riseOwner.aiResetCopilotUsage(); return }
        var windows = riseOwner.aiCodexWindowsFromArray(d.windows)
        if (windows.length === 0) windows = riseOwner.aiCodexWindowsFromArray((d.buckets || [])[0] ? ((d.buckets || [])[0]).windows : [])
        riseOwner.aiCpHas = windows.length > 0
        riseOwner.aiCpFresh = ageOk && d._source !== "stale"
        riseOwner.aiCpPlan = String(d._plan || "")
        riseOwner.aiCpSku = String(d._sku || "")
        riseOwner.aiCpUnlimited = d._unlimited === true
        riseOwner.aiCpCreditsUsed = parseInt(d._credits_used) || 0
        riseOwner.aiCpCreditsEntitlement = parseInt(d._credits_entitlement) || 0
        riseOwner.aiCpLimitReachedType = String(d._limit_reached_type || "")
        riseOwner.aiCpStatus = String(d.status || "")
        if (windows.length === 0) {
            riseOwner.aiCpPct = 0; riseOwner.aiCpLabel = ""; riseOwner.aiCpResetTs = 0
            return
        }
        // Copilot reports exactly one window; take the widest as the headline one.
        var best = windows[0]
        for (var i = 1; i < windows.length; i++) {
            if (windows[i].minutes > best.minutes) best = windows[i]
        }
        riseOwner.aiCpPct = best.pct
        if (!riseOwner.aiCpUnlimited && riseOwner.aiCpCreditsEntitlement > 0)
            riseOwner.aiCpPct = Math.max(0, Math.min(100, Math.round(riseOwner.aiCpCreditsUsed / riseOwner.aiCpCreditsEntitlement * 100)))
        riseOwner.aiCpLabel = best.label
        riseOwner.aiCpResetTs = best.resetTs
    }
