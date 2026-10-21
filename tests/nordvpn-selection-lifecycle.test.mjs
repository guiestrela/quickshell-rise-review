import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

// Exercise the actual QML handlers, with only Process/Qt scheduling replaced.
// No CLI, reader, socket, or VPN action is ever executed by this fixture.
const source = readFileSync(new URL('../versions/V1/modules/NordVpnController.qml', import.meta.url), 'utf8');
const adapter = readFileSync(new URL('../versions/V1/modules/NordVpnProtocol.js', import.meta.url), 'utf8');
const reply = JSON.stringify({ schema: 1, technology: 'NORDLYNX', protocol: 'UDP' });
function fixture() {
  const later = [];
  let running = false;
  let launches = 0;
  const probe = { command: [], get running() { return running; }, set running(value) {
    if (value) { assert.equal(running, false, 'no overlapping process launches'); launches++; }
    running = value;
  } };
  const context = vm.createContext({ enabled: true, _settingsGeneration: 0,
    _selectionEpoch: 0, _selectionRequest: null, _selectionPending: false,
    selectionReader: '/fixture/never-executed-reader', selectionProbe: probe,
    Qt: { callLater: fn => later.push(fn) },
    queryProcess: { running: false }, countriesProcess: { running: false },
    refreshCountries() {}, vpnSettings: {} });
  context.controller = context;
  const protocol = vm.createContext({}); vm.runInContext(adapter, protocol); context.VpnProtocol = protocol;
  vm.runInContext(source.slice(source.indexOf('    function refreshSelectionReadback('), source.indexOf('    function _startQuery(')), context);
  const enabledBody = source.slice(source.indexOf('    onEnabledChanged: {') + '    onEnabledChanged: '.length, source.indexOf('\n    Process {'));
  const changeEnabled = vm.runInContext(`(function() ${enabledBody})`, context);
  const selection = source.slice(source.indexOf('        id: selectionProbe'), source.indexOf('        id: actionProcess'));
  const exitBody = selection.slice(selection.indexOf('function(exitCode)'), selection.lastIndexOf('\n    }')).trim();
  const onExit = vm.runInContext(`(${exitBody})`, context);
  const output = { text: '' };
  const onOutput = vm.runInContext(`(function() { ${selection.match(/onStreamFinished: ([^\n]+)/)[1]} })`, context);
  return { context, output, get launches() { return launches; },
    unknown() { context._settingsGeneration++; context.vpnSettings = protocol.normalizeSettings({ protocol: 'VPN_PROTOCOL_UNSPECIFIED' }); return context.refreshSelectionReadback(); },
    known() { context._settingsGeneration++; context.vpnSettings = protocol.normalizeSettings({ protocol: 'openvpn_tcp' }); context.refreshSelectionReadback(); },
    enabled(value) { context.enabled = value; changeEnabled(); },
    exit(code = 0, text = reply, afterExit = false) {
      running = false;
      const finishOutput = () => {
        output.text = text;
        onOutput.call(output);
      };
      if (!afterExit) finishOutput();
      onExit(code);
      if (afterExit) finishOutput();
    },
    flush() { let count = 0; while (later.length) { assert.ok(++count < 20, 'callbacks must not spin'); later.shift()(); } },
  };
}

test('overlapping unknown generations drain immediately to only the newest snapshot', () => {
  const f = fixture();
  f.unknown(); f.unknown(); f.unknown();
  assert.equal(f.launches, 1);
  f.exit();
  f.flush();
  assert.equal(f.launches, 2, 'superseded completion must launch the newest pending read without a poll');
  assert.equal(f.context.vpnSettings.technology, '', 'stale selection must not overwrite the latest snapshot');
  f.exit(); f.flush();
  assert.equal(f.context.vpnSettings.technology, 'NORDLYNX');
  assert.equal(f.launches, 2);
});

test('disable and re-enable reject old lifecycle completion even without a new settings generation', () => {
  const f = fixture(); f.unknown();
  f.enabled(false); f.enabled(true);
  f.context.refreshSelectionReadback();
  assert.equal(f.launches, 1, 'stopped request retains ownership until its exit drains');
  f.exit(); f.flush();
  assert.equal(f.context.vpnSettings.technology, '', 'old lifecycle must not populate selection');
  assert.equal(f.launches, 2, 'new lifecycle pending read must drain immediately');
  f.exit(); f.flush();
  assert.equal(f.context.vpnSettings.technology, 'NORDLYNX');
});

test('collector may finish after process exit without losing its JSON', () => {
  const f = fixture(); f.unknown(); f.exit(0, reply, true); f.flush();
  assert.equal(f.context.vpnSettings.technology, 'NORDLYNX');
});

test('completion captures immutable drained output before deferring and prevents collector reuse', () => {
  const f = fixture(); f.unknown(); f.exit();
  f.context.refreshSelectionReadback();
  assert.equal(f.launches, 1, 'deferred request still owns process slot');
  f.output.text = '{reused collector}';
  f.context._selectionRequest.output = '{mutated request}';
  f.flush();
  assert.equal(f.context.vpnSettings.technology, 'NORDLYNX', 'completion must use its immutable drained output snapshot');
  assert.equal(f.launches, 1);
});

for (const [name, code, text] of [
  ['nonzero exit', 1, reply], ['malformed JSON', 0, '{broken'],
  ['invalid schema', 0, '{}'], ['oversized output', 0, ' '.repeat(4097)],
]) {
  test(`${name} leaves unknown selection without retry spinning`, () => {
    const f = fixture(); f.unknown(); f.context.refreshSelectionReadback();
    f.exit(code, text); f.flush();
    assert.equal(f.context.vpnSettings.technology, '');
    assert.equal(f.context._selectionRequest, null);
    assert.equal(f.launches, 1, 'failure is not an automatic same-generation retry');
    f.flush(); assert.equal(f.launches, 1);
    f.unknown(); assert.equal(f.launches, 2, 'a later snapshot can retry');
  });
  test(`superseded ${name} still drains exactly one newest request`, () => {
    const f = fixture(); f.unknown(); f.unknown(); f.unknown();
    f.exit(code, text); f.flush();
    assert.equal(f.launches, 2);
    assert.equal(f.context.vpnSettings.technology, '');
    f.exit(); f.flush(); assert.equal(f.context.vpnSettings.technology, 'NORDLYNX');
    assert.equal(f.launches, 2);
  });
}

test('a native known snapshot cancels pending retry and rejects stale results', () => {
  const f = fixture(); f.unknown(); f.unknown(); f.known(); f.exit(); f.flush();
  assert.equal(f.context.vpnSettings.technology, 'OPENVPN');
  assert.equal(f.context.vpnSettings.protocol, 'TCP');
  assert.equal(f.launches, 1);
});

test('disable discards pending work and deferred completions cannot populate disabled state', () => {
  const f = fixture(); f.unknown(); f.unknown(); f.exit(); f.enabled(false); f.flush();
  assert.equal(f.context.vpnSettings.technology, ''); assert.equal(f.launches, 1);
  assert.equal(f.context._selectionRequest, null);
  assert.equal(f.context._selectionPending, false);
});

test('an old completion never clears a different request owner', () => {
  const f = fixture(); f.unknown(); f.exit();
  const owner = { generation: 99, epoch: 99 };
  f.context._selectionRequest = owner;
  f.flush();
  assert.equal(f.context._selectionRequest, owner);
  assert.equal(f.context.vpnSettings.technology, '');
});
