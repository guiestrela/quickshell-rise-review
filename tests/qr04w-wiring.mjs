import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';

const base = path.resolve('versions/V1');
const variants = [
  { dir: base, gid: 'G17', field: 34 },
  { dir: path.join(base, 'variants/V2'), gid: 'G20', field: 46 },
];
for (const { dir, gid, field } of variants) {
  const variant = gid === 'G17' ? 'V1' : 'V2';
  test(`${variant}: Wallpapers tile toggles persisted real slot`, () => {
    const theme = fs.readFileSync(path.join(dir, 'Theme.qml'), 'utf8');
    const slot = fs.readFileSync(path.join(dir, 'BarSlot.qml'), 'utf8');
    const panel = fs.readFileSync(path.join(dir, 'panels/ControlPanel.qml'), 'utf8');
    assert.match(theme, /property bool modWallpapers:\s*false/);
    assert.match(theme, /onModWallpapersChanged:\s*if \(_widgetsLoaded\) saveWidgets\(\)/);
    assert.match(theme, new RegExp(`parts\\[wsField \\+ ${field}\\].*modWallpapers|modWallpapers.*parts\\[wsField \\+ ${field}\\]`));
    assert.match(theme, /\+ \(modWallpapers\s*\? "1" : "0"\)/);
    assert.match(slot, /Component\s*\{\s*id: compWallpapers;?\s*WallpaperWidget\s*\{/);
    assert.match(slot, new RegExp(`"${gid}": compWallpapers`));
    assert.match(slot, new RegExp(`gid: "${gid}"`));
    assert.match(panel, /label: "Wallpapers";[^\n]*root\.modWallpapers[^\n]*on(?:VisibilityToggled|Activated): root\.modWallpapers = !root\.modWallpapers/);
  });
}

test('legacy layouts gain independent wallpaper IDs without dropping entries', () => {
  const source = fs.readFileSync(path.join(base, 'modules/WallpaperLayout.js'), 'utf8');
  const api = vm.createContext({}); vm.runInContext(source, api);
  const left = Array.from({ length: 7 }, (_, i) => `G${i + 1}`);
  const center = ['G8'];
  const right = [9,10,11,14,12,13,15,16].map(n => `G${n}`);
  const v1 = api.migrateV1Order(left, center, right);
  assert.equal(v1.right.at(-1), 'G17');
  assert.equal(right.length, 8);
  assert.equal(api.migrateV1Order(v1.left, v1.center, v1.right).right.length, 9);
  const oldV2 = Array.from({ length: 19 }, (_, i) => ({ gid: `G${i + 1}`, extra: i > 14 }));
  const v2 = api.migrateV2Entries(oldV2.slice(0, 7), oldV2.slice(7, 8), [...oldV2.slice(8), { gid: '', extra: true }]);
  assert.equal(v2.right.at(-1).gid, 'G20');
  assert.equal(api.migrateV2Entries(v2.left, v2.center, v2.right).right.at(-1).gid, 'G20');
  const nordvpn = vm.createContext({});
  vm.runInContext(fs.readFileSync(path.join(base, 'modules/NordVpnLayout.js'), 'utf8'), nordvpn);
  const currentV2 = nordvpn.migrateV2Entries(v2.left, v2.center, v2.right);
  assert.ok(currentV2, 'NordVPN migration must accept cache with Wallpapers G20');
  assert.equal(currentV2.right.at(-1).gid, 'G20');
  assert.equal(api.migrateV1Order(['G1'], ['G8'], ['G9']), null);
});
