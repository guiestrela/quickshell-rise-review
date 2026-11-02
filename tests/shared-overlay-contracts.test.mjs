import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = name => readFileSync(new URL(`../shared/panels/${name}.qml`, import.meta.url), 'utf8');

test('shared tooltip keeps variant presentation injectable', () => {
    const text = source('TooltipOverlay');
    for (const property of [
        'barBottom',
        'gap',
        'useTooltipYForVertical',
        'surfaceColor',
        'surfaceBorderColor',
        'surfaceBorderWidth',
        'surfaceRadius',
        'shadowComponent',
    ]) {
        assert.match(text, new RegExp(`property .*\\b${property}\\b`));
    }
    assert.match(text, /sourceComponent: overlay\.shadowComponent/);
    assert.match(text, /tooltipTopY/);
    assert.match(text, /tooltipBottomY/);
});

test('shared tray menu keeps variant surface and positioning injectable', () => {
    const text = source('TrayMenu');
    for (const property of [
        'barBottom',
        'gap',
        'cardRadius',
        'cardBorderColor',
        'cardBorderWidth',
        'rowRadius',
        'shadowComponent',
        'positionerComponent',
    ]) {
        assert.match(text, new RegExp(`property .*\\b${property}\\b`));
    }
    assert.match(text, /sourceComponent: trayMenu\.shadowComponent/);
    assert.match(text, /sourceComponent: trayMenu\.positionerComponent/);
    assert.match(text, /function openSubmenu/);
    assert.match(text, /function goBack/);
});
