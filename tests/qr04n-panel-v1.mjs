import { readQmlSource } from './qml-source.mjs';
import assert from "node:assert/strict";
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
const dir = dirname(fileURLToPath(import.meta.url));
const qml = readQmlSource(resolve(dir, "../shared/panels/NordVPNPanel.qml"), "utf8");
assert.match(qml, /required property var root/);
assert.match(qml, /required property var controller/);
assert.match(qml, /root\.vpnVisible/);
assert.doesNotMatch(qml, /networkVisible|Quickshell\.exec|\bProcess\s*\{|\bTimer\s*\{/);
for (const action of ["connectVpnCountry", "pauseVpn", "setVpnSetting", "connectVpn", "disconnectVpn"]) assert.ok(qml.includes(`controller.${action}`), `missing ${action} callback`);
for (const key of ["firewall", "kill-switch", "threat-protection-lite", "auto-connect", "technology"]) assert.ok(qml.includes(key), `missing ${key} control`);
// Keep the real adapter/import graph inside the Quickshell config root.
// Only the controller is a recording double; no VPN backend is instantiated.
const project = resolve(dir, "..");
const scratch = mkdtempSync(resolve(tmpdir(), "qr04n-panel-"));
try {
  for (const file of [
    "variants/V1/panels/NordVPNPanel.qml",
    "variants/V1/modules/PillShadow.qml",
    "variants/V1/modules/SidePanelPositioner.qml",
    "shared/panels/NordVPNPanel.qml",
    "shared/components/UiText.qml",
  ]) {
    const target = resolve(scratch, file);
    mkdirSync(dirname(target), { recursive: true });
    copyFileSync(resolve(project, file), target);
  }
  const fixture = readFileSync(resolve(dir, "qml/qr04n-panel-v1.qml"), "utf8")
    .replace("../../variants/V1/panels/NordVPNPanel.qml", "variants/V1/panels/NordVPNPanel.qml");
  writeFileSync(resolve(scratch, "shell.qml"), fixture);
  const cmd = spawnSync("qs", ["--path", resolve(scratch, "shell.qml"), "--verbose"], {
    encoding: "utf8", timeout: 12000, env: { ...process.env, DISPLAY: undefined }
  });
  const output = `${cmd.stdout ?? ""}${cmd.stderr ?? ""}`;
  assert.equal(cmd.error, undefined, `Quickshell runner error: ${cmd.error}`);
  assert.equal(cmd.status, 0, `Quickshell rc ${cmd.status}; output:\n${output}`);
  assert.doesNotMatch(output, /ERROR|ReferenceError|TypeError|Unable to assign|Binding loop/,
    `Quickshell runtime diagnostics:\n${output}`);
  assert.match(output, /QR04N_PANEL_QML_PASS isolated signal-handler coverage: toggle x2, country selection\/connect, security, auto-connect, technology, protocol, busy controls, 5 pauses, close/,
    `Quickshell exited without required pass marker:\n${output}`);
  console.log("QR04N_PANEL_V1_STATIC_PASS");
  console.log("QR04N_PANEL_V1_RUNTIME_PASS");
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
