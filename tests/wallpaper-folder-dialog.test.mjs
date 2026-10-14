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
  test(`${variant}: browse from the parent so a media-only folder is selectable`, () => {
    const qml = readFileSync(join(repo, relativePath), 'utf8');
    assert.ok(/FolderDialog\s*\{/.test(qml), 'production FolderDialog must exist');
    assert.ok(/currentFolder:\s*panel\.folderPickerStartUrl\(panel\.profile\.folder\)/.test(qml), 'picker must start at the configured folder parent');
    assert.ok(!/selectedFolder:\s*currentFolder/.test(qml), 'do not bind selectedFolder before the dialog backend exists');

    const browseStart = qml.indexOf('id: browseButton;');
    const handlerStart = qml.indexOf('onActivated: {', browseStart);
    const browseHandler = handlerStart < 0 ? null : extractBlock(qml, qml.indexOf('{', handlerStart));
    assert.ok(browseHandler, 'Browse button handler must exist');
    const resetIndex = browseHandler.indexOf('folderDialog.currentFolder = panel.folderPickerStartUrl(folder)');
    const openIndex = browseHandler.indexOf('folderDialog.open()');
    const callLaterIndex = browseHandler.indexOf('Qt.callLater(');
    const selectIndex = browseHandler.indexOf('folderDialog.selectedFolder = panel.folderPickerSelectionUrl(folder)');
    assert.ok(resetIndex >= 0 && openIndex > resetIndex, 'reset currentFolder to the configured parent before every open');
    assert.ok(callLaterIndex > openIndex && selectIndex > callLaterIndex, 'select the configured folder after opening, once the dialog backend exists');

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
