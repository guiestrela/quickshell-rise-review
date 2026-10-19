import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
test('fan samples: zero, invalid clearing, bounded history',()=>{
 const q=fs.readFileSync('versions/V1/modules/FanRpmHistory.qml','utf8');
 const a=q.indexOf('    function acceptSample(');const b=q.indexOf('    function refresh()',a);assert.ok(a>=0);
 const c=vm.createContext({rpm:-1,peakRpm:0,samples:[],trace:{requestPaint(){}}});vm.runInContext(q.slice(a,b),c);
 c.acceptSample('2500',0);assert.equal(c.rpm,2500);assert.equal(c.peakRpm,2500);
 c.acceptSample('0',0);assert.equal(c.rpm,0);
 for(let i=0;i<40;i++)c.acceptSample('2400',0);assert.equal(c.samples.length,30);
 c.acceptSample('2400',1);assert.equal(c.rpm,-1);assert.equal(c.samples.length,0);
 c.acceptSample('invalid',0);assert.equal(c.rpm,-1);
});
