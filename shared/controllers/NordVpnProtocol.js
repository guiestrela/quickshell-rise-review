// NordVPN <=5 separates Technology/Protocol; >=6 reports a unified Protocol.
// Pure normalization only: never infer a selection from an unspecified value.
function normalizeSettings(settings) {
    var result = Object.assign({}, settings);
    if (result.technology || !result.protocol) return result;
    var raw = String(result.protocol).trim().toUpperCase();
    if (raw === "UDP" || raw === "TCP") return result;
    var protocol = raw.replace(/^VPN_PROTOCOL_/, "").replace(/[\s-]+/g, "_");
    result["protocol-api"] = "unified";
    result["vpn-protocol"] = String(result.protocol);
    result.technology = "";
    result.protocol = "";
    result["selection-notice"] = "";
    if (protocol === "NORDLYNX") result.technology = "NORDLYNX";
    else if (protocol === "NORDWHISPER") result.technology = "NORDWHISPER";
    else if (protocol === "OPENVPN_UDP" || protocol === "OPENVPN_TCP") {
        result.technology = "OPENVPN";
        result.protocol = protocol === "OPENVPN_TCP" ? "TCP" : "UDP";
    } else {
        result["selection-notice"] = "NordVPN did not report the active protocol. After an update, restart the NordVPN service when convenient. No VPN settings or connection state were changed.";
    }
    return result;
}

// Only use a validated local-daemon readback for an otherwise unknown snapshot.
function applyDaemonSelection(settings, reply) {
    var result = Object.assign({}, settings);
    if (result["protocol-api"] !== "unified" || !result["selection-notice"])
        return result;
    if (!reply || reply.schema !== 1
            || ["OPENVPN", "NORDLYNX", "NORDWHISPER"].indexOf(reply.technology) < 0
            || ["", "UDP", "TCP"].indexOf(reply.protocol) < 0
            || (reply.technology === "OPENVPN" && reply.protocol === ""))
        return result;
    result.technology = reply.technology;
    result.protocol = reply.protocol;
    result["selection-source"] = "daemon-rpc";
    result["selection-notice"] = "";
    result["selection-write-notice"] = "The NordVPN client and running service use different versions. The current selection was read directly from the service. Restart the NordVPN service before changing technology or transport.";
    return result;
}
