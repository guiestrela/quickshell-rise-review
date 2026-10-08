// Shared V1-only defaults for startup and the Default Layout action.
.pragma library

function defaultOrder() {
    return {
        left: ["G1", "G2", "G3", "G4", "G5", "G6", "G7"],
        center: ["G8"],
        right: ["G9", "G10", "G17", "G14", "G12", "G13", "G11", "G16", "G15", "G18"]
    }
}

function defaultSplits() {
    return {
        left: [true, true, true, true, true, true],
        right: [true, true, true, true, true, true, true, true],
        boundary: [true, true]
    }
}

function defaultCompact() {
    return {
        compactNetwork: true,
        compactBattery: false,
        compactBrightness: false,
        compactCpu: true,
        compactMemory: true,
        compactVolume: true,
        compactBluetooth: true,
        compactPower: true,
        compactMpris: false,
        compactNordVpn: false,
        compactAi: false
    }
}

function compactCacheFields(nordVpn, ai) {
    return [nordVpn ? "1" : "0", ai ? "1" : "0"]
}

function parseCompactCacheFields(parts, wsField) {
    return {
        compactNordVpn: parts.length > wsField + 37 && parts[wsField + 37] === "1",
        compactAi: parts.length > wsField + 38 && parts[wsField + 38] === "1"
    }
}
