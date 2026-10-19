import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
test('external GPU RPM reuses telemetry without starting CPU reader',()=>{
 const q=fs.readFileSync('versions/V1/modules/FanRpmHistory.qml','utf8');
 const a=q.indexOf('    function refresh()'),b=q.indexOf('    onActiveChanged:',a);
 const seen=[];const ctx=vm.createContext({active:true,externalSource:true,externalRpm:1224,reader:{running:false},acceptSample:(x,c)=>seen.push([x,c])});vm.runInContext(q.slice(a,b),ctx);
 ctx.refresh();assert.equal(ctx.reader.running,false);assert.deepEqual(seen,[[1224,0]]);
 ctx.externalRpm=-1;ctx.refresh();assert.deepEqual(seen[1],['',1]);
 ctx.active=false;ctx.refresh();assert.equal(seen.length,2);
 ctx.active=true;ctx.externalSource=false;ctx.refresh();assert.equal(ctx.reader.running,true);
 const panel=fs.readFileSync('versions/V1/variants/V2/panels/GpuPanel.qml','utf8');
 assert.match(panel,/externalRpm: root.gpuFanRpm/);assert.match(panel,/externalSource: true/);
});
