import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
for (const variant of ['', 'variants/V2/']) {
  const read = name => readFileSync(new URL(`../versions/V1/${variant}${name}`, import.meta.url), 'utf8');
  const bar = read('BarSlot.qml');
  const visibility = vm.runInNewContext(`(function(gid, stage) {${bar.match(/function groupVisibleAtStage\(gid, stage\) \{([\s\S]*?)\n        \}/)[1]}
})`);
  for (let stage = 0; stage <= 3; stage++) assert.equal(visibility('G9', stage), true);
  const widget = read('modules/MprisWidget.qml');
  const first = {}, second = {};
  const root = { mprisVisible: false, activePopupScreen: first, activatePopupScreen(screen) { this.activePopupScreen = screen; } };
  const context = vm.createContext({ root, screen: first });
  vm.runInContext(`function togglePanel() {${widget.match(/function togglePanel\(\) \{([\s\S]*?)\n    \}/)[1]}}`, context);
  vm.runInContext('togglePanel()', context);
  assert.equal(root.mprisVisible, true);
  context.screen = second;
  vm.runInContext('togglePanel()', context);
  assert.equal(root.activePopupScreen, second);
  assert.equal(root.mprisVisible, true);
  vm.runInContext('togglePanel()', context);
  assert.equal(root.mprisVisible, false);
  assert.match(bar, /MprisWidget\s*\{\s*root: barSlot.root[;\s]+screen: barSlot.screen/);
}
console.log('MPRIS multi-monitor regression passed (V1/V2)');
