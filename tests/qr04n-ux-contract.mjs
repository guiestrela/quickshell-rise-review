import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const project = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => readFileSync(resolve(project, p), "utf8");
for (const variant of ["", "variants/V2/"]) {
  const prefix = `versions/V1/${variant}`;
  const panelPath = `${prefix}panels/NordVPNPanel.qml`;
  const panelWrapper = read(panelPath);
  const panel = variant && panelWrapper.includes("Shared.NordVPNPanel")
    ? read("versions/V1/panels/NordVPNPanel.qml") : panelWrapper;
  const widget = read(`${prefix}modules/NordVPNWidget.qml`);
  assert.match(panel, /countryOptions/, `${variant || "V1"}: country list UI`);
  assert.match(panel, /auto-connect.*(?:enabled|disabled)|autoConnect/, `${variant || "V1"}: explicit auto-connect toggle`);
  assert.match(panel, /protocolOptions|Protocol.*unavailable/i, `${variant || "V1"}: protocol list and honest capability`);
  assert.doesNotMatch(panel, /DNS SERVERS \(IPv4\)|vpn-dns-input/, `${variant || "V1"}: DNS editor removed`);
  assert.match(widget, /TooltipMixin/, `${variant || "V1"}: Rise tooltip component`);
  assert.match(widget, /showTooltip|NordVPN (?:ON|OFF|N\/A)/, `${variant || "V1"}: tooltip has status text`);
}
const controller = read("versions/V1/modules/NordVpnController.qml");
assert.match(controller, /countries/);
assert.match(controller, /set.*autoconnect/);
console.log("QR04N UX contract PASS");
