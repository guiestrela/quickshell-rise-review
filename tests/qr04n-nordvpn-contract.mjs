import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const project = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const read = (path) => readFileSync(resolve(project, path), "utf8");

const variants = process.argv.includes("--v1") ? [""] : ["", "variants/V2/"];
for (const variant of variants) {
  const prefix = `versions/V1/${variant}`;
  const nordVpnGid = variant ? "G19" : "G16";
  const slot = read(`${prefix}BarSlot.qml`);
  const controls = read(`${prefix}panels/ControlPanel.qml`);
  const network = read(`${prefix}modules/NetworkWidget.qml`);
  const panel = read(`${prefix}panels/NetworkPanel.qml`);
  const theme = read(`${prefix}Theme.qml`);
  const widgetPath = `${prefix}modules/NordVPNWidget.qml`;

  assert.ok(existsSync(resolve(project, widgetPath)), `${prefix} independent NordVPN widget is missing`);
  const widget = read(widgetPath);
  assert.ok(slot.includes(`"${nordVpnGid}": compNordVpn`), `${prefix}BarSlot must map ${nordVpnGid} to a dedicated component`);
  const expectedToggle = variant
    ? controls.includes(`gid: "${nordVpnGid}"`) && controls.includes('label: "NordVPN"')
    : controls.includes('label: "NordVPN"') && controls.includes('active: root.modNordVpn');
  assert.ok(expectedToggle, `${prefix} WIDGETS must independently toggle ${nordVpnGid}`);
  assert.ok(slot.includes("NordVpnLayout.swapModels"), `${prefix} drag must use tested slot swap logic`);
  assert.ok(slot.includes(variant ? "migrateV2Entries" : "migrateV1Order"), `${prefix} must migrate persisted layouts`);
  assert.ok(widget.includes("nordVpnStatus"), `${prefix} widget must render shared status`);
  assert.ok(widget.includes("vpnVisible = true"), `${prefix} widget click must open the independent Rise VPN panel`);
  assert.ok(theme.includes("property bool vpnVisible"), `${prefix} must own independent VPN panel visibility`);
  assert.ok(!panel.includes("vpnStatusProc") && !panel.includes("refreshVpn"), `${prefix} NetworkPanel must not own VPN polling`);
  assert.ok(!panel.includes("NordVPN"), `${prefix} NetworkPanel must not contain VPN UI`);
  assert.ok(existsSync(resolve(project, `${prefix}panels/NordVPNPanel.qml`)), `${prefix} independent VPN panel is missing`);
  const variantRoot = read(`${prefix}VariantRoot.qml`);
  assert.ok(variantRoot.includes("NordVPNPanel"), `${prefix} VariantRoot must instantiate the VPN panel`);
  assert.ok(!network.includes('command: ["nordvpn", "status"]'), `${prefix} NetworkWidget must not spawn a duplicate VPN poller`);
  assert.ok(theme.includes("property bool modNordVpn"), `${prefix} visibility needs a persisted theme setting`);
  const vpnPanel = read(`${prefix}panels/NordVPNPanel.qml`);
  const vpnPanelImplementation = variant && vpnPanel.includes("Shared.NordVPNPanel")
    ? read("versions/V1/panels/NordVPNPanel.qml") : vpnPanel;
  assert.ok(vpnPanelImplementation.includes("connectVpnCountry") && vpnPanelImplementation.includes("pauseVpn") && vpnPanelImplementation.includes("setVpnSetting"), `${prefix} independent VPN panel must preserve real VPN controls`);
  assert.ok(vpnPanelImplementation.includes("auto-connect") && vpnPanelImplementation.includes("technology"), `${prefix} independent VPN panel must preserve auto-connect and technology controls`);
  if (!variant) {
    const controller = read("versions/V1/modules/NordVpnController.qml");
    const variantRoot = read("versions/V1/VariantRoot.qml");
    assert.ok(controller.includes('"connect"') && controller.includes('"disconnect"') && controller.includes('"pause"'), "V1 controller must own fixed-argv actions");
    assert.ok(controller.includes('"set", "protocol"') === false, "V1 unsupported protocol must not be implemented as CLI argv");
    assert.ok(theme.includes("readonly property string vpnState:") && theme.includes("readonly property bool vpnBusy:"), "Theme must expose shared controller state");
    assert.equal((theme.match(/NordVpnController\s*\{/g) || []).length, 1, "Theme must instantiate exactly one controller per root, not per monitor");
    assert.ok(widget.includes('setPanelAnchor("vpn"') && theme.includes('else if (name === "vpn") vpnBarX = x'), "VPN panel must own its bar anchor");
    assert.ok(vpnPanel.includes("root.vpnBarX") && !vpnPanel.includes("root.networkBarX"), "VPN panel must not depend on the Network anchor");
    assert.ok(variantRoot.includes("NetworkPanel { root: theme }") && variantRoot.includes("NordVPNPanel { root: theme; controller: theme }"), "VariantRoot must wire both actual panels to the shared owner");
    const popupClose = theme.match(/function closePopups\(except\) \{([\s\S]*?)\n    \}/)?.[1] || "";
    assert.ok(popupClose.includes('except !== "networkVisible"') && popupClose.includes('except !== "vpnVisible"'), "network and VPN must participate independently in popup exclusivity");
    assert.ok(theme.includes("|| networkVisible || vpnVisible") || theme.includes("|| vpnVisible ||"), "both panels must count as active popups");
    assert.ok(panel.includes('root.networkVisible ? 1 : 0') && panel.includes("nmAdapterReady") && panel.includes("wifi"), "NetworkPanel must retain its independent Wi-Fi/Ethernet surface");
    assert.ok(!panel.includes("vpnVisible") && !panel.includes("NordVPN"), "opening Network must not own or show NordVPN");
  }
}
console.log("QR04N independent widget contract PASS");
