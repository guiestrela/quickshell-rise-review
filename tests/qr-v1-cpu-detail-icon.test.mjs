import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const read=p=>fs.readFileSync('versions/V1/'+p,'utf8');
function fn(q,name){const a=q.indexOf('    function '+name+'(');assert.ok(a>=0,name);let b=q.indexOf('{',a),d=1,e=b+1;for(;d;e++){if(q[e]==='{')d++;if(q[e]==='}')d--;}return q.slice(a,e)}
test('V1 GPU uses same SVG icon as V2',()=>{
 assert.match(read('modules/GpuWidget.qml'),/gpu-card.svg/);
 assert.equal(read('assets/gpu-card.svg'),read('variants/V2/assets/gpu-card.svg'));
});
test('V1 detailed CPU parses model, clock, load and top processes',()=>{
 const q=read('Theme.qml'),c=vm.createContext({});
 for(const f of ['parseCpuInfo','parseSystemLoad','parseCpuDetail','parseCpuTopProcesses'])vm.runInContext(fn(q,f),c);
 c.parseCpuInfo('processor : 0\nmodel name : Example CPU\nphysical id : 0\ncore id : 0\n\nprocessor : 1\nphysical id : 0\ncore id : 0');assert.equal(c.cpuThreadCount,2);assert.equal(c.cpuCoreCount,1);
 c.parseCpuDetail('2400|4400|balance_performance|powersave|0');assert.equal(c.cpuClockMHz,2400);
 c.parseSystemLoad('1.0 2.0 3.0');assert.equal(c.systemLoad15,3);
 c.parseCpuTopProcesses('ps 9\nworker 4.5\nworker-b 3.2');assert.equal(c.cpuTopProcesses.length,2);assert.equal(c.cpuTopProcesses[0].name,'worker');
 assert.match(read('panels/CpuPanel.qml'),/TOP PROCESSES/);assert.match(read('panels/CpuPanel.qml'),/root.cpuModelName/);assert.match(read('panels/CpuPanel.qml'),/FanRpmHistory/);
});
test('detailed CPU telemetry preserves V1 widget history',()=>{
 const q=read('Theme.qml');const c=vm.createContext({_systemCpuPrevTotal:-1,_systemCpuPrevIdle:-1,_systemCpuPrevUser:-1,_systemCpuPrevSystem:-1,_systemCpuPrevIoWait:-1,systemCpuHistory:[],systemCpuMaxSamples:30});vm.runInContext(fn(q,'parseSystemCpu'),c);
 c.parseSystemCpu('cpu  100 0 50 850 0 0 0 0');c.parseSystemCpu('cpu  130 0 70 900 0 0 0 0');assert.equal(c.systemCpuPercent,50);assert.equal(c.systemCpuHistory.length,1);assert.equal(c.systemCpuHistory[0],0.5);assert.equal(c.systemCpuUserPercent,30);
});
