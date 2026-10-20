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

function extractBlock(source, marker) {
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, `${marker} must exist`);
  return extractBlockAt(source, source.indexOf('{', start), marker);
}

function extractBlockAt(source, open, marker) {
  assert.notEqual(open, -1, `${marker} must open a block`);
  let depth = 0;
  for (let index = open; index < source.length; index += 1) {
    if (source[index] === '{') depth += 1;
    if (source[index] === '}' && --depth === 0) return source.slice(open + 1, index);
  }
  assert.fail(`${marker} has an unterminated block`);
}

function extractFunction(source, name) {
  const start = source.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const open = source.indexOf('{', start);
  return source.slice(start, open) + `{${extractBlock(source, `function ${name}(`)}}`;
}

for (const [variant, relativePath] of variants) {
  test(`${variant}: stage a media file, then apply only to the selected display`, () => {
    const qml = readFileSync(join(repo, relativePath), 'utf8');
    // The chooser now runs outside the shell to isolate toolkit crashes.
    assert.match(qml, /WallpaperExternalPicker\s*\{/);
    const picker = extractBlock(qml, 'WallpaperExternalPicker {');
    assert.match(picker, /targetDisplay !== panel\.root\.wallpaperManagerDisplay/);
    assert.match(picker, /panel\.applyWallpaperSelection\(/);
    assert.match(qml, /wallpaperDialog\.open\(\)/);

    assert.ok(qml.includes('var paths = display === "all" ? service.pool : service.poolFor(display)'), 'validate against the selected output pool');

    const localPathFromFileUrl = vm.runInNewContext(`(${extractFunction(qml, 'localPathFromFileUrl')})`);
    const isMediaFileInFolder = vm.runInNewContext(`(${extractFunction(qml, 'isMediaFileInFolder')})`);
    assert.equal(localPathFromFileUrl('file:///home/guiestrela/Wallpapers/Live%20Set/clip%20one.MP4'), '/home/guiestrela/Wallpapers/Live Set/clip one.MP4');
    assert.equal(localPathFromFileUrl('not-a-local-file-url'), '');
    assert.equal(isMediaFileInFolder('/home/guiestrela/Wallpapers/horizontalLive/clip.mp4', '/home/guiestrela/Wallpapers/horizontalLive'), true);
    assert.equal(isMediaFileInFolder('/home/guiestrela/Wallpapers/horizontalLive/nested/still.PNG', '/home/guiestrela/Wallpapers/horizontalLive'), true);
    assert.equal(isMediaFileInFolder('/home/guiestrela/Wallpapers/horizontalLive-neighbor/clip.mp4', '/home/guiestrela/Wallpapers/horizontalLive'), false);
    assert.equal(isMediaFileInFolder('/home/guiestrela/Wallpapers/horizontalLive/not-media.txt', '/home/guiestrela/Wallpapers/horizontalLive'), false);

    const calls = [];
    const panel = {
      profile: { folder: '/home/guiestrela/Wallpapers/horizontalLive' },
      selectedWallpaperFile: '',
      selectedWallpaperError: '',
      root: {
        wallpaperManagerDisplay: 'DP-2',
        setWallpaperProfile: (patch, output) => calls.push({ patch, output }),
      },
      localPathFromFileUrl,
      isMediaFileInFolder,
      selectedWallpaperCanApply: true,
    };
    const stageWallpaperFile = vm.runInNewContext(`(${extractFunction(qml, 'stageWallpaperFile')})`, { panel });
    assert.equal(stageWallpaperFile('file:///home/guiestrela/Wallpapers/horizontalLive/clip.mp4'), true);
    assert.equal(panel.selectedWallpaperFile, '/home/guiestrela/Wallpapers/horizontalLive/clip.mp4');
    assert.equal(calls.length, 0, 'staging a file must not apply it');
    assert.equal(stageWallpaperFile('file:///home/guiestrela/Wallpapers/outside.mp4'), false);
    assert.notEqual(panel.selectedWallpaperError, '');
    assert.equal(calls.length, 0, 'an invalid selection must not apply it');
    assert.equal(stageWallpaperFile('file:///home/guiestrela/Wallpapers/horizontalLive/clip.mp4'), true);

    const selectedPath = '/home/guiestrela/Wallpapers/horizontalLive/clip.mp4';
    const savedProfile = { folder: '/home/guiestrela/Wallpapers/horizontalLive', pinned: '' };
    const currentByOutput = { 'DP-2': selectedPath };
    panel.root.wallpaperManagerServiceApi = {
      scanInFlight: false,
      liveScreens: [{ name: 'DP-1' }, { name: 'DP-2' }],
      pathFor: (name) => currentByOutput[name] || '',
    };
    panel.root.setWallpaperProfile = (patch, output) => {
      calls.push({ patch, output });
      Object.assign(savedProfile, patch);
    };
    panel.root.wallpaperProfileFor = () => savedProfile;
    panel.currentWallpaperMatches = vm.runInNewContext(`(${extractFunction(qml, 'currentWallpaperMatches')})`, { panel });
    panel.verifySelectedWallpaperApplication = vm.runInNewContext(`(${extractFunction(qml, 'verifySelectedWallpaperApplication')})`, { panel });
    const applySelectedWallpaper = vm.runInNewContext(`(${extractFunction(qml, 'applySelectedWallpaper')})`, { panel });
    assert.equal(applySelectedWallpaper(), true);
    assert.deepEqual(JSON.parse(JSON.stringify(calls)), [{
      patch: { mode: 'single', pinned: '/home/guiestrela/Wallpapers/horizontalLive/clip.mp4' },
      output: 'DP-2',
    }]);
    assert.equal(panel.selectedWallpaperApplied, true);
    currentByOutput['DP-2'] = '/home/guiestrela/Wallpapers/horizontalLive/other.mp4'; // Next image
    panel.verifySelectedWallpaperApplication();
    assert.equal(panel.selectedWallpaperApplied, false, 'Next must invalidate the stale Applied status');
    assert.equal(panel.selectedWallpaperApplying, false);
    assert.equal(panel.selectedWallpaperError, '', 'an intentional Next is not an Apply failure');

    const allCalls = [];
    const allSavedProfile = { folder: '/home/guiestrela/Wallpapers/horizontalLive', pinned: '' };
    const allCurrentByOutput = { 'DP-1': selectedPath, 'DP-2': selectedPath };
    const allPanel = {
      selectedWallpaperCanApply: true,
      selectedWallpaperFile: selectedPath,
      selectedWallpaperApplied: false,
      selectedWallpaperApplying: false,
      selectedWallpaperError: '',
      root: {
        wallpaperManagerDisplay: 'all',
        wallpaperManagerServiceApi: {
          scanInFlight: false,
          liveScreens: [{ name: 'DP-1' }, { name: 'DP-2' }],
          pathFor: (name) => allCurrentByOutput[name] || '',
        },
        setWallpaperProfile: (patch, output) => {
          allCalls.push({ patch, output });
          Object.assign(allSavedProfile, patch);
        },
        wallpaperProfileFor: () => allSavedProfile,
      },
    };
    allPanel.currentWallpaperMatches = vm.runInNewContext(`(${extractFunction(qml, 'currentWallpaperMatches')})`, { panel: allPanel });
    allPanel.verifySelectedWallpaperApplication = vm.runInNewContext(`(${extractFunction(qml, 'verifySelectedWallpaperApplication')})`, { panel: allPanel });
    const applyAll = vm.runInNewContext(`(${extractFunction(qml, 'applySelectedWallpaper')})`, { panel: allPanel });
    assert.equal(applyAll(), true);
    assert.deepEqual(JSON.parse(JSON.stringify(allCalls)), [{
      patch: { mode: 'single', pinned: '/home/guiestrela/Wallpapers/horizontalLive/clip.mp4' },
      output: 'all',
    }]);
    assert.equal(allPanel.selectedWallpaperApplied, true);
    allCurrentByOutput['DP-2'] = '/home/guiestrela/Wallpapers/horizontalLive/other.mp4';
    allPanel.verifySelectedWallpaperApplication();
    assert.equal(allPanel.selectedWallpaperApplied, false, 'all must invalidate when any screen diverges');
    assert.equal(allPanel.selectedWallpaperError, '', 'an intentional per-screen change is not an Apply failure');

    const pendingCurrentByOutput = { 'DP-1': '/fixture/A/old.mp4' };
    const pendingProfile = { folder: '/fixture/A', pinned: '' };
    const pendingService = {
      scanInFlight: false,
      liveScreens: [{ name: 'DP-1' }],
      pathFor: (name) => pendingCurrentByOutput[name] || '',
    };
    const pendingPanel = {
      selectedWallpaperCanApply: true,
      selectedWallpaperFile: '/fixture/A/chosen.mp4',
      selectedWallpaperApplied: false,
      selectedWallpaperApplying: false,
      selectedWallpaperScanStarted: false,
      selectedWallpaperError: '',
      root: {
        wallpaperManagerDisplay: 'DP-1',
        wallpaperManagerServiceApi: pendingService,
        setWallpaperProfile: (patch) => {
          Object.assign(pendingProfile, patch);
          pendingPanel.verifySelectedWallpaperApplication(); // Theme profile signal precedes scanFolder().
          pendingService.scanInFlight = true;
          pendingPanel.selectedWallpaperScanStarted = true;
        },
        wallpaperProfileFor: () => pendingProfile,
      },
    };
    pendingPanel.currentWallpaperMatches = vm.runInNewContext(`(${extractFunction(qml, 'currentWallpaperMatches')})`, { panel: pendingPanel });
    pendingPanel.verifySelectedWallpaperApplication = vm.runInNewContext(`(${extractFunction(qml, 'verifySelectedWallpaperApplication')})`, { panel: pendingPanel });
    const applyPending = vm.runInNewContext(`(${extractFunction(qml, 'applySelectedWallpaper')})`, { panel: pendingPanel });
    assert.equal(applyPending(), true);
    assert.equal(pendingPanel.selectedWallpaperApplying, true);
    assert.equal(pendingPanel.selectedWallpaperApplied, false, 'do not say Applied before the scanner confirms the current path');
    pendingService.scanInFlight = false;
    pendingCurrentByOutput['DP-1'] = '/fixture/A/chosen.mp4';
    pendingPanel.verifySelectedWallpaperApplication();
    assert.equal(pendingPanel.selectedWallpaperApplying, false);
    assert.equal(pendingPanel.selectedWallpaperApplied, true);

    const rejectedPanel = {
      selectedWallpaperCanApply: true,
      selectedWallpaperFile: '/fixture/A/chosen.mp4',
      selectedWallpaperApplied: false,
      selectedWallpaperError: '',
      root: {
        wallpaperManagerDisplay: 'DP-1',
        setWallpaperProfile: () => {},
        wallpaperProfileFor: () => ({ folder: '/fixture/A', pinned: '' }),
      },
    };
    const rejectUnpinned = vm.runInNewContext(`(${extractFunction(qml, 'applySelectedWallpaper')})`, { panel: rejectedPanel });
    assert.equal(rejectUnpinned(), false, 'do not report success when profile readback discarded the pin');
    assert.equal(rejectedPanel.selectedWallpaperApplied, false);
    assert.notEqual(rejectedPanel.selectedWallpaperError, '');
  });
}
