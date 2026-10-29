import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync('versions/V1/modules/NordVpnController.qml', 'utf8');
const method = source.slice(source.indexOf('    function setAutoConnect('), source.indexOf('    function connectVpn('));
function fixture(overrides = {}) {
  const calls = [];
  const state = { canMutate: true, countriesState: 'Ready', countryOptions: ['United_States', 'Brazil'], cli: 'nordvpn',
    _runAction: argv => { calls.push([...argv]); return true; }, ...overrides };
  return { calls, set: vm.runInNewContext(`(${method.trim()})`, state) };
}

test('Auto-connect enables with a country or default target and disables without country lookup', () => {
  const c = fixture();
  assert.equal(c.set(true, 'United_States'), true);
  assert.deepEqual(c.calls, [['nordvpn', 'set', 'autoconnect', 'enabled', 'United_States']]);
  const unavailable = fixture({ countriesState: 'Unavailable', countryOptions: [] });
  assert.equal(unavailable.set(false, 'Brazil'), true);
  assert.equal(unavailable.set(true, ''), true);
  assert.deepEqual(unavailable.calls, [['nordvpn', 'set', 'autoconnect', 'disabled'], ['nordvpn', 'set', 'autoconnect', 'enabled']]);
});

test('Invalid country and busy controller cannot change auto-connect', () => {
  const c = fixture();
  assert.equal(c.set(true, 'invalid'), false);
  assert.deepEqual(c.calls, []);
  assert.equal(fixture({ canMutate: false }).set(false, ''), false);
});

test('Both panels apply the toggle directly and omit the unsupported virtual-location setting', () => {
  for (const path of ['versions/V1/panels/NordVPNPanel.qml', 'versions/V1/variants/V2/panels/NordVPNPanel.qml']) {
    const panel = readFileSync(path, 'utf8');
    assert.match(panel, /onClicked: controller.setAutoConnect\(!vpnPanel.autoConnectEnabled, vpnPanel.autoCountryTarget\)/);
    assert.doesNotMatch(panel, /autoConnectEnabled = !/);
    assert.doesNotMatch(panel, /virtual-location/);
  }
  assert.doesNotMatch(source, /"virtual-location"/);
});


test('Global connect uses the persisted country, falling back to the auto-connect country before quick connect', () => {
  const method = source.slice(source.indexOf('    function connectVpn('), source.indexOf('    function disconnectVpn(')).trim();
  for (const [country, auto, settings, expected] of [
    ['United_States', '', {}, 'United_States'],
    ['', 'United_States', {'auto-connect': 'enabled'}, 'United_States'],
    ['Paraguay', 'United_States', {'auto-connect': 'enabled'}, 'Paraguay'],
    ['', 'United_States', {'auto-connect': 'disabled'}, 'quick'],
  ]) {
    const calls = [];
    const state = { canMutate: true, preferredCountry: country, preferredAutoCountry: auto, vpnSettings: settings, cli: 'nordvpn',
      connectVpnCountry: value => { calls.push(value); return true; },
      _runAction: () => { calls.push('quick'); return true; } };
    assert.equal(vm.runInNewContext(`(${method})`, state)(), true);
    assert.deepEqual(calls, [expected]);
  }
});
