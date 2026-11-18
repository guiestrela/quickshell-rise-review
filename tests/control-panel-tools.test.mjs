import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const logicPath = new URL('../shared/logic/ControlPanelTools.js', import.meta.url);
assert.ok(existsSync(logicPath), 'ControlPanelTools search and health logic is not implemented');
const source = readFileSync(logicPath, 'utf8')
    .replace(/^\.pragma library\s*/m, '');
const api = {};
vm.runInNewContext(source, api, { filename: 'ControlPanelTools.js' });

const plain = (value) => JSON.parse(JSON.stringify(value));

test('search matches every normalized query token across labels and keywords', () => {
    const entries = plain(api.entriesForVariant('V2'));
    const results = plain(api.filterEntries(entries, 'nordvpn countries', 10));
    assert.equal(results.length, 1);
    assert.equal(results[0].id, 'nordvpn');
    assert.equal(results[0].target, 'widgets');
    assert.deepEqual(plain(api.filterEntries(entries, 'nao existente', 10)), []);
});

test('search is accent-insensitive, case-insensitive, and bounded', () => {
    const entries = plain(api.entriesForVariant('V1'));
    assert.equal(plain(api.filterEntries(entries, 'BAR POSIÇÃO', 10))[0].id, 'position');
    assert.equal(plain(api.filterEntries(entries, '', 3)).length, 3);
});

test('V1 and V2 catalogs preserve variant-specific destinations and G23', () => {
    const v1 = plain(api.entriesForVariant('V1'));
    const v2 = plain(api.entriesForVariant('V2'));
    assert.equal(v1.some((entry) => entry.id === 'split-layout'), true);
    assert.equal(v2.some((entry) => entry.id === 'split-layout'), false);
    assert.equal(v1.find((entry) => entry.id === 'indicators').target, 'widgets');
    assert.equal(v2.find((entry) => entry.id === 'indicators').target, 'widgets');
});

test('health rows label only local observations and explicitly omit external probes', () => {
    const rows = plain(api.healthRows({
        variant: 'v2', switching: false, outputName: '',
        battery: true, backlight: false, networkMode: 'wifi'
    }));
    const byLabel = Object.fromEntries(rows.map((row) => [row.label, row]));
    assert.equal(byLabel['Variant'].value, 'V2');
    assert.equal(byLabel['Variant switch'].value, 'Idle');
    assert.equal(byLabel['Popup output'].value, 'Not selected');
    assert.equal(byLabel['Battery capability'].value, 'Detected');
    assert.equal(byLabel['Backlight capability'].value, 'Not detected');
    assert.equal(byLabel['Network widget mode'].value, 'Wi-Fi');
    assert.equal(byLabel['External checks'].value, 'Not run');
    assert.match(byLabel['External checks'].detail, /no account/i);
});
