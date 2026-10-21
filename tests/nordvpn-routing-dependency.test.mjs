import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../versions/V1/modules/NordVpnController.qml', import.meta.url), 'utf8');
const start = source.indexOf('function setVpnSetting(');
const end = source.indexOf('\n    function _runAction(', start);
const setSetting = source.slice(start, end).trim();
function controller(settings) {
  const calls = [];
  const context = { canMutate: true, cli: '/test-only/nordvpn', vpnSettings: settings,
    vpnMessage: '', vpnActionMessage: '', _runAction: argv => { calls.push([...argv]); return true; } };
  return { context, calls, set: vm.runInNewContext(`(${setSetting})`, context) };
}

test('Routing OFF is refused with an explicit Meshnet dependency, without CLI side effects', () => {
  for (const enabled of ['enabled', 'on', 'yes', 'true', 'ENABLED']) {
    const c = controller({ routing: 'enabled', meshnet: enabled });
    assert.equal(c.set('routing'), false);
    assert.equal(c.calls.length, 0, 'do not issue an action the daemon will reject');
    assert.match(c.context.vpnMessage, /Meshnet/);
    assert.doesNotMatch(c.context.vpnActionMessage, /completed/i);
  }
});

test('Routing ON remains available with Meshnet enabled; OFF remains available with Meshnet disabled', () => {
  for (const [routing, meshnet, value] of [['disabled', 'enabled', 'on'], ['enabled', 'disabled', 'off']]) {
    const c = controller({ routing, meshnet });
    assert.equal(c.set('routing'), true);
    assert.deepEqual(c.calls, [['/test-only/nordvpn', 'set', 'routing', value]]);
  }
});

test('Post-quantum ON explains the Meshnet conflict without changing VPN settings', () => {
  for (const meshnet of ['enabled', 'on', 'yes', 'true', 'ENABLED']) {
    const c = controller({ 'post-quantum-vpn': 'disabled', meshnet, technology: 'NORDLYNX' });
    assert.equal(c.set('post-quantum-vpn'), false);
    assert.equal(c.calls.length, 0, 'do not silently disable Meshnet or reconnect');
    assert.match(c.context.vpnMessage, /Meshnet/);
    assert.doesNotMatch(c.context.vpnActionMessage, /completed/i);
  }
});

test('Post-quantum ON requires NordLynx and does not switch technology silently', () => {
  for (const technology of ['OPENVPN', 'NORDWHISPER', '']) {
    const c = controller({ 'post-quantum-vpn': 'disabled', meshnet: 'disabled', technology });
    assert.equal(c.set('post-quantum-vpn'), false);
    assert.equal(c.calls.length, 0);
    assert.match(c.context.vpnMessage, /NordLynx/);
  }
});

test('Compatible Post-quantum ON and disabling Post-quantum use the correct CLI argv', () => {
  for (const [state, meshnet, expected] of [['disabled', 'disabled', 'on'], ['enabled', 'enabled', 'off']]) {
    const c = controller({ 'post-quantum-vpn': state, meshnet, technology: 'NordLynx' });
    assert.equal(c.set('post-quantum-vpn'), true);
    assert.deepEqual(c.calls, [['/test-only/nordvpn', 'set', 'post-quantum', expected]]);
  }
});

test('Unavailable controller does not mutate Routing', () => {
  const c = controller({ routing: 'enabled', meshnet: 'disabled' });
  c.context.canMutate = false;
  assert.equal(c.set('routing'), false);
  assert.equal(c.calls.length, 0);
});
