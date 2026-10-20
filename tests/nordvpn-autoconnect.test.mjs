import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

for (const variant of ['', 'variants/V2/']) {
  const source = readFileSync(new URL(`../versions/V1/${variant}panels/NordVPNPanel.qml`, import.meta.url), 'utf8');
  const body = source.match(/function toggleAutoConnect\(\) \{([\s\S]*?)\n    \}/)[1];
  const calls = [];
  const state = {
    autoConnectEnabled: false,
    autoCountryTarget: 'Brazil',
    controller: { setAutoConnect: (...args) => { calls.push(args); return true; } },
  };
  vm.runInNewContext(`function toggleAutoConnect() {${body}}; toggleAutoConnect()`, state);
  assert.deepEqual(calls.shift(), [true, 'Brazil']);
  assert.equal(state.autoConnectEnabled, false, 'display must wait for daemon confirmation');
  state.autoConnectEnabled = true;
  vm.runInNewContext('toggleAutoConnect()', state);
  assert.deepEqual(calls.shift(), [false, 'Brazil']);
  assert.match(source, /onClicked: vpnPanel\.toggleAutoConnect\(\)/);
  assert.doesNotMatch(source, /vpnPanel\.autoConnectEnabled\s*=/, 'click must preserve settings binding across refreshes');
}
console.log('Auto-connect persistence regression passed (V1 and V2)');
