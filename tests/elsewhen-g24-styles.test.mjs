import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readQmlSource } from './qml-source.mjs';

const theme = readQmlSource(new URL('../variants/V2/Theme.qml', import.meta.url), 'utf8');
const panel = readQmlSource(new URL('../variants/V2/panels/ControlPanel.qml', import.meta.url), 'utf8');
function functionSource(name) {
  const marker = `function ${name}(`;
  const start = theme.indexOf(marker);
  assert.ok(start >= 0, marker);
  const brace = theme.indexOf('{', start);
  let depth = 1, end = brace + 1;
  while (depth) {
    if (theme[end] === '{') depth++;
    if (theme[end] === '}') depth--;
    assert.ok(end < theme.length, `balanced ${name}`);
    end++;
  }
  return theme.slice(start, end);
}
const methods = ['normalizeWidgetSurfaceStyle', 'widgetGidValid', 'widgetSurfaceStyle',
  'setWidgetSurfaceStyle', 'serializeWidgetSurfaceStyles', 'parseWidgetSurfaceStyles',
  'widgetColorModeValid', 'normalizedWidgetColorMode', 'widgetToneValid',
  'widgetColorStyle', 'setWidgetColorStyle', 'setWidgetPaletteColor',
  'setWidgetBorderEnabled', 'widgetHasBorder', 'resetWidgetSurfaceStyle',
  'serializeWidgetColorStyles'];
const ctx = { widgetSurfaceStyles: {}, widgetColorStyles: {}, _widgetsLoaded: true,
  saveWidgets() {}, paletteColorValid: value => /^color0[1-9]$/.test(value) || value === 'foreground' };
vm.createContext(ctx);
vm.runInContext(methods.map(functionSource).join('\n'), ctx);

test('G24 surface customization callbacks persist and reload the World Clock style', () => {
  assert.match(panel, /objectName:\s*"elsewhen-widget-toggle";\s*gid:\s*"G24"/);
  assert.equal(ctx.widgetGidValid('G24'), true);
  ctx.setWidgetSurfaceStyle('G24', 'opacity', 0.68);
  ctx.setWidgetSurfaceStyle('G24', 'radius', 'round');
  ctx.setWidgetSurfaceStyle('G24', 'padding', 'roomy');
  ctx.setWidgetSurfaceStyle('G24', 'borderWidth', 1.5);
  ctx.setWidgetSurfaceStyle('G24', 'borderColor', 'color03');
  const serialized = ctx.serializeWidgetSurfaceStyles();
  assert.match(serialized, /^G24~/);
  ctx.widgetSurfaceStyles = ctx.parseWidgetSurfaceStyles(serialized);
  assert.deepEqual(JSON.parse(JSON.stringify(ctx.widgetSurfaceStyle('G24'))),
    { opacity: 0.68, radius: 'round', padding: 'roomy', borderWidth: 1.5, borderColor: 'color03' });
  assert.ok(panel.includes("ctrlPanel.root.setWidgetSurfaceStyle(ctrlPanel.widgetColorMenuGid, modelData.key, next)"));
  assert.match(panel, /onActivated:\s*ctrlPanel\.root\.resetWidgetSurfaceStyle\(ctrlPanel\.widgetColorMenuGid\)/);
  assert.match(panel, /onActivated:\s*ctrlPanel\.root\.setWidgetBorderEnabled\(/);
  ctx.resetWidgetSurfaceStyle('G24');
  assert.equal(Object.hasOwn(ctx.widgetSurfaceStyles, 'G24'), false);
});

test('G24 palette and border toggles survive the production color serializer', () => {
  assert.equal(ctx.widgetGidValid('G24'), true);
  ctx.setWidgetColorStyle('G24', 'color05', 'both', 'foreground');
  assert.match(ctx.serializeWidgetColorStyles(), /G24~color05~both~foreground/);
});
