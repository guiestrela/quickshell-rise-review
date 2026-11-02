import { readQmlSource } from './qml-source.mjs';
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const project = resolve(dirname(fileURLToPath(import.meta.url)), "..");
for (const [variant, path] of [
  ["V1", "shared/panels/NordVPNPanel.qml"],
  ["V2", "shared/panels/NordVPNPanel.qml"],
]) {
  const qml = readQmlSource(resolve(project, path), "utf8");
  assert.match(qml, /width:\s*Math\.min\(300, parent\.width - 16\)/, `${variant}: panel is capped at Network's 300px width`);
  assert.match(qml, /objectName:\s*"nordvpn-panel-card"/, `${variant}: card is discoverable in isolated UI test`);
  assert.match(readQmlSource(resolve(project, `variants/${variant}/panels/NordVPNPanel.qml`), "utf8"), variant === "V1" ? /buttonRadius: panel\.root\.tileRadius/ : /buttonRadius: panel\.root\.panelButtonRadius/,
    `${variant}: panel buttons keep native Network radius token`);
  // Compare actual action controls, not merely the presence of a radius token.
  for (const id of ["countryApplyMouse", "autoConnectApplyMouse"]) {
    assert.match(qml, new RegExp(`opacity: ${id}\\.enabled \\? 1 : 0\\.5`), `${variant}: ${id} visibly disabled`);
    assert.match(qml, new RegExp(`${id}\\.containsMouse && ${id}\\.enabled \\? vpnPanel\\.root\\.seal`), `${variant}: ${id} native enabled hover border`);
  }
  assert.match(qml, /color: vpnPanel\.autoConnectEnabled \? vpnPanel\.root\.fillActive/, `${variant}: selected auto-connect uses Network active fill`);
  const technologyLabel = qml.split('text: entryDelegate2.modelData; color: parent.selected')[1]?.split('}')[0] || '';
  assert.match(technologyLabel, /font.pixelSize: 10/, `${variant}: technology labels use Network 10px action typography`);
  assert.match(qml, /Keys\.onPressed[\s\S]*Qt\.Key_Escape[\s\S]*closePanel\(\)/,
    `${variant}: Escape continues to dismiss the panel`);
  assert.match(qml, /WlrLayershell\.keyboardFocus:[^\n]*WlrKeyboardFocus\.Exclusive/,
    `${variant}: keyboard focus ownership remains unchanged`);
}
console.log("NordVPN presentation contract PASS (V1/V2, 300px, native radius, Escape/focus)");
