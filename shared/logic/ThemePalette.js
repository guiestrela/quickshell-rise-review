// Shared behavior; owner is the active variant, environment supplies QML services.
.pragma library

function paletteColor(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        if (id === "color02") return riseState.color02
        if (id === "color03") return riseState.color03
        if (id === "color04") return riseState.color04
        if (id === "color05") return riseState.color05
        if (id === "color06") return riseState.color06
        if (id === "color07") return riseState.color07
        if (id === "foreground") return riseState.foregroundSoft
        if (id === "accent") return riseState.accentHint
        return riseState.color01
    }

function normalizedPaletteId(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        if (id === "red" || id === "accent") return "color01"
        return riseState.paletteColorValid(id) ? id : "color01"
    }

function paletteColorValid(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        return id === "color01" || id === "color02" || id === "color03"
            || id === "color04" || id === "color05" || id === "color06"
            || id === "color07" || id === "foreground"
    }

function barColorValid(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        return riseState.paletteColorValid(id) || id === "red" || id === "accent"
    }

function barColorLabel(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        if (id === "color01" || id === "red" || id === "accent") return "Color 01"
        if (id === "color02") return "Color 02"
        if (id === "color03") return "Color 03"
        if (id === "color04") return "Color 04"
        if (id === "color05") return "Color 05"
        if (id === "color06") return "Color 06"
        if (id === "color07") return "Color 07"
        if (id === "foreground") return "Foreground"
        return "Color 01"
    }

function _linearColorChannel(riseOwner, riseEnvironment, v) {
    var riseState = riseOwner;

        return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    }

function _relativeLuminance(riseOwner, riseEnvironment, c) {
    var riseState = riseOwner;

        return 0.2126 * riseState._linearColorChannel(c.r)
             + 0.7152 * riseState._linearColorChannel(c.g)
             + 0.0722 * riseState._linearColorChannel(c.b)
    }

function _contrastRatio(riseOwner, riseEnvironment, a, b) {
    var riseState = riseOwner;

        var la = riseState._relativeLuminance(a)
        var lb = riseState._relativeLuminance(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }

function paletteContrastColor(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        var fill = riseState.paletteColor(id)
        return riseState._contrastRatio(fill, riseState.paper) >= riseState._contrastRatio(fill, riseState.ink) ? riseState.paper : riseState.ink
    }
