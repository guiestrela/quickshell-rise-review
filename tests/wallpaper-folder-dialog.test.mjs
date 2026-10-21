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
  test(`${variant}: unified chooser opens the configured folder before selecting files or directories`, () => {
    const qml = readFileSync(join(repo, relativePath), 'utf8');
    assert.match(qml, /WallpaperExternalPicker\s*\{/);
    assert.match(qml, /currentFolder:\s*panel\.profile\.folder === "" \? "file:\/\/\/home" : panel\.folderPickerSelectionUrl\(panel\.profile\.folder\)/);
    assert.doesNotMatch(qml, /(?:FolderDialog|FileDialog)\s*\{/, 'keep toolkit chooser lifecycles outside the shell');

    const browseStart = qml.indexOf('id: browseButton;');
    const handlerStart = qml.indexOf('onActivated: {', browseStart);
    assert.ok(browseStart >= 0 && handlerStart >= 0, 'Browse button handler must exist');
    const browseHandler = extractBlock(qml, qml.indexOf('{', handlerStart));
    const selectionUrl = vm.runInNewContext(`(${extractFunction(qml, 'folderPickerSelectionUrl')})`);
    for (const folder of ['/home/test/Wallpapers/Live Set', '/home/test/Wallpapers/media-only', '/', '']) {
      const calls = [];
      const picker = { open() { calls.push({ folder: this.currentFolder, display: this.targetDisplay }); } };
      vm.runInNewContext(browseHandler, {
        panel: { profile: { folder }, root: { wallpaperManagerDisplay: 'DP-2' }, folderPickerSelectionUrl: selectionUrl },
        wallpaperDialog: picker,
      });
      assert.deepEqual(calls, [{ folder: folder ? selectionUrl(folder) : 'file:///home', display: 'DP-2' }]);
    }
    const helper = readFileSync(join(repo, 'scripts/rise-wallpaper-picker'), 'utf8');
    assert.match(helper, /os\.path\.isdir\(info\.filename\) or Path\(info\.filename\)\.suffix\.lower\(\) in EXTENSIONS/,
      'filter must retain directories even when they only contain media files');
    assert.match(helper, /chooser\.get_filename\(\) or chooser\.get_current_folder\(\)/,
      'confirmation with no selected item applies the open folder');
    assert.match(helper, /if os\.path\.isdir\(path\):\s*kind = 'folder'/);
    assert.match(helper, /elif os\.path\.isfile\(path\).*:\s*kind = 'file'/);

    const startUrl = vm.runInNewContext(`(${extractFunction(qml, 'folderPickerStartUrl')})`);
    assert.equal(selectionUrl('/home/guiestrela/Wallpapers/horizontalLive'), 'file:///home/guiestrela/Wallpapers/horizontalLive');
    assert.equal(selectionUrl('/home/guiestrela/Wallpapers/Live Set'), 'file:///home/guiestrela/Wallpapers/Live%20Set');
    assert.equal(startUrl('/home/guiestrela/Wallpapers/horizontalLive'), 'file:///home/guiestrela/Wallpapers');
    assert.equal(startUrl('/home/guiestrela/Wallpapers/Live Set'), 'file:///home/guiestrela/Wallpapers');
    assert.equal(startUrl('/home/guiestrela/Live Set'), 'file:///home/guiestrela');
    assert.equal(startUrl('/'), 'file:///');
    assert.equal(startUrl(''), 'file:///home');
  });
}
