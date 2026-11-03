import { readQmlSource } from './qml-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const project = dirname(dirname(fileURLToPath(import.meta.url)));
for (const [variant, relative] of [
  ['V1', 'variants/V1/panels/WallpaperManagerQuickPanel.qml'],
  ['V2', 'variants/V2/panels/WallpaperManagerQuickPanel.qml'],
]) {
  const panel = readQmlSource(join(project, relative), 'utf8');
  test(`${variant}: wallpaper panel exposes Displays and Shuffling tabs`, () => {
    assert.match(panel, /PanelWindow\s*\{/);
    assert.match(panel, /\{key:\s*"displays",\s*label:\s*"Displays"\}/);
    assert.match(panel, /\{key:\s*"shuffling",\s*label:\s*"Shuffling"\}/);
    assert.match(panel, /wallpaperManagerTab\s*===\s*"displays"/);
    assert.match(panel, /wallpaperManagerTab\s*===\s*"shuffling"/);
  });
  test(`${variant}: scaling buttons save and select the advertised scale`, () => {
    const marker = panel.indexOf('objectName: "wallpaper-scale-"');
    assert.notEqual(marker, -1);
    const start = panel.lastIndexOf('delegate: RiseButton {', marker);
    const delegate = panel.slice(start, panel.indexOf('\n                            }', marker));
    const handler = delegate.match(/onActivated:\s*([^\n]+)/)?.[1];
    const selected = delegate.match(/selected:\s*([^\n]+)/)?.[1];
    assert.ok(handler && selected, 'scale delegate needs a click and selected binding');
    for (const key of ['zoom', 'actual', 'fitHeight', 'fitWidth']) {
      const calls = [];
      const context = { modelData: { key }, panel: { profile: { scaling: key }, root: {
        setWallpaperProfile: patch => calls.push(JSON.parse(JSON.stringify(patch))),
      } } };
      // Evaluate derived keys too: this catches labels wired to another scale.
      const derived = delegate.match(/readonly property string scalingKey:\s*([^\n]+)/)?.[1];
      if (derived) context.scalingKey = vm.runInNewContext(derived, context);
      vm.runInNewContext(handler, context);
      assert.deepEqual(calls, [{ scaling: key }], `${key} must save itself, not another scale`);
      assert.equal(vm.runInNewContext(selected, context), true, `${key} must show selected`);
      context.panel.profile.scaling = key === 'zoom' ? 'actual' : 'zoom';
      assert.equal(vm.runInNewContext(selected, context), false, 'another scale must not select this button');
    }
  });
  test(`${variant}: panel delegates actions without owning the wallpaper renderer`, () => {
    assert.match(panel, /wallpaperManagerVisible\s*=\s*false/);
    assert.match(panel, /setWallpaperPerDisplay\(/);
    assert.match(panel, /setWallpaperProfile\(\{mode:\s*modelData\.key\}\)/);
    assert.match(panel, /wallpaperManagerServiceApi\.nextAll\(\)/);
    assert.match(panel, /wallpaperManagerServiceApi\.scanFolder\(panel\.root\.wallpaperManagerDisplay\)/);
    assert.match(panel, /wallpaperManagerServiceApi\.pathFor\(modelData\.name\)/);
    assert.doesNotMatch(panel, /WlrLayer\.Background|omarchy-theme-bg-set/);
  });
}

// Variant adapters must keep presentation only; controls have one production owner.
test('wallpaper variants share one control implementation', () => {
  for (const variant of ['V1', 'V2']) {
    const adapter = readFileSync(join(project, `variants/${variant}/panels/WallpaperManagerQuickPanel.qml`), 'utf8');
    assert.match(adapter, /Shared\.WallpaperManagerQuickPanel\s*\{/);
    assert.match(adapter, /surfaceComponent: Component/);
    assert.doesNotMatch(adapter, /component RiseButton|wallpaper-manager-title|wallpaper-scale-/);
  }
});

test('wallpaper connected surface stays behind the controls', () => {
  const adapter = readFileSync(join(project, 'variants/V2/panels/WallpaperManagerQuickPanel.qml'), 'utf8');
  assert.match(adapter, /Native\.ConnectedPanelSurface\s*\{\s*parent: panel\.surfaceHost\s*z: -1/);
});
