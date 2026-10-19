import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
for(const path of ['versions/V1/modules/CpuWidget.qml','versions/V1/variants/V2/modules/CpuWidget.qml']){
 test(path+' CPU hover identifies CPU, usage and real temperature',()=>{
 const q=fs.readFileSync(path,'utf8');const a=q.indexOf('    readonly property string tooltipText: '),b=q.indexOf('\n\n',a);const expr=q.slice(a,b).split('tooltipText: ')[1].split('\n').slice(0,2).join('\n');
 assert.equal(vm.runInNewContext(expr,{percent:43,root:{cpuTemperatureC:41}}),'CPU · 43% · 41°C');
 assert.equal(vm.runInNewContext(expr,{percent:43,root:{cpuTemperatureC:0}}),'CPU · 43%');
 });
}
test('V1 CPU detail reads and clears temperature, polls while widget visible',()=>{
 const q=fs.readFileSync('versions/V1/Theme.qml','utf8'),a=q.indexOf('    function parseCpuDetail('),b=q.indexOf('    function parseCpuTopProcesses(',a);
 const c=vm.createContext({});vm.runInContext(q.slice(a,b),c);c.parseCpuDetail('2400|4400|balance|powersave|0|41');assert.equal(c.cpuTemperatureC,41);
 c.parseCpuDetail('2400|4400|balance|powersave|0|');assert.equal(c.cpuTemperatureC,0);
 assert.match(q,/running: theme.modCpu \|\| theme.cpuVisible[\s\S]*?cpuDetailProc.running/);
});
