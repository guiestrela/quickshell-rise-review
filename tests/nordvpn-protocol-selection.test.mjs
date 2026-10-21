import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import vm from 'node:vm';

const adapter = new URL('../versions/V1/modules/NordVpnProtocol.js', import.meta.url);
function normalize(settings) {
  assert.ok(existsSync(adapter), 'NordVPN protocol adapter must exist');
  const context = vm.createContext({});
  vm.runInContext(readFileSync(adapter, 'utf8').replace(/^\.pragma library\s*/, ''), context);
  return JSON.parse(JSON.stringify(context.normalizeSettings(settings)));
}
function action(settings) {
  const source = readFileSync(new URL('../versions/V1/modules/NordVpnController.qml', import.meta.url), 'utf8');
  const start = source.indexOf('function setVpnSetting(');
  const end = source.indexOf('\n    function _runAction(', start);
  const calls = [];
  const context = { canMutate: true, cli: '/fixture/nordvpn', vpnSettings: settings,
    vpnMessage: '', vpnActionMessage: '', _runAction: argv => { calls.push([...argv]); return true; } };
  return { context, calls, set: vm.runInNewContext(`(${source.slice(start, end).trim()})`, context) };
}

test('legacy Technology and OpenVPN transport remain unchanged', () => {
  const input = { technology: 'NordLynx', protocol: 'UDP', dns: 'disabled' };
  assert.deepEqual(normalize(input), input);
});

test('NordVPN 6 unified protocol supplies the technology and only its real OpenVPN transport', () => {
  for (const [raw, technology, protocol] of [
    ['NordLynx', 'NORDLYNX', ''], ['nordwhisper', 'NORDWHISPER', ''],
    ['openvpn_udp', 'OPENVPN', 'UDP'], ['OpenVPN TCP', 'OPENVPN', 'TCP'],
    ['VPN_PROTOCOL_OPENVPN_TCP', 'OPENVPN', 'TCP'],
  ]) {
    const result = normalize({ protocol: raw, firewall: 'enabled' });
    assert.equal(result.technology, technology);
    assert.equal(result.protocol, protocol);
    assert.equal(result['protocol-api'], 'unified');
    assert.equal(result.firewall, 'enabled');
    assert.equal(result['selection-notice'], '');
  }
});

test('mixed-version unspecified protocol never invents a current selection or permits a write', () => {
  const result = normalize({ protocol: 'VPN_PROTOCOL_UNSPECIFIED', routing: 'enabled' });
  assert.equal(result.technology, ''); assert.equal(result.protocol, '');
  assert.match(result['selection-notice'], /restart/i);
  for (const [key, value] of [['technology', 'NORDLYNX'], ['protocol', 'UDP']]) {
    const c = action(result);
    assert.equal(c.set(key, value), false);
    assert.deepEqual(c.calls, []);
    assert.match(c.context.vpnMessage, /restart/i);
  }
});

test('technology and transport choices use NordVPN 6 commands, never removed set technology', () => {
  for (const [key, value, current, expected] of [
    ['technology', 'NORDLYNX', 'openvpn_tcp', 'nordlynx'],
    ['technology', 'NORDWHISPER', 'nordlynx', 'nordwhisper'],
    ['technology', 'OPENVPN', 'openvpn_tcp', 'openvpn_tcp'],
    ['technology', 'OPENVPN', 'nordlynx', 'openvpn_udp'],
    ['protocol', 'TCP', 'openvpn_udp', 'openvpn_tcp'],
    ['protocol', 'UDP', 'openvpn_tcp', 'openvpn_udp'],
  ]) {
    const c = action(normalize({ protocol: current }));
    assert.equal(c.set(key, value), true);
    assert.deepEqual(c.calls, [['/fixture/nordvpn', 'set', 'protocol', expected]]);
  }
});

test('read-only daemon fallback restores confirmed selection without allowing incompatible writes', () => {
  const context = vm.createContext({});
  vm.runInContext(readFileSync(adapter, 'utf8'), context);
  assert.equal(typeof context.applyDaemonSelection, 'function', 'daemon readback adapter must exist');
  const unknown = normalize({ protocol: 'VPN_PROTOCOL_UNSPECIFIED' });
  const result = JSON.parse(JSON.stringify(context.applyDaemonSelection(unknown, { schema: 1, technology: 'NORDLYNX', protocol: 'UDP' })));
  assert.equal(result.technology, 'NORDLYNX'); assert.equal(result.protocol, 'UDP');
  assert.equal(result['selection-notice'], '');
  assert.equal(result['selection-source'], 'daemon-rpc');
  assert.match(result['selection-write-notice'], /restart/i);
  for (const [key, value] of [['technology', 'OPENVPN'], ['protocol', 'TCP']]) {
    const c = action(result); assert.equal(c.set(key, value), false); assert.deepEqual(c.calls, []);
    assert.equal(c.context.vpnActionMessage, 'Protocol unchanged: writes blocked by CLI/daemon version mismatch');
    assert.doesNotMatch(c.context.vpnActionMessage, /selection unavailable/i);
  }
  assert.equal(unknown.technology, '', 'do not mutate the original snapshot');
});

test('daemon fallback rejects malformed replies and never overrides a native known selection', () => {
  const context = vm.createContext({}); vm.runInContext(readFileSync(adapter, 'utf8'), context);
  assert.equal(typeof context.applyDaemonSelection, 'function');
  const unknown = normalize({ protocol: 'VPN_PROTOCOL_UNSPECIFIED' });
  for (const reply of [null, {}, {schema:2,technology:'NORDLYNX',protocol:'UDP'}, {schema:1,technology:'INVALID',protocol:'UDP'}, {schema:1,technology:'OPENVPN',protocol:''}]) {
    const result = JSON.parse(JSON.stringify(context.applyDaemonSelection(unknown, reply)));
    assert.equal(result.technology, ''); assert.notEqual(result['selection-notice'], '');
  }
  const native = normalize({ protocol: 'openvpn_tcp' });
  assert.deepEqual(JSON.parse(JSON.stringify(context.applyDaemonSelection(native, {schema:1,technology:'NORDLYNX',protocol:'UDP'}))), native);
});

test('legacy actions keep old argv and invalid values are still rejected', () => {
  const c = action({ technology: 'NordLynx', protocol: 'UDP' });
  assert.equal(c.set('technology', 'OPENVPN'), true);
  assert.equal(c.set('protocol', 'TCP'), true);
  assert.deepEqual(c.calls, [['/fixture/nordvpn', 'set', 'technology', 'OPENVPN'], ['/fixture/nordvpn', 'set', 'protocol', 'TCP']]);
  assert.equal(c.set('technology', 'invalid'), false);
  assert.equal(c.set('protocol', 'invalid'), false);
  assert.equal(c.calls.length, 2);
});
