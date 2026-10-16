import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync('versions/V1/variants/V2/Theme.qml','utf8');
const start=source.indexOf('    function parseGpuTelemetry(text)');
const end=source.indexOf('    function parseThermalTelemetry',start);
const context=vm.createContext({});
vm.runInContext(source.slice(start,end),context);
test('RPM numeric, stopped, unavailable and stale reset',()=>{
 for(const [raw,wanted] of [['1234',1234],['0',0],['',-1],['N/A',-1],['-3',-1],['1oops',-1]]){
 context.parseGpuTelemetry('sysfs|GPU||43|41|0|0|0|0|0||0|'+raw);
 assert.equal(context.gpuFanRpm,wanted);
 }
 context.parseGpuTelemetry('none|||||||||||');assert.equal(context.gpuFanRpm,-1);
 context.parseGpuTelemetry('sysfs|GPU||43|41|0|0|0|0|0||0');assert.equal(context.gpuFanRpm,-1);
});
test('panel displays zero RPM and hides unavailable',()=>{
 const panel=fs.readFileSync('versions/V1/variants/V2/panels/GpuPanel.qml','utf8');
 assert.match(panel,/root.gpuFanRpm >= 0 \? root.gpuFanRpm \+ " RPM" : ""/);
});
