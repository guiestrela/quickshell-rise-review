import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const panel = readFileSync(new URL('../versions/V1/variants/V2/panels/ControlPanel.qml', import.meta.url), 'utf8');
const theme = readFileSync(new URL('../versions/V1/variants/V2/Theme.qml', import.meta.url), 'utf8');
function body(marker) {
  let i = theme.indexOf(marker);
  assert.ok(i >= 0, marker);
  const start = theme.indexOf('{', i);
  let end = start + 1, depth = 1;
  while (depth) {
    if (theme[end] === '{') depth++;
    if (theme[end] === '}') depth--;
    assert.ok(end < theme.length, 'balanced function');
    end++;
  }
  return theme.slice(start + 1, end - 1);
}

test('V2 NordVPN exposes the native Full/Icon control on G19', () => {
  const tile = panel.split('\n').find(line => line.includes('WidgetStateTile') && line.includes('gid: "G19"'));
  assert.ok(tile, 'NordVPN tile exists');
  assert.match(tile, /supportsCompact:\s*true/, 'Full/Icon selector must be enabled');
  assert.match(tile, /compact:\s*root\.iconOnly\("G19"\)/);
  assert.match(tile, /onModeToggled:\s*root\.toggleIconOnly\("G19"\)/);
});

test('existing V2 mode functions toggle and persist only G19 without altering other groups', () => {
  let saves = 0;
  const ctx = { iconOnlyGids: ['G7'], _widgetsLoaded: true, saveWidgets() { saves++; }, gid: 'G19' };
  vm.createContext(ctx);
  vm.runInContext(`(function(){${body('function toggleIconOnly(gid)')}})()`, ctx);
  assert.equal(vm.runInContext(`(function(){${body('function iconOnly(gid)')}})()`, ctx), true);
  assert.deepEqual(Array.from(ctx.iconOnlyGids), ['G7', 'G19']);
  const readback = vm.runInNewContext(`(function(s){${body('function parseGidCsv(s)')}})(${JSON.stringify(ctx.iconOnlyGids.join(','))})`);
  assert.deepEqual(Array.from(readback), ['G7', 'G19']);
  vm.runInContext(`(function(){${body('function toggleIconOnly(gid)')}})()`, ctx);
  assert.deepEqual(Array.from(ctx.iconOnlyGids), ['G7']);
  assert.equal(saves, 2);
});
