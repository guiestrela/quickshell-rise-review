import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const project = dirname(dirname(fileURLToPath(import.meta.url)));
const variants = [
  ['V1', 'versions/V1/modules/WallpaperProfile.js'],
  ['V2', 'versions/V1/variants/V2/modules/WallpaperProfile.js'],
];

function profile(path) {
  const source = readFileSync(join(project, path), 'utf8').replace(/^\.pragma library\s*\n/, '');
  const context = vm.createContext({});
  vm.runInContext(source, context, { filename: path });
  return context;
}

for (const [name, path] of variants) {
  test(`${name}: configuração legada de pasta é preservada por monitor`, () => {
    const config = profile(path).configFor({ folder: '~/wallpapers', recursive: false }, 'DP-1', '/home/test');
    assert.equal(config.folder, '/home/test/wallpapers');
    assert.equal(config.recursive, false);
    assert.equal(config.mode, 'shuffle');
    assert.equal(config.scaling, 'zoom');
    assert.equal(config.pinned, '');
  });

  test(`${name}: configuração própria do monitor prevalece, outra herda 'all'`, () => {
    const settings = {
      folder: '/legacy',
      perDisplayConfig: true,
      displayConfig: {
        all: { folder: '/shared', mode: 'shuffle', scaling: 'fitWidth' },
        'DP-1': { folder: '/one', recursive: false, mode: 'single', pinned: '/one/pinned.jpg', scaling: 'actual' },
      },
    };
    const api = profile(path);
    const first = api.configFor(settings, 'DP-1', '/home/test');
    const second = api.configFor(settings, 'DP-2', '/home/test');
    assert.equal(first.folder, '/one');
    assert.equal(first.recursive, false);
    assert.equal(first.mode, 'single');
    assert.equal(first.pinned, '/one/pinned.jpg');
    assert.equal(first.scaling, 'actual');
    assert.equal(second.folder, '/shared');
    assert.equal(second.mode, 'shuffle');
    assert.equal(second.scaling, 'fitWidth');
  });

  test(`${name}: caminhos inválidos e pin fora da pasta não são usados`, () => {
    const api = profile(path);
    const outside = api.configFor({
      perDisplayConfig: true,
      displayConfig: { 'DP-1': { folder: '/safe', pinned: '/safe-neighbor/secret.png', mode: 'invalid', scaling: 'invalid' } },
    }, 'DP-1', '/home/test');
    assert.equal(outside.pinned, '');
    assert.equal(outside.mode, 'shuffle');
    assert.equal(outside.scaling, 'zoom');
    const cleared = api.configFor({ folder: '', displayConfig: { all: { folder: '', pinned: '/stale.png' } } }, 'DP-1', '/home/test');
    assert.equal(cleared.pinned, '');
    const unsafe = api.configFor({ folder: 'https://example.test/evil' }, 'DP-1', '/home/test');
    assert.equal(unsafe.folder, '');
  });

  test(`${name}: edição de um monitor é imutável e preserva os demais`, () => {
    const api = profile(path);
    const previous = {
      folder: '/legacy', perDisplayConfig: true,
      displayConfig: { 'DP-2': { folder: '/two', mode: 'single', pinned: '/two/a.png' } },
    };
    const updated = api.updateDisplay(previous, 'DP-1', { folder: '/one' }, '/home/test');
    assert.equal(previous.displayConfig['DP-1'], undefined);
    assert.equal(previous.displayConfig['DP-2'].folder, '/two');
    assert.equal(api.configFor(updated, 'DP-1', '/home/test').folder, '/one');
    assert.equal(api.configFor(updated, 'DP-2', '/home/test').pinned, '/two/a.png');
    assert.equal(api.configFor(updated, 'DP-1', '/home/test').mode, 'shuffle');
  });

  test(`${name}: modo compartilhado muda apenas com valor permitido`, () => {
    const api = profile(path);
    const settings = {
      perDisplayConfig: false,
      displayConfig: { all: { folder: '/shared', mode: 'shuffle' }, 'DP-1': { folder: '/old' } },
    };
    const updated = api.updateDisplay(settings, 'DP-1', { mode: 'single' }, '/home/test');
    assert.equal(api.configFor(updated, 'DP-1', '/home/test').mode, 'single');
    assert.equal(api.configFor(updated, 'DP-2', '/home/test').mode, 'single');
    assert.equal(updated.displayConfig['DP-1'].folder, '/old');
    const rejected = api.updateDisplay(updated, 'DP-1', { mode: 'malicious' }, '/home/test');
    assert.equal(api.configFor(rejected, 'DP-1', '/home/test').mode, 'single');
  });

  test(`${name}: atualização de perfil persiste modo e escala por monitor sem alterar outros`, () => {
    const api = profile(path);
    const settings = {
      perDisplayConfig: true,
      displayConfig: {
        all: { folder: '/shared', mode: 'shuffle', scaling: 'zoom' },
        'DP-2': { folder: '/two', mode: 'single', scaling: 'actual' },
      },
    };
    const changed = api.updateDisplay(settings, 'DP-1', { mode: 'single', scaling: 'fitWidth' }, '/home/test');
    assert.equal(api.configFor(changed, 'DP-1', '/home/test').mode, 'single');
    assert.equal(api.configFor(changed, 'DP-1', '/home/test').scaling, 'fitWidth');
    assert.equal(api.configFor(changed, 'DP-2', '/home/test').scaling, 'actual');
    assert.equal(api.configFor(changed, 'DP-3', '/home/test').scaling, 'zoom');
    const rejected = api.updateDisplay(changed, 'DP-1', { scaling: 'javascript:bad' }, '/home/test');
    assert.equal(api.configFor(rejected, 'DP-1', '/home/test').scaling, 'fitWidth');
  });

  test(`${name}: pin somente aceita imagem dentro da pasta e limpa ao trocar pasta`, () => {
    const api = profile(path);
    const base = { perDisplayConfig: true, displayConfig: { 'DP-1': { folder: '/wall' } } };
    const pinned = api.updateDisplay(base, 'DP-1', { pinned: '/wall/photo.png' }, '/home/test');
    assert.equal(api.configFor(pinned, 'DP-1', '/home/test').pinned, '/wall/photo.png');
    const invalid = api.updateDisplay(pinned, 'DP-1', { pinned: '/other/photo.png' }, '/home/test');
    assert.equal(api.configFor(invalid, 'DP-1', '/home/test').pinned, '/wall/photo.png');
    const moved = api.updateDisplay(pinned, 'DP-1', { folder: '/new' }, '/home/test');
    assert.equal(api.configFor(moved, 'DP-1', '/home/test').pinned, '');
  });
}
