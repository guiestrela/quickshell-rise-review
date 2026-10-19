import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const read=p=>fs.readFileSync('versions/V1/'+p,'utf8');
test('GPU full and compact display follow CPU, with percent in both modes',()=>{
 const q=read('modules/GpuWidget.qml');assert.match(q,/Canvas/);assert.match(q,/readonly property var history: root.gpuHistory/);assert.match(q,/text: "GPU"/);assert.match(q,/visible: root.compactGpu/);assert.match(q,/gpu-card.svg/);
 assert.equal((q.match(/text: String\(Math.min\(100, rootMod.percent\)\)/g)||[]).length,2);
});
test('GPU history comes from existing telemetry, bounded and cleared on unavailable',()=>{
 const q=read('Theme.qml'),a=q.indexOf('    function parseGpuTelemetry('),b=q.indexOf('    Process {\n        id: gpuTelemetryProc',a);
 const c=vm.createContext({gpuHistory:[]});vm.runInContext(q.slice(a,b),c);
 c.parseGpuTelemetry('sysfs|GPU||44|40|0|0|0|0|0||0|1224');assert.equal(c.gpuHistory[0],0.44);
 for(let i=0;i<40;i++)c.parseGpuTelemetry('sysfs|GPU||0|40|0|0|0|0|0||0|0');assert.equal(c.gpuHistory.length,30);assert.equal(c.gpuHistory[29],0);
 c.parseGpuTelemetry('none|||||||||||');assert.equal(c.gpuHistory.length,0);
});
