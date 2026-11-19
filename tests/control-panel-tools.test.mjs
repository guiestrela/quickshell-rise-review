import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const healthSymbols = /control-panel-health-opener|control-panel-tools-overlay|healthToolsTile|healthCapabilities|healthRows|toolsOpen|panelTools|ControlPanelTools|ControlPanelCapabilities|focusReturnRoot|onCloseRequested|label:\s*"Health"|Read-only Control Panel health|variantName:\s*"V[12]"/;

test('Health and Search are absent from both ControlPanels', () => {
    for (const variant of ['V1', 'V2']) {
        const source = read(`variants/${variant}/panels/ControlPanel.qml`);
        assert.ok(!healthSymbols.test(source), `${variant} must not expose Health`);
        assert.ok(!/searchToolsTile|control-panel-search-opener|openToolsDestination|onDestinationRequested/.test(source), `${variant} must not expose Search routing`);
        assert.ok(source.includes('objectName: "control-panel"') || source.includes('id: card'), `${variant} must retain its ControlPanel content`);
    }
});

test('native composition gate no longer depends on Health', () => {
    const source = read('tests/test-control-panel-native-composition.py');
    assert.ok(!/toolsOpen|control-panel-health-opener|control-panel-tools-overlay|healthToolsTile|healthCapabilities|healthRows/.test(source));
});

test('Health-only production and fixture files are removed', () => {
    for (const path of [
        'shared/components/ControlPanelTools.qml',
        'shared/logic/ControlPanelCapabilities.js',
        'shared/services/ControlPanelCapabilities.qml',
        'tests/qml/tst_ControlPanelTools.qml',
        'tests/qml/tst_IndependentControlTools.qml',
        'tests/test-control-panel-tools-independent.py',
        'tests/control-panel-capabilities.test.mjs',
    ]) {
        assert.equal(existsSync(new URL(`../${path}`, import.meta.url)), false, `${path} must be removed`);
    }
});
