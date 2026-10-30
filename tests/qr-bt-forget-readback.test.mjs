import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

for (const variant of ['versions/V1', 'versions/V1/variants/V2']) {
  test(`${variant}: partial default-adapter listing cannot override paired native device`, () => {
    const source = readFileSync(new URL(`../${variant}/panels/BluetoothPanel.qml`, import.meta.url), 'utf8');
    const marker = 'if (btPanel.forgetReadbackPending && btPanel.forgetTarget)';
    const start = source.indexOf(marker);
    assert.ok(start >= 0);
    const open = source.indexOf('{', start);
    let depth = 0, end = -1;
    for (let i = open; i < source.length; i++) {
      if (source[i] === '{') depth++;
      if (source[i] === '}' && --depth === 0) {end = i + 1; break;}
    }
    assert.ok(end > open);
    const block = source.slice(start, end);
    const target = {mac: '12:34:56:78:9A:BC', adapterId: 'hci1', dbusPath: '/org/bluez/hci1/dev_12_34_56_78_9A_BC'};
    function run(rows, live) {
      const panel = {forgetReadbackPending: true, forgetTarget: {...target}, forgetError: '', forgetNotice: ''};
      vm.runInNewContext(block, {btPanel: panel, devs: rows, nativeDevices: live});
      return panel;
    }
    const native = {...target, paired: true, adapter: {adapterId: 'hci1'}};
    const partial = run([], [native]);
    assert.equal(partial.forgetReadbackPending, false);
    assert.notEqual(partial.forgetTarget, null, 'keep confirmation when selected native device remains paired');
    assert.notEqual(partial.forgetError, '');
    assert.equal(partial.forgetNotice, '', 'do not claim removal from absence in default adapter list');
    const success = run([], [{...native, paired: false}]);
    assert.equal(success.forgetTarget, null);
    assert.notEqual(success.forgetNotice, '');
    const rowStillPaired = run([{...target, paired: true}], []);
    assert.notEqual(rowStillPaired.forgetTarget, null);
    assert.notEqual(rowStillPaired.forgetError, '');
    const anotherAdapter = run([], [{...native, dbusPath: '/org/bluez/hci0/dev_12_34_56_78_9A_BC', adapter: {adapterId: 'hci0'}}]);
    assert.equal(anotherAdapter.forgetTarget, null, 'a different adapter must not be mistaken for the selected device');
  });
}
