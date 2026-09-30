import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
const dir = dirname(fileURLToPath(import.meta.url));
const qml = readFileSync(resolve(dir, "../versions/V1/panels/NordVPNPanel.qml"), "utf8");
assert.match(qml, /required property var root/);
assert.match(qml, /required property var controller/);
assert.match(qml, /root\.vpnVisible/);
assert.doesNotMatch(qml, /networkVisible|Quickshell\.exec|\bProcess\s*\{|\bTimer\s*\{/);
for (const action of ["connectVpnCountry", "pauseVpn", "setVpnSetting", "connectVpn", "disconnectVpn"]) assert.ok(qml.includes(`controller.${action}`), `missing ${action} callback`);
for (const key of ["firewall", "kill-switch", "threat-protection-lite", "auto-connect", "technology"]) assert.ok(qml.includes(key), `missing ${key} control`);
const cmd = spawnSync("qs", ["--path", resolve(dir, "qml/qr04n-panel-v1.qml"), "--verbose"], {
  encoding: "utf8", timeout: 12000, env: { ...process.env, DISPLAY: undefined }
});
const output = `${cmd.stdout ?? ""}${cmd.stderr ?? ""}`;
assert.equal(cmd.error, undefined, `Quickshell runner error: ${cmd.error}`);
assert.equal(cmd.status, 0, `Quickshell rc ${cmd.status}; output:\n${output}`);
assert.match(output, /QR04N_PANEL_QML_PASS isolated signal-handler coverage: toggle x2, country go\/accepted, 5 settings, protocol, 5 pauses, close/,
  `Quickshell exited without required pass marker:\n${output}`);
console.log("QR04N_PANEL_V1_STATIC_PASS");
console.log("QR04N_PANEL_V1_RUNTIME_PASS");
