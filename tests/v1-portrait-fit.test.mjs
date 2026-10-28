import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync('versions/V1/BarSlot.qml', 'utf8');
const expression = name => source.match(new RegExp(`readonly property real ${name}: ([^\\n]+)`))[1];
const visibility = source.match(/function groupVisibleAtStage\(gid, stage\) \{([\s\S]*?)\n        \}/)[1];

test('portrait fit keeps every group visible and the whole strip inside each output', () => {
  for (const output of [720, 1080, 1440, 2560]) {
    const context = vm.createContext({barSlot: {width: output}, completeWidth: 2100, Math});
    const available = vm.runInContext(expression('availableWidth'), context);
    context.availableWidth = available;
    const scale = vm.runInContext(expression('fitScale'), context);
    assert.ok(scale > 0 && scale <= 1);
    assert.ok(2100 * scale <= available + 0.001);
    assert.equal(scale, output >= 2110 ? 1 : available / 2100);
    for (let group = 1; group <= 19; group++) {
      context.gid = `G${group}`;
      for (let stage = 0; stage <= 3; stage++) {
        context.stage = stage;
        assert.equal(vm.runInContext(`(function(){${visibility}})()`, context), true);
      }
    }
  }
});

test('panel anchors use transformed screen coordinates', () => {
  assert.match(source, /return it\.mapToItem\(null, it\.width \* frac, 0\)\.x/);
});

test('split mode budgets every separator and split-all covers every widget gap', () => {
  const body = source.match(/function sideNaturalWidth\(row, stage\) \{([\s\S]*?)\n        \}/)[1];
  for (const split of [false, true]) {
    const slots = Array.from({length: 10}, () => ({gid: 'G1', hasContent: true, budgetSlotWidth: 80 + (split ? 16 : 0)}));
    const row = {rep: {count: slots.length, itemAt: i => slots[i]}, spacing: 6};
    const width = vm.runInNewContext(`(function(row, stage){${body}})(row, 0)`, {
      row, groupVisibleAtStage: () => true, Math
    });
    assert.equal(width, 800 + 54 + (split ? 160 : 0));
  }
  assert.match(source, /leftSplits\s*= Array\(leftModel.count - 1\)\.fill\(true\)/);
  assert.match(source, /rightSplits\s*= Array\(rightModel.count - 1\)\.fill\(true\)/);
});
