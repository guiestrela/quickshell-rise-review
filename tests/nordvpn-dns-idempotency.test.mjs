import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../versions/V1/modules/NordVpnController.qml', import.meta.url), 'utf8');
function method(name, next) {
  const start = source.indexOf(`function ${name}(`);
  return source.slice(start, source.indexOf(`\n    function ${next}(`, start)).trim();
}
function make(settings) {
  const calls = [];
  const state = { canMutate: true, cli: '/fixture/nordvpn', vpnSettings: settings,
    vpnMessage: 'old error', vpnActionMessage: 'old error',
    _runAction: argv => { calls.push([...argv]); return true; } };
  return { calls, state,
    set: vm.runInNewContext(`(${method('setDnsServers', 'resetDnsServers')})`, state),
    reset: vm.runInNewContext(`(${method('resetDnsServers', 'setVpnSetting')})`, state) };
}

test('Applying the existing DNS is a successful no-op, not another CLI failure', () => {
  for (const [dns, input] of [['1.1.1.1', '1.1.1.1'], ['1.1.1.1, 8.8.8.8', '8.8.8.8 1.1.1.1']]) {
    const c = make({ dns });
    assert.equal(c.set(input), true);
    assert.deepEqual(c.calls, []);
    assert.equal(c.state.vpnMessage, '');
    assert.match(c.state.vpnActionMessage, /already/i);
    assert.doesNotMatch(c.state.vpnActionMessage, /failed/i);
  }
});

test('Reset of already disabled DNS is a successful no-op', () => {
  for (const dns of ['disabled', 'off', 'default', 'Disabled']) {
    const c = make({ dns });
    assert.equal(c.reset(), true);
    assert.deepEqual(c.calls, []);
    assert.equal(c.state.vpnMessage, '');
    assert.match(c.state.vpnActionMessage, /already/i);
  }
});

test('Different or unknown DNS uses exact argv; resetting active DNS reaches the CLI', () => {
  for (const dns of ['8.8.8.8', '', 'disabled']) {
    const c = make({ dns });
    assert.equal(c.set('1.1.1.1, 1.0.0.1'), true);
    assert.deepEqual(c.calls, [['/fixture/nordvpn', 'set', 'dns', '1.1.1.1', '1.0.0.1']]);
  }
  const c = make({ dns: '1.1.1.1' });
  assert.equal(c.reset(), true);
  assert.deepEqual(c.calls, [['/fixture/nordvpn', 'set', 'dns', 'off']]);
});

test('Invalid DNS and unavailable controls never launch an action', () => {
  for (const input of ['', '1.1.1.256', '01.1.1.1', '::1', '1.1.1.1;bad', '1.1.1.1 2.2.2.2 3.3.3.3 4.4.4.4']) {
    const c = make({ dns: '1.1.1.1' });
    assert.equal(c.set(input), false);
    assert.deepEqual(c.calls, []);
  }
  const c = make({ dns: '1.1.1.1' }); c.state.canMutate = false;
  assert.equal(c.set('1.1.1.1'), false); assert.equal(c.reset(), false);
  assert.deepEqual(c.calls, []);
});
