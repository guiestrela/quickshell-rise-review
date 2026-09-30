import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const base = resolve(dirname(fileURLToPath(import.meta.url)), '..');
for (const variant of ['', 'variants/V2/']) {
  const name = variant ? 'V2' : 'V1';
  test(`${name}: widget Rise abre o seletor real e pede próximo ao serviço existente`, () => {
    const source = readFileSync(resolve(base, `versions/V1/${variant}modules/WallpaperWidget.qml`), 'utf8');
    assert.match(source, /required property var root/);
    assert.match(source, /rootMod\.root\.toggleImagePicker\("wallpaper",\s*rootMod\.screen\)/);
    assert.match(source, /rootMod\.root\.shuffleWallpapers\(\)/);
    assert.match(source, /root\.modWallpapers\s*\?/);
    assert.doesNotMatch(source, /\bProcess\s*\{|execDetached|omarchy-shell|omarchy-theme-bg-set/);
  });
}
