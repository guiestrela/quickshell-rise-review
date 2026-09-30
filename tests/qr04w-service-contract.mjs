import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const base = resolve(dirname(fileURLToPath(import.meta.url)), '..');
for (const variant of ['', 'variants/V2/']) {
  test(`${variant || 'V1'}: serviço único passa recursão ao scanner sem alterar legado`, () => {
    const source = readFileSync(resolve(base, `versions/V1/${variant}modules/WallpaperManagerService.qml`), 'utf8');
    assert.match(source, /theme\.wallpaperRecursive\s*===\s*false/);
    assert.match(source, /\.push\("--flat"\)/);
    assert.match(source, /function scanFolder\(\)/);
    assert.match(source, /wallpaper-scan\.py/);
    assert.doesNotMatch(source, /WallpaperOmarchyManager|omarchy-shell shell/);
  });
}
