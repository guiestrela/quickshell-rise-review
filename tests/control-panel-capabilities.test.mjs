import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const logicPath = new URL('../shared/logic/ControlPanelCapabilities.js', import.meta.url);
assert.ok(existsSync(logicPath), 'ControlPanel capability facade is not implemented');
const source = readFileSync(logicPath, 'utf8').replace(/^\.pragma library\s*/m, '');
const api = {};
vm.runInNewContext(source, api, { filename: 'ControlPanelCapabilities.js' });
const plain = (value) => JSON.parse(JSON.stringify(value));
const byLabel = (report) => Object.fromEntries(report.healthRows.map((row) => [row.label, row]));

test('facade normalizes only supplied local host values', () => {
    const report = plain(api.readHostCapabilities({
        variantHost: { runningVariant: 'v2', switching: false },
        activePopupScreenName: 'DP-1', hasBattery: true, hasBacklight: false,
        networkMode: 'wifi'
    }));
    const rows = byLabel(report);
    assert.equal(rows.Variant.value, 'V2');
    assert.equal(rows['Variant switch'].value, 'Idle');
    assert.equal(rows['Popup output'].value, 'DP-1');
    assert.equal(rows['Battery capability'].value, 'Detected');
    assert.equal(rows['Backlight capability'].value, 'Not detected');
    assert.equal(rows['Network widget mode'].value, 'Wi-Fi');
    assert.deepEqual(plain(report.diagnostics), []);
});

test('facade distinguishes missing host API from present but temporarily empty state', () => {
    const missing = plain(api.readHostCapabilities({ hasBattery: false, hasBacklight: false }));
    const missingRows = byLabel(missing);
    assert.equal(missingRows.Variant.value, 'Unsupported');
    assert.equal(missingRows['Popup output'].value, 'Unsupported');
    assert.equal(missingRows['Network widget mode'].value, 'Unsupported');
    assert.ok(missing.diagnostics.some((item) => item.code === 'variant-host-missing'));
    assert.ok(missing.diagnostics.some((item) => item.code === 'network-mode-missing'));

    const temporary = plain(api.readHostCapabilities({
        variantHost: { runningVariant: '', switching: true },
        activePopupScreenName: '', hasBattery: false, hasBacklight: false,
        networkMode: 'none'
    }));
    const temporaryRows = byLabel(temporary);
    assert.equal(temporaryRows.Variant.value, 'Not reported');
    assert.equal(temporaryRows['Variant switch'].value, 'In progress');
    assert.equal(temporaryRows['Popup output'].value, 'Not selected');
    assert.equal(temporaryRows['Network widget mode'].value, 'Not reported');
    assert.deepEqual(plain(temporary.diagnostics), []);
});

test('facade emits diagnostic codes for unsupported fields without external checks', () => {
    const report = plain(api.readHostCapabilities({
        variantHost: { runningVariant: 'v1' },
        activePopupScreenName: 'HDMI-A-1', hasBattery: true,
        networkMode: 'future-mode'
    }));
    const rows = byLabel(report);
    assert.equal(rows['Variant switch'].value, 'Unsupported');
    assert.equal(rows['Network widget mode'].value, 'Unknown');
    assert.equal(rows['External checks'].value, 'Not run');
    assert.match(rows.Diagnostics.detail, /switching-missing/);
    assert.ok(report.diagnostics.some((item) => item.code === 'backlight-capability-missing'));
    assert.ok(report.diagnostics.some((item) => item.code === 'network-mode-unknown'));
});
