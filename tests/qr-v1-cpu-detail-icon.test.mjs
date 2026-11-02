import { readQmlSource } from './qml-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const read=p=>readQmlSource('variants/V1/'+p,'utf8');
function fn(q,name){const a=q.indexOf('    function '+name+'(');assert.ok(a>=0,name);let b=q.indexOf('{',a),d=1,e=b+1;for(;d;e++){if(q[e]==='{')d++;if(q[e]==='}')d--;}return q.slice(a,e)}
test('V1 GPU uses same SVG icon as V2',()=>{
 assert.match(read('modules/GpuWidget.qml'),/gpu-card.svg/);
 for (const variant of ['V1','V2']) {
  const widget = readQmlSource(`variants/${variant}/modules/GpuWidget.qml`, 'utf8');
  assert.match(widget, /Qt\.resolvedUrl\("\.\.\/\.\.\/\.\.\/shared\/assets\/gpu-card\.svg"\)/);
 }
 assert.match(readQmlSource('shared/assets/gpu-card.svg','utf8'), /<svg/);
});
test('V1 detailed CPU parses model, clock, load and top processes',()=>{
 const q=readQmlSource('shared/services/SystemTelemetry.qml','utf8'),c=vm.createContext({});
 for(const f of ['parseCpuInfo','parseSystemLoad','parseCpuDetail','parseCpuTopProcesses'])vm.runInContext(fn(q,f),c);
 c.parseCpuInfo('processor : 0\nmodel name : Example CPU\nphysical id : 0\ncore id : 0\n\nprocessor : 1\nphysical id : 0\ncore id : 0');assert.equal(c.cpuThreadCount,2);assert.equal(c.cpuCoreCount,1);
 c.parseCpuDetail('2400|4400|balance_performance|powersave|0');assert.equal(c.cpuClockMHz,2400);
 c.parseSystemLoad('1.0 2.0 3.0');assert.equal(c.systemLoad15,3);
 c.parseCpuTopProcesses('ps 9\nworker 4.5\nworker-b 3.2');assert.equal(c.cpuTopProcesses.length,2);assert.equal(c.cpuTopProcesses[0].name,'worker');
 assert.match(readQmlSource('shared/panels/CpuPanel.qml','utf8'),/TOP PROCESSES/);assert.match(readQmlSource('shared/panels/CpuPanel.qml','utf8'),/root.cpuModelName/);assert.match(readQmlSource('shared/panels/CpuPanel.qml','utf8'),/FanRpmHistory/);
});
test('detailed CPU telemetry preserves V1 widget history',()=>{
 const q=readQmlSource('shared/services/SystemTelemetry.qml','utf8');const c=vm.createContext({_systemCpuPrevTotal:-1,_systemCpuPrevIdle:-1,_systemCpuPrevUser:-1,_systemCpuPrevSystem:-1,_systemCpuPrevIoWait:-1,systemCpuHistory:[],systemCpuMaxSamples:30});vm.runInContext(fn(q,'parseSystemCpu'),c);
 c.parseSystemCpu('cpu  100 0 50 850 0 0 0 0');c.parseSystemCpu('cpu  130 0 70 900 0 0 0 0');assert.equal(c.systemCpuPercent,50);assert.equal(c.systemCpuHistory.length,1);assert.equal(c.systemCpuHistory[0],0.5);assert.equal(c.systemCpuUserPercent,30);
});
