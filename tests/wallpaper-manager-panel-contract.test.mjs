import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const project = dirname(dirname(fileURLToPath(import.meta.url)));
const panel = readFileSync(join(project, 'versions/V1/panels/WallpaperManagerQuickPanel.qml'), 'utf8');

test('isolated wallpaper manager panel exposes Displays and Shuffling tabs', () => {
  assert.match(panel, /PanelWindow\s*\{/);
  assert.match(panel, /\{key:\s*"displays",\s*label:\s*"Displays"\}/);
  assert.match(panel, /\{key:\s*"shuffling",\s*label:\s*"Shuffling"\}/);
  assert.match(panel, /wallpaperManagerTab\s*===\s*"displays"/);
  assert.match(panel, /wallpaperManagerTab\s*===\s*"shuffling"/);
});

test('panel closes through root state and offers profile controls without owning renderer', () => {
  assert.match(panel, /wallpaperManagerVisible\s*=\s*false/);
  assert.match(panel, /setWallpaperPerDisplay\(/);
  assert.match(panel, /setWallpaperProfile\(\{mode:\s*modelData\.key\}\)/);
  assert.match(panel, /setWallpaperProfile\(\{scaling:\s*modelData\.key\}\)/);
  assert.match(panel, /shuffleWallpapers\(\)/);
  assert.match(panel, /wallpaperManagerServiceApi\.scanFolder\(\)/);
  assert.match(panel, /Rise controls the wallpaper renderer/);
  assert.doesNotMatch(panel, /WlrLayer\.Background|omarchy-theme-bg-set/);
});
