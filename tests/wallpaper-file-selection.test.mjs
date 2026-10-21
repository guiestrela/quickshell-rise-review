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
const mediaPatterns = ['*.jpg', '*.jpeg', '*.png', '*.webp', '*.bmp', '*.gif', '*.mp4', '*.webm', '*.mkv', '*.mov', '*.avi'];

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

function extractRiseButton(source, objectName) {
  const name = source.indexOf(`objectName: "${objectName}"`);
  assert.notEqual(name, -1, `${objectName} must exist`);
  const start = source.lastIndexOf('RiseButton {', name);
  assert.notEqual(start, -1, `${objectName} must belong to a RiseButton`);
  return extractBlockAt(source, source.indexOf('{', start), objectName);
}

function extractFunction(source, name) {
  const start = source.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const open = source.indexOf('{', start);
  return source.slice(start, open) + `{${extractBlock(source, `function ${name}(`)}}`;
}

for (const [variant, relativePath] of variants) {
  test(`${variant}: confirmed chooser results apply only to their target outputs`, () => {
    const qml = readFileSync(join(repo, relativePath), 'utf8');
    const calls = [];
    const current = { 'DP-1': '/old/first.png', 'DP-2': '/old/second.png' };
    const profiles = { 'DP-1': { folder: '/old', pinned: '' }, 'DP-2': { folder: '/old', pinned: '' } };
    const panel = { selectedWallpaperError: '', root: {
      wallpaperManagerDisplay: 'DP-2',
      wallpaperManagerServiceApi: {
        scanInFlight: false, scanJobs: [], scanErrors: {},
        liveScreens: [{ name: 'DP-1' }, { name: 'DP-2' }],
        pathFor: name => current[name] || '',
      },
      wallpaperProfileFor: name => profiles[name] || {},
      setWallpaperProfile: (patch, name) => {
        calls.push({ patch: JSON.parse(JSON.stringify(patch)), name });
        profiles[name] = { ...profiles[name], ...patch };
        if (patch.pinned) current[name] = patch.pinned;
      },
    } };
    for (const name of ['localPathFromFileUrl', 'currentWallpaperMatches', 'verifySelectedWallpaperApplication', 'applyWallpaperSelection'])
      panel[name] = vm.runInNewContext(`(${extractFunction(qml, name)})`, { panel });
    const oldFirst = { ...profiles['DP-1'] };
    assert.equal(panel.applyWallpaperSelection('file', 'file:///new/Live%20Set/clip.MP4', 'DP-2'), true);
    assert.deepEqual(calls, [{ name: 'DP-2', patch: { folder: '/new/Live Set', mode: 'single', pinned: '/new/Live Set/clip.MP4' } }]);
    assert.deepEqual(profiles['DP-1'], oldFirst, 'a DP-2 selection must leave DP-1 intact');
    assert.equal(panel.selectedWallpaperApplied, true, 'renderer path readback confirms the file');
    assert.equal(panel.applyWallpaperSelection('folder', 'file:///new/Other%20Set', 'DP-2'), true);
    assert.deepEqual(calls.at(-1), { name: 'DP-2', patch: { folder: '/new/Other Set', mode: 'shuffle', pinned: '' } });
    assert.equal(panel.selectedWallpaperApplied, false, 'folder selection clears previous file status');

    calls.length = 0; panel.root.wallpaperManagerDisplay = 'all';
    assert.equal(panel.applyWallpaperSelection('file', 'file:///shared/chosen.mp4', 'all'), true);
    assert.deepEqual(calls.map(call => call.name), ['all', 'DP-1', 'DP-2']);
    assert.equal(panel.selectedWallpaperApplied, true);
    assert.equal(current['DP-1'], '/shared/chosen.mp4');
    assert.equal(current['DP-2'], '/shared/chosen.mp4');
    for (const [kind, url] of [['file', 'https://host/clip.mp4'], ['file', 'file:///bad.txt'], ['file', 'file:///bad%0A.mp4'], ['folder', 'file:///%ZZ'], ['unknown', 'file:///safe']]) {
      const before = calls.length;
      assert.equal(panel.applyWallpaperSelection(kind, url, 'all'), false);
      assert.equal(calls.length, before, 'invalid selection must never update a profile');
      assert.notEqual(panel.selectedWallpaperError, '');
    }
    panel.root.wallpaperManagerServiceApi.liveScreens = [];
    const before = calls.length;
    assert.equal(panel.applyWallpaperSelection('folder', 'file:///shared', 'all'), false);
    assert.equal(calls.length, before, 'no writes when no displays are connected');
  });
  test(`${variant}: stage a media file, then apply only to the selected display`, () => {
    const qml = readFileSync(join(repo, relativePath), 'utf8');
    const fileDialog = extractBlock(qml, 'WallpaperExternalPicker {');
    assert.match(fileDialog, /currentFolder:\s*panel\.profile\.folder === "" \? "file:\/\/\/home"/);
    assert.match(fileDialog, /if \(targetDisplay !== panel\.root\.wallpaperManagerDisplay\) return/,
      'ignore a picker result when its target display is no longer selected');
    assert.match(fileDialog, /panel\.applyWallpaperSelection\(selectionKind, selectionKind === "folder" \? selectedFolder : selectedFile, targetDisplay\)/);
    const helper = readFileSync(join(repo, 'scripts/rise-wallpaper-picker'), 'utf8');
    for (const pattern of mediaPatterns) assert.ok(helper.includes(`'${pattern.slice(1)}'`), `file filter must include ${pattern}`);
    assert.match(helper, /if response != confirm:\s*return 1/, 'cancel must not emit a selection');
    assert.match(helper, /dialog\.add_button\('Apply selection', confirm\)/, 'explicit confirmation is required');

    const chooseButton = extractRiseButton(qml, 'wallpaper-browse');
    assert.match(chooseButton, /wallpaperDialog\.targetDisplay = panel\.root\.wallpaperManagerDisplay/);
    assert.match(chooseButton, /wallpaperDialog\.currentFolder = folder === "" \? "file:\/\/\/home" : panel\.folderPickerSelectionUrl\(folder\)/);
    assert.match(chooseButton, /wallpaperDialog\.open\(\)/);
    assert.doesNotMatch(chooseButton, /setWallpaperProfile|applyWallpaperSelection/, 'opening the chooser must not apply anything');
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
