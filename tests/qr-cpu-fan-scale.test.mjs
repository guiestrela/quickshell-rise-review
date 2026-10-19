import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
test('recent RPM scale shows small fluctuations without capacity claim',()=>{
 const q=fs.readFileSync('versions/V1/modules/FanRpmHistory.qml','utf8');
 const a=q.indexOf('    function recentScale('),b=q.indexOf('    function acceptSample(',a);assert.ok(a>=0);
 const c=vm.createContext({});vm.runInContext(q.slice(a,b),c);
 const points=[2571,2547,2566,2586];const fractions=points.map(x=>c.recentScale(points,x).fraction);
 assert.ok(Math.max(...fractions)-Math.min(...fractions)>0.5);
 const stable=c.recentScale([2500,2500],2500);assert.equal(stable.fraction,0.5);
 assert.equal(c.recentScale([0],0).fraction,0);
 assert.equal(c.recentScale([],-1).fraction,0);
 assert.match(q,/width:.*fan.rpmScale.fraction/);
 assert.match(q,/fan.rpmScale.low.*fan.rpmScale.high/);
});
