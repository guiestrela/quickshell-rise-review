import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const repo = dirname(dirname(fileURLToPath(import.meta.url)));
const variants = [
  ['V1', 'versions/V1/panels/BluetoothPanel.qml'],
  ['V2', 'versions/V1/variants/V2/panels/BluetoothPanel.qml'],
];
const selectedDevice = {
  name: 'Synthetic paired device', paired: true, connected: false,
  adapterId: 'hci1', mac: '12:34:56:78:9A:BC',
  dbusPath: '/org/bluez/hci1/dev_12_34_56_78_9A_BC',
};

function extractFunction(source, name) {
  const start = source.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const open = source.indexOf('{', start);
  let depth = 0;
  for (let index = open; index < source.length; index += 1) {
    if (source[index] === '{') depth += 1;
    if (source[index] === '}' && --depth === 0) return source.slice(start, index + 1);
  }
  assert.fail(`${name} must be a complete function`);
}

for (const [variant, relativePath] of variants) {
  test(`${variant}: only a validated paired selection reaches confirmation and removal`, () => {
    const qml = readFileSync(join(repo, relativePath), 'utf8');
    const ctx = {
      forgetTarget: null, forgetError: '', forgetNotice: '',
      forgetReadbackPending: false, forgetCommandAdapter: '', forgetCommandDevice: '',
      forgetProc: { running: false }, connProc: { running: false },
    };
    for (const fn of ['validBluetoothIdentity', 'requestForgetDevice', 'cancelForgetDevice', 'confirmForgetDevice']) {
      ctx[fn] = vm.runInNewContext(`(${extractFunction(qml, fn)})`, ctx);
    }

    assert.equal(ctx.validBluetoothIdentity(selectedDevice), true);
    assert.equal(ctx.validBluetoothIdentity({ ...selectedDevice, paired: false }), false);
    assert.equal(ctx.validBluetoothIdentity({ ...selectedDevice, adapterId: '../hci1' }), false);
    assert.equal(ctx.validBluetoothIdentity({ ...selectedDevice, mac: '12:34:56:78:9A:BC;touch' }), false);
    assert.equal(ctx.validBluetoothIdentity({ ...selectedDevice, dbusPath: '/org/bluez/hci0/dev_12_34_56_78_9A_BC' }), false);

    ctx.requestForgetDevice(selectedDevice);
    assert.equal(JSON.stringify(ctx.forgetTarget), JSON.stringify({
      name: selectedDevice.name, adapterId: selectedDevice.adapterId,
      mac: selectedDevice.mac, dbusPath: selectedDevice.dbusPath, paired: true,
    }), 'confirmation retains an immutable identity snapshot');
    ctx.cancelForgetDevice();
    assert.equal(ctx.forgetTarget, null);
    assert.equal(ctx.forgetProc.running, false, 'cancel does not invoke removal');

    ctx.requestForgetDevice(selectedDevice);
    ctx.confirmForgetDevice();
    assert.equal(ctx.forgetProc.running, true, 'explicit confirmation starts removal');
    assert.equal(ctx.forgetCommandAdapter, '/org/bluez/hci1');
    assert.equal(ctx.forgetCommandDevice, selectedDevice.dbusPath);
    ctx.confirmForgetDevice();
    assert.equal(ctx.forgetProc.running, true, 'duplicate confirmation does not launch another process');

    ctx.forgetProc.running = false;
    ctx.forgetReadbackPending = true;
    ctx.confirmForgetDevice();
    assert.equal(ctx.forgetProc.running, false, 'readback blocks a second removal');
    ctx.forgetReadbackPending = false;
    ctx.connProc.running = true;
    ctx.confirmForgetDevice();
    assert.equal(ctx.forgetProc.running, false, 'connection action blocks removal');

    assert.match(qml, /RemoveDevice/);
    assert.match(qml, /pair again|new pairing/i);
    assert.match(qml, /forgetReadbackPending/);
    assert.match(qml, /still paired|Could not verify/i);
    assert.doesNotMatch(qml, /bash.*-c.*forget/i, 'Forget must not interpolate identity into a shell');
  });
}
