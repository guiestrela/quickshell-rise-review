import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
for(const rel of ['versions/V1/panels/VolumePanel.qml','versions/V1/variants/V2/panels/VolumePanel.qml']) {
 const qml=fs.readFileSync(rel,'utf8');
 function fn(name){const start=qml.indexOf('    function '+name+'(');assert.ok(start>=0,name);let at=qml.indexOf('{',start),depth=1,end=at+1;for(;depth;end++){if(qml[end]==='{')depth++;if(qml[end]==='}')depth--;}return qml.slice(start,end);}
 test(rel+' source list excludes monitors and handles bad data',()=>{
  const c=vm.createContext({});vm.runInContext(fn('parseInputDevices'),c);
  const list=c.parseInputDevices(JSON.stringify([{name:'mic',description:'Microphone',monitor_of_sink:4294967295},{name:'out.monitor'},{name:'bad',monitor_of_sink:2}]));
  assert.equal(list.length,1);assert.equal(list[0].name,'mic');assert.equal(c.parseInputDevices('bad').length,0);
 });
 test(rel+' source selection uses argv and waits for readback',()=>{
  const c=vm.createContext({sources:[{name:'mic;literal'}],sourceSwitchPending:false,defaultSource:'old',sourceSwitchProc:{},defSourceProc:{running:false},sourceSwitchError:''});vm.runInContext(fn('setDefaultSource'),c);
  c.setDefaultSource({name:'unknown'});assert.equal(c.sourceSwitchPending,false);
  c.setDefaultSource({name:'mic;literal'});assert.equal(c.sourceSwitchPending,true);assert.deepEqual(Array.from(c.sourceSwitchProc.command),['timeout','4','pactl','set-default-source','mic;literal']);assert.equal(c.defaultSource,'old');
  c.sourceSwitchProc.running=false;c.setDefaultSource({name:'mic;literal'});assert.equal(c.defaultSource,'old');
 });
}
