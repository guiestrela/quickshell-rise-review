import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const project = dirname(dirname(fileURLToPath(import.meta.url)));
for (const [variant, path] of [['V1', 'versions/V1/modules/WallpaperProfile.js'], ['V2', 'versions/V1/variants/V2/modules/WallpaperProfile.js']]) {
  test(`${variant}: updates retain scaling and recursion settings`, () => {
    const source = readFileSync(join(project, path), 'utf8').replace(/^\.pragma library\s*\n/, '');
    const context = vm.createContext({});
    vm.runInContext(source, context, { filename: path });
    const api = context;
    const original = { perDisplayConfig: true, displayConfig: { 'DP-1': { folder: '/wall', recursive: false, mode: 'single', scaling: 'fitWidth' } } };
    const updated = api.updateDisplay(original, 'DP-1', { mode: 'shuffle' }, '/home/test');
    const config = api.configFor(updated, 'DP-1', '/home/test');
    assert.equal(config.folder, '/wall');
    assert.equal(config.recursive, false);
    assert.equal(config.mode, 'shuffle');
    assert.equal(config.scaling, 'fitWidth');
    const display = api.updateDisplay(updated, 'DP-1', { recursive: true, scaling: 'actual' }, '/home/test');
    const displayConfig = api.configFor(display, 'DP-1', '/home/test');
    assert.equal(displayConfig.recursive, true);
    assert.equal(displayConfig.scaling, 'actual');
  });
}
