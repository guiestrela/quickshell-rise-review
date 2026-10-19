import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const read=p=>fs.readFileSync('versions/V1/'+p,'utf8');
test('GPU compact mode is wired to UI, persistence and reset',()=>{
 const q=read('Theme.qml'),w=read('modules/GpuWidget.qml'),c=read('panels/ControlPanel.qml');
 assert.match(w,/visible: !root.compactGpu/);
 assert.match(c,/label: "GPU";\s+active: root.compactGpu;.*root.compactGpu = !root.compactGpu/);
 assert.match(q,/wsField \+ 40/);assert.match(q,/onCompactGpuChanged:/);assert.match(q,/compactGpu = defaults.compactGpu/);
 const defaults=vm.runInNewContext(read('modules/V1Defaults.js').replace(/^\.pragma library\s*/m,'')+'\ndefaultCompact()');assert.equal(defaults.compactGpu,false);
});
