// Read-only search and health data shared by both ControlPanel variants.
.pragma library

var catalog = [
    { id: "actions", title: "Actions", category: "Control", keywords: "reload version switch v1 v2", target: "actions", detail: "Reload the shell or select a bar variant." },
    { id: "power", title: "Power actions", category: "Control", keywords: "lock suspend reboot shutdown", target: "power", detail: "Open the existing, initially collapsed power controls." },
    { id: "bar-color", title: "Bar color", category: "Appearance", keywords: "palette foreground background color", target: "colors", detail: "Choose from the current palette." },
    { id: "picker-style", title: "Picker style", category: "Appearance", keywords: "tanzaku hearthstone carousel wallpaper themes", target: "picker", detail: "Choose the existing picker presentation." },
    { id: "split-layout", title: "Split layout", category: "Layout", keywords: "split merge protect slots default", target: "splits", variants: ["V1"], detail: "Open split and layout controls." },
    { id: "bar-functions", title: "Bar functions", category: "Layout", keywords: "widgets workspaces compact controls", target: "functions", detail: "Open the existing bar-functions panel." },
    { id: "widgets", title: "Widgets", category: "Bar functions", keywords: "toggle show hide module", target: "widgets", detail: "Open the widget controls." },
    { id: "memory", title: "Memory widget", category: "Widgets", keywords: "ram usage", target: "widgets", detail: "Find Memory in the widget controls." },
    { id: "ai-usage", title: "AI usage widget", category: "Widgets", keywords: "claude codex copilot opencode quota provider", target: "widgets", detail: "Find AI usage in the widget controls; no provider is queried." },
    { id: "indicators", title: "Indicators (G23)", category: "Widgets", keywords: "indicator status dot three dots g23", target: "widgets", detail: "Open the independent Indicators widget control." },
    { id: "nordvpn", title: "NordVPN", category: "Widgets", keywords: "vpn countries connect apply", target: "widgets", detail: "Find NordVPN in the widget controls; its keyboard and Connect/Apply flows are unchanged." },
    { id: "wallpapers", title: "Wallpapers", category: "Widgets", keywords: "wallpaper display output screen", target: "widgets", detail: "Find Wallpapers in the widget controls; per-output behavior is unchanged." },
    { id: "network", title: "Network", category: "Widgets", keywords: "wifi wi-fi ethernet", target: "widgets", detail: "Find Network in the widget controls; no scan or connectivity probe is run." },
    { id: "brightness", title: "Brightness", category: "Widgets", keywords: "backlight display", target: "widgets", detail: "Find Brightness if a backlight is detected." },
    { id: "battery", title: "Battery", category: "Widgets", keywords: "power charge", target: "widgets", detail: "Find Battery if the host reports a laptop battery." },
    { id: "workspaces", title: "Workspaces", category: "Bar functions", keywords: "workspace desktops persist style", target: "workspaces", detail: "Open and expand workspace settings." },
    { id: "compact", title: "Compact display", category: "Bar functions", keywords: "icon full compact density", target: "compact", variants: ["V1"], detail: "Open compact widget presentation settings." },
    { id: "styles", title: "Bar styles", category: "Appearance", keywords: "style shell full fit dock notch border frost shadow radius", target: "styles", detail: "Open the current variant's style controls." },
    { id: "position", title: "Bar position", category: "Appearance", keywords: "position posicao top bottom", target: "position", detail: "Choose the existing top or bottom placement." },
    { id: "logo", title: "Launcher logo", category: "Appearance", keywords: "launcher icon text logo", target: "logo", detail: "Open launcher logo choices." }
];

function normalize(value) {
    return String(value === undefined || value === null ? "" : value)
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase();
}

function entriesForVariant(variant) {
    var requested = String(variant || "").toUpperCase();
    return catalog.filter(function(entry) {
        return !entry.variants || entry.variants.indexOf(requested) >= 0;
    }).map(function(entry) {
        return {
            id: entry.id,
            title: entry.title,
            category: entry.category,
            keywords: entry.keywords,
            target: entry.target,
            detail: entry.detail
        };
    });
}

function filterEntries(entries, query, limit) {
    var cap = Number.isFinite(Number(limit)) ? Math.max(0, Math.floor(Number(limit))) : 12;
    var terms = normalize(query).trim().split(/\s+/).filter(Boolean);
    var source = Array.isArray(entries) ? entries : [];
    var matches = source.filter(function(entry) {
        if (!entry) return false;
        var haystack = normalize([entry.title, entry.category, entry.keywords, entry.detail].join(" "));
        return terms.every(function(term) { return haystack.indexOf(term) >= 0; });
    });
    return matches.slice(0, cap);
}

function healthRows(snapshot) {
    var state = snapshot || {};
    var variant = state.variant === "v1" || state.variant === "v2"
        ? state.variant.toUpperCase() : "Unknown";
    var switching = state.switching === true ? "In progress"
        : state.switching === false ? "Idle" : "Unknown";
    var output = String(state.outputName || "").trim() || "Not selected";
    var battery = state.battery === true ? "Detected"
        : state.battery === false ? "Not detected" : "Unknown";
    var backlight = state.backlight === true ? "Detected"
        : state.backlight === false ? "Not detected" : "Unknown";
    var networkModes = { wifi: "Wi-Fi", ethernet: "Ethernet", none: "Not reported" };
    var network = networkModes[String(state.networkMode || "").toLowerCase()] || "Unknown";

    return [
        { label: "Variant", value: variant, detail: "Current variant host value; not a readiness guarantee." },
        { label: "Variant switch", value: switching, detail: "Whether the variant host reports a switch in progress." },
        { label: "Popup output", value: output, detail: "Current popup target only; this is not a monitor inventory." },
        { label: "Battery capability", value: battery, detail: "Local UPower-backed capability flag; no battery action is run." },
        { label: "Backlight capability", value: backlight, detail: "Local host capability flag; no brightness change is made." },
        { label: "Network widget mode", value: network, detail: "Widget mode only; no Wi-Fi scan or connectivity test is run." },
        { label: "External checks", value: "Not run", detail: "No account, credential, remote service, or external network probe is queried." }
    ];
}
