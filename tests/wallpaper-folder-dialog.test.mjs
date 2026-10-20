import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const repo = dirname(dirname(fileURLToPath(import.meta.url)));
const variants = [
  ['V1', 'versions/V1/panels/WallpaperManagerQuickPanel.qml'],
  ['V2', 'versions/V1/variants/V2/panels/WallpaperManagerQuickPanel.qml'],
];

function extractBlock(source, openingBrace) {
  let depth = 0;
  for (let index = openingBrace; index < source.length; index += 1) {
    if (source[index] === '{') depth += 1;
    if (source[index] === '}' && --depth === 0) return source.slice(openingBrace + 1, index);
  }
  assert.fail('block has an unterminated body');
}

function extractFunction(source, name) {
  const start = source.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const open = source.indexOf('{', start);
  const body = extractBlock(source, open);
  return source.slice(start, open) + `{${body}}`;
}

for (const [variant, relativePath] of variants) {
  test(`${variant}: external picker keeps local folder URLs and selected display`, () => {
    const qml = readFileSync(join(repo, relativePath), 'utf8');
    assert.match(qml, /WallpaperExternalPicker\s*\{/);
    assert.match(qml, /wallpaperDialog\.currentFolder = folder === "" \? "file:\/\/\/home" : panel\.folderPickerSelectionUrl\(folder\)/);
    assert.match(qml, /wallpaperDialog\.targetDisplay = panel\.root\.wallpaperManagerDisplay/);
    assert.match(qml, /wallpaperDialog\.open\(\)/);

    const startUrl = vm.runInNewContext(`(${extractFunction(qml, 'folderPickerStartUrl')})`);
    const selectionUrl = vm.runInNewContext(`(${extractFunction(qml, 'folderPickerSelectionUrl')})`);
    assert.equal(selectionUrl('/home/guiestrela/Wallpapers/horizontalLive'), 'file:///home/guiestrela/Wallpapers/horizontalLive');
    assert.equal(selectionUrl('/home/guiestrela/Wallpapers/Live Set'), 'file:///home/guiestrela/Wallpapers/Live%20Set');
    assert.equal(startUrl('/home/guiestrela/Wallpapers/horizontalLive'), 'file:///home/guiestrela/Wallpapers');
    assert.equal(startUrl('/home/guiestrela/Wallpapers/Live Set'), 'file:///home/guiestrela/Wallpapers');
    assert.equal(startUrl('/home/guiestrela/Live Set'), 'file:///home/guiestrela');
    assert.equal(startUrl('/'), 'file:///');
    assert.equal(startUrl(''), 'file:///home');
  });
}
