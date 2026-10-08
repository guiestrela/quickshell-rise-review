import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../versions/V1/modules/V1Defaults.js', import.meta.url), 'utf8')
  .replace(/^\.pragma library\s*/m, '');
const defaults = vm.runInNewContext(`${source}\n({ defaultOrder, defaultSplits, defaultCompact, compactCacheFields, parseCompactCacheFields })`);

test('V1 default order matches the approved current layout', () => {
  assert.deepEqual(JSON.parse(JSON.stringify(defaults.defaultOrder())), {
    left: ['G1','G2','G3','G4','G5','G6','G7'],
    center: ['G8'],
    right: ['G9','G10','G17','G14','G12','G13','G11','G16','G15','G18']
  });
});

test('V1 default splits and compact modes match the approved snapshot', () => {
  assert.deepEqual(JSON.parse(JSON.stringify(defaults.defaultSplits())), {
    left: [true,true,true,true,true,true],
    right: [true,true,true,true,true,true,true,true],
    boundary: [true,true]
  });
  assert.deepEqual(JSON.parse(JSON.stringify(defaults.defaultCompact())), {
    compactNetwork: true, compactBattery: false, compactBrightness: false,
    compactCpu: true, compactMemory: true, compactVolume: true,
    compactBluetooth: true, compactPower: true, compactMpris: false,
    compactNordVpn: false, compactAi: false
  });
});

test('new compact cache fields append after legacy wsField+36', () => {
  for (const wsField of [4, 5]) {
    const prefix = Array(wsField + 37).fill('0');
    for (const [vpn, ai] of [[true,false], [false,true], [true,true], [false,false]]) {
      const serialized = prefix.concat(defaults.compactCacheFields(vpn, ai));
      assert.deepEqual(JSON.parse(JSON.stringify(defaults.parseCompactCacheFields(serialized, wsField))), {
        compactNordVpn: vpn, compactAi: ai
      });
    }
    assert.deepEqual(JSON.parse(JSON.stringify(defaults.parseCompactCacheFields(prefix, wsField))), {
      compactNordVpn: false, compactAi: false
    });
  }
});