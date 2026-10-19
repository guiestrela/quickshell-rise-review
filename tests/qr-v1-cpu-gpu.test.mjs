import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const read=p=>fs.readFileSync('versions/V1/'+p,'utf8');
test('V1 CPU owns no GPU sampler or GPU UI',()=>{
 const q=read('panels/CpuPanel.qml');assert.doesNotMatch(q,/gpuDriver|gpuUtil|nvidia-smi|CPU \\u00B7 GPU/);assert.match(q,/text: "CPU"/);assert.match(q,/FanRpmHistory/);
});
test('V1 GPU is registered, controllable and persisted without renumbering',()=>{
 const b=read('BarSlot.qml'),t=read('Theme.qml'),c=read('panels/ControlPanel.qml'),v=read('VariantRoot.qml');
 assert.match(b,/"G19": compGpu/);assert.match(b,/"G18": compDisplayManager/);assert.match(b,/gpu:\s+island.groupX\("G19"/);
 assert.match(c,/label: "GPU";.*root.modGpu/);assert.match(v,/GpuPanel \{ root: theme \}/);
 assert.match(t,/onGpuVisibleChanged: popupOpened\("gpuVisible"\)/);assert.match(t,/except !== "gpuVisible"/);
 assert.match(t,/wsField \+ 39/);assert.match(t,/\(modGpu\s+\? "1" : "0"\)/);
 assert.match(t,/gpuTelemetryProc/);assert.match(read('modules/GpuWidget.qml'),/root.gpuVisible = !root.gpuVisible/);
 assert.match(read('panels/GpuPanel.qml'),/root.gpuFanRpm/);
});

test('V1 default layout retains GPU and legacy split flags',()=>{
 const d=read('modules/V1Defaults.js');assert.match(d,/"G7", "G19"/);
 assert.match(read('BarSlot.qml'),/leftSplits.length - 1.*concat\(\[true\]\)/);
});

test('legacy order migration adds GPU once without resetting customized order', async()=>{
 const vm=await import('node:vm');const source=read('BarSlot.qml');
 const fn=source.slice(source.indexOf('    function applyOrder('),source.indexOf('    function saveOrder('));
 const calls=[];const registry=Object.fromEntries(Array.from({length:19},(_,i)=>['G'+(i+1),true]));
 const c=vm.createContext({leftModel:{count:8},centerModel:{count:1},rightModel:{count:10},registry,
 NordVpnLayout:{migrateV1Order:()=>null},WallpaperLayout:{migrateV1Order:()=>null},applyTo:(m,g)=>calls.push(Array.from(g))});
 vm.runInContext(fn,c);
 const old='G1,G2,G5,G4,G3,G6,G7|G8|G9,G10,G17,G14,G12,G13,G11,G16,G15,G18';
 c.applyOrder(old);assert.equal(calls.length,3);assert.deepEqual(calls[0],['G1','G2','G5','G4','G3','G6','G7','G19']);
 const current=calls.map(x=>x.join(',')).join('|');calls.length=0;c.applyOrder(current);assert.equal(calls.length,3);assert.equal(calls.flat().filter(x=>x==='G19').length,1);
 calls.length=0;c.applyOrder(old.replace('G7','G6'));assert.equal(calls.length,0);
});
test('ported V1 GPU parser reads real schema, zero and unavailable', async()=>{
 const vm=await import('node:vm');const q=read('Theme.qml');
 const f=q.slice(q.indexOf('    function parseGpuTelemetry('),q.indexOf('    Process {\n        id: gpuTelemetryProc'));
 const c=vm.createContext({gpuHistory:[]});vm.runInContext(f,c);
 c.parseGpuTelemetry('sysfs|GPU||69|40|0|0|0|0|0||0|1224');assert.equal(c.gpuPercent,69);assert.equal(c.gpuFanRpm,1224);
 c.parseGpuTelemetry('sysfs|GPU||0|40|0|0|0|0|0||0|0');assert.equal(c.gpuFanRpm,0);
 c.parseGpuTelemetry('none|||||||||||');assert.equal(c.gpuBackend,'');assert.equal(c.gpuFanRpm,-1);
});
