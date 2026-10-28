import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync('versions/V1/variants/V2/Theme.qml', 'utf8');
function settings() {
    const context = vm.createContext({
        widgetSurfaceStyles: {}, _widgetsLoaded: true, saves: 0,
        panelButtonRadius: 10,
        paletteColorValid: id => /^color0[1-7]$/.test(id) || id === 'foreground',
        saveWidgets() { context.saves++; }
    });
    // Execute the production functions, without starting services or touching user caches.
    for (const name of ['widgetSurfaceStyle', 'normalizeWidgetSurfaceStyle',
        'setWidgetSurfaceStyle', 'resetWidgetSurfaceStyle', 'widgetSurfacePadding',
        'widgetSurfaceRadius', 'serializeWidgetSurfaceStyles', 'parseWidgetSurfaceStyles', 'widgetGidValid']) {
        const start = source.indexOf(`    function ${name}(`);
        const end = source.indexOf('\n    }', start) + 6;
        assert.ok(start >= 0 && end > start, name);
        vm.runInContext(source.slice(start, end), context);
    }
    return context;
}

test('old caches retain original surface geometry and can round trip new choices', () => {
    const c = settings();
    assert.equal(c.widgetSurfaceStyle('G2').opacity, 1);
    assert.equal(c.widgetSurfaceRadius('G2'), 10);
    assert.equal(c.widgetSurfacePadding('G2'), 0);
    assert.equal(c.serializeWidgetSurfaceStyles(), '-');
    for (const [key, value] of Object.entries({opacity: .68, radius: 'round', padding: 'roomy', borderWidth: 1.5, borderColor: 'color03'}))
        c.setWidgetSurfaceStyle('G2', key, value);
    const encoded = c.serializeWidgetSurfaceStyles();
    c.widgetSurfaceStyles = c.parseWidgetSurfaceStyles(encoded);
    assert.equal(c.serializeWidgetSurfaceStyles(), encoded);
    assert.equal(c.widgetSurfacePadding('G2'), 6);
    assert.equal(c.widgetSurfaceRadius('G2'), 12);
    assert.equal(c.widgetSurfaceStyle('G2').borderColor, 'color03');
    c.setWidgetSurfaceStyle('G2', 'radius', 'soft');
    assert.equal(c.widgetSurfaceStyle('G2').opacity, .68);
    c.resetWidgetSurfaceStyle('G2');
    assert.equal(c.serializeWidgetSurfaceStyles(), '-');
});

test('malformed cache entries and unsupported controls cannot enter saved settings', () => {
    const c = settings();
    c.widgetSurfaceStyles = c.parseWidgetSurfaceStyles(
        'G2~0.68~round~roomy~1.5,G99~1~auto~none~1,G3~0.1~soft~none~1,' +
        "G4~1~invalid~roomy~1,G5~1~soft~none~9,G6~1~soft~none~1~bad'");
    assert.equal(c.serializeWidgetSurfaceStyles(), 'G2~0.68~round~roomy~1.5~inherit');
    c.setWidgetSurfaceStyle('G99', 'opacity', 1);
    c.setWidgetSurfaceStyle('G3', 'unknown', 'bad');
    assert.equal(c.saves, 0);
    c.setWidgetSurfaceStyle('G2', 'opacity', -100);
    assert.equal(c.widgetSurfaceStyle('G2').opacity, .35);
    c.setWidgetSurfaceStyle('G2', 'borderWidth', 100);
    assert.equal(c.widgetSurfaceStyle('G2').borderWidth, 2);
    c.setWidgetSurfaceStyle('G2', 'radius', "bad'");
    assert.equal(c.widgetSurfaceStyle('G2').radius, 'auto');
    assert.ok(!c.serializeWidgetSurfaceStyles().includes("'"));
});
