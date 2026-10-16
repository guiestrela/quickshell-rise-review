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
  test(`${variant}: Bluetooth battery is shown only for connected devices with valid live data`, () => {
    const qml = readFileSync(join(repo, relativePath), 'utf8');
    assert.match(qml, /import Quickshell\.Bluetooth/);
    assert.match(qml, /text:\s*"\\uE1A4"/);
    assert.match(qml, /batteryPercentForDevice\(/);
    assert.match(qml, /height:\s*42\b/, 'device row height stays unchanged');

    const bluetoothDevice = { address: 'AA:BB:CC:DD:EE:FF', connected: true, batteryAvailable: true, battery: 0.65 };
    const context = { Bluetooth: { devices: { values: [bluetoothDevice] } } };
    const batteryPercentForDevice = vm.runInNewContext(`(${extractFunction(qml, 'batteryPercentForDevice')})`, context);
    const percent = (connected = true) => batteryPercentForDevice('AA:BB:CC:DD:EE:FF', connected);

    assert.equal(percent(), 65);
    bluetoothDevice.battery = 0;
    assert.equal(percent(), 0, 'zero percent is a valid reported value');
    bluetoothDevice.battery = 1;
    assert.equal(percent(), 100);
    bluetoothDevice.batteryAvailable = false;
    assert.equal(percent(), null, 'unavailable battery must not become zero');
    bluetoothDevice.batteryAvailable = true;
    bluetoothDevice.connected = false;
    assert.equal(percent(), null, 'disconnected devices must not expose stale battery');
    bluetoothDevice.connected = true;
    assert.equal(percent(false), null, 'the row connection state also gates the data');
    bluetoothDevice.battery = 1.01;
    assert.equal(percent(), null, 'out-of-range API values are unavailable');
    bluetoothDevice.battery = 0.42;
    assert.equal(percent(), 42, 'subsequent live updates are reflected');
    context.Bluetooth.devices.values = [];
    assert.equal(percent(), null, 'removed devices must not retain stale values');
  });
}
