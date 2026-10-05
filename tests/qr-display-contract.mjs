import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import path from "node:path";

const repo = path.resolve(import.meta.dirname, "..");
const variants = [
  { id: "V1", dir: "versions/V1", panel: "versions/V1/panels/DisplayManagerPanel.qml", slot: "G18", tile: "Tile" },
  { id: "V2", dir: "versions/V1/variants/V2", panel: "versions/V1/panels/DisplayManagerPanel.qml", slot: "G21", tile: "WidgetStateTile" },
];
const read = (relative) => readFileSync(path.join(repo, relative), "utf8");
const controls = [
  "display-monitor-list", "display-resolution", "display-refresh",
  "display-mirror", "display-rotation", "display-scale",
  "display-brightness", "display-text-size", "display-workspaces", "display-save",
];
for (const variant of variants) {
  const prefix = variant.dir + "/";
  for (const relative of ["Theme.qml", "BarSlot.qml", "panels/ControlPanel.qml", "VariantRoot.qml",
                          "modules/DisplayManagerWidget.qml"]) {
    assert.ok(existsSync(path.join(repo, prefix, relative)), `${variant.id} missing ${relative}`);
  }
  const theme = read(prefix + "Theme.qml");
  const slot = read(prefix + "BarSlot.qml");
  const controlsPanel = read(prefix + "panels/ControlPanel.qml");
  const widget = read(prefix + "modules/DisplayManagerWidget.qml");
  const panel = read(variant.panel);
  if (variant.id === "V2") {
    const entry = read(prefix + "VariantRoot.qml");
    const wrapper = read(prefix + "panels/DisplayManagerPanel.qml");
    assert.ok(/(?<!\.)\bDisplayManagerPanel\s*\{/.test(entry) && wrapper.includes('import "../../../panels" as Shared') && wrapper.includes("Shared.DisplayManagerPanel"), "V2 native-style wrapper must retain the shared panel controls");
  }
  assert.match(theme, /onModDisplayManagerChanged:\s*if \(_widgetsLoaded\) saveWidgets\(\)/, `${variant.id} toggle persistence hook`);
  if (variant.id === "V2") assert.match(read(prefix+"modules/DisplayManagerController.qml"), /Shared\.DisplayManagerController/, "V2 shared controller wrapper must be resolved");
  assert.ok(theme.includes("keyboardPopupVisible: imagePickerVisible || mediaBrowserVisible || wallpaperManagerVisible || displayManagerVisible"), `${variant.id} keyboard popup focus contract`);
  assert.ok(theme.includes("onDisplayManagerAutoWorkspacesChanged"), `${variant.id} workspace preference persistence hook`);
  assert.match(theme, /property bool modDisplayManager\s*:\s*false/, `${variant.id} visibility setting`);
  assert.match(theme, /displayManagerVisible/, `${variant.id} popup lifecycle`);
  assert.match(theme, /modDisplayManager\s*\?\s*"1"\s*:\s*"0"/, `${variant.id} append-only persistence`);
  assert.match(theme, /modDisplayManager\s*=\s*parts\[[^\]]+\]\s*===\s*"1"/, `${variant.id} persistence load`);
  assert.ok(controlsPanel.includes("Display Manager") && controlsPanel.includes("modDisplayManager"), `${variant.id} WIDGETS toggle`);
  assert.ok(slot.includes(`"${variant.slot}"`) && slot.includes("DisplayManagerWidget"), `${variant.id} widget slot`);
  assert.ok(widget.includes("toggleDisplayManager") && widget.includes("modDisplayManager"), `${variant.id} widget handler`);
  for (const control of controls) assert.ok(panel.includes(control), `${variant.id} missing ${control}`);
  assert.ok(panel.includes("activePopupScreen") && panel.includes("WlrLayer.Overlay"), `${variant.id} Rise overlay contract`);
  assert.ok(panel.includes("displayManagerControllerApi"), `${variant.id} production controller wiring`);
  assert.ok(read(prefix + "VariantRoot.qml").includes("DisplayManagerPanel"), `${variant.id} panel instantiated`);
}
assert.ok(existsSync(path.join(repo, "versions/V1/modules/DisplayManagerController.qml")), "shared controller missing");
assert.ok(existsSync(path.join(repo, "scripts/rise-display-manager-apply")), "safe apply helper missing");
console.log("QR_DISPLAY_CONTRACT_PASS V1/V2");
