// Normalize only local host properties consumed by ControlPanel Health.
function property(object, name) {
    if (!object || (typeof object !== "object" && typeof object !== "function"))
        return { present: false, value: undefined };
    try {
        var value = object[name];
        return { present: value !== undefined, value: value };
    } catch (error) {
        return { present: false, value: undefined, error: String(error) };
    }
}

function diagnostic(list, code, message) {
    list.push({ code: code, severity: "info", message: message });
}

function readHostCapabilities(hostRoot) {
    var diagnostics = [];
    var host = hostRoot || {};
    var variantHost = property(host, "variantHost");
    var variantValue = { present: false, value: undefined };
    var switchingValue = { present: false, value: undefined };

    if (!variantHost.present) {
        diagnostic(diagnostics, "variant-host-missing", "Host does not expose variantHost.");
    } else if (variantHost.value === null) {
        diagnostic(diagnostics, "variant-host-unavailable", "variantHost is present but not currently supplied.");
    } else {
        variantValue = property(variantHost.value, "runningVariant");
        switchingValue = property(variantHost.value, "switching");
        if (!variantValue.present)
            diagnostic(diagnostics, "variant-value-missing", "variantHost does not expose runningVariant.");
        if (!switchingValue.present)
            diagnostic(diagnostics, "switching-missing", "variantHost does not expose switching.");
    }

    var popupOutput = property(host, "activePopupScreenName");
    var battery = property(host, "hasBattery");
    var backlight = property(host, "hasBacklight");
    var network = property(host, "networkMode");
    if (!popupOutput.present)
        diagnostic(diagnostics, "popup-output-missing", "Host does not expose activePopupScreenName.");
    if (!battery.present)
        diagnostic(diagnostics, "battery-capability-missing", "Host does not expose hasBattery.");
    if (!backlight.present)
        diagnostic(diagnostics, "backlight-capability-missing", "Host does not expose hasBacklight.");
    if (!network.present)
        diagnostic(diagnostics, "network-mode-missing", "Host does not expose networkMode.");

    var variant = !variantHost.present ? "Unsupported"
        : variantHost.value === null ? "Unavailable"
        : !variantValue.present ? "Unsupported"
        : String(variantValue.value || "").trim() === "" ? "Not reported"
        : String(variantValue.value).toLowerCase() === "v1" ? "V1"
        : String(variantValue.value).toLowerCase() === "v2" ? "V2" : "Unknown";
    var switching = !variantHost.present ? "Unsupported"
        : variantHost.value === null ? "Unavailable"
        : !switchingValue.present ? "Unsupported"
        : switchingValue.value === true ? "In progress"
        : switchingValue.value === false ? "Idle" : "Unknown";
    var output = !popupOutput.present ? "Unsupported"
        : String(popupOutput.value || "").trim() || "Not selected";
    var batteryLabel = !battery.present ? "Unsupported"
        : battery.value === true ? "Detected" : battery.value === false ? "Not detected" : "Unknown";
    var backlightLabel = !backlight.present ? "Unsupported"
        : backlight.value === true ? "Detected" : backlight.value === false ? "Not detected" : "Unknown";
    var modes = { wifi: "Wi-Fi", ethernet: "Ethernet", none: "Not reported" };
    var modeKey = network.present ? String(network.value || "").toLowerCase() : "";
    var networkLabel = !network.present ? "Unsupported"
        : modes[modeKey] || (modeKey === "" ? "Not reported" : "Unknown");
    if (network.present && networkLabel === "Unknown")
        diagnostic(diagnostics, "network-mode-unknown", "Host supplied an unrecognized networkMode value.");

    var details = diagnostics.map(function(item) { return item.code + ": " + item.message; });
    var diagnosticSummary = diagnostics.length === 0
        ? "No host capability gaps were detected."
        : details.join("; ");
    var healthRows = [
        { label: "Variant", value: variant, detail: "Current variant host value; not a readiness guarantee." },
        { label: "Variant switch", value: switching, detail: "Whether the variant host reports a switch in progress." },
        { label: "Popup output", value: output, detail: "Current popup target only; this is not a monitor inventory." },
        { label: "Battery capability", value: batteryLabel, detail: "Local UPower-backed capability flag; no battery action is run." },
        { label: "Backlight capability", value: backlightLabel, detail: "Local host capability flag; no brightness change is made." },
        { label: "Network widget mode", value: networkLabel, detail: "Widget mode only; no Wi-Fi scan or connectivity test is run." },
        { label: "External checks", value: "Not run", detail: "No account, credential, remote service, or external network probe is queried." },
        { label: "Diagnostics", value: diagnostics.length === 0 ? "None" : diagnostics.length + " note(s)", detail: diagnosticSummary }
    ];
    return { healthRows: healthRows, diagnostics: diagnostics };
}
