import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

test('Search entry points and generic destinations are removed from both ControlPanels', () => {
    for (const variant of ['V1', 'V2']) {
        const source = read(`variants/${variant}/panels/ControlPanel.qml`);
        assert.ok(!/searchToolsTile|control-panel-search-opener|openToolsDestination|onDestinationRequested|toolsStartInHealth/.test(source), `${variant} must not expose Search routing`);
        assert.ok(source.includes('control-panel-health-opener'), `${variant} must retain Health`);
        assert.ok(source.includes('focusReturnTarget: healthToolsTile'), `${variant} must return focus to Health`);
    }
});

test('Health overlay has no Search UI or catalog dependency', () => {
    const source = read('shared/components/ControlPanelTools.qml');
    assert.ok(!/searchInput|searchTab|filteredEntries|searchEntries|destinationRequested|startInHealth|ControlPanelTools\.js/.test(source));
    assert.ok(source.includes('LOCAL STATE ONLY · NO EXTERNAL PROBES'));
    assert.ok(source.includes('model: tools.healthRows'));
    assert.ok(!/\bProcess\s*\{|execDetached|\bFileView\s*\{/.test(source));
    assert.equal(existsSync(new URL('../shared/logic/ControlPanelTools.js', import.meta.url)), false, 'unused Search catalog must be removed');
});
