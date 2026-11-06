import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const read = p => readFileSync(new URL('../'+p, import.meta.url), 'utf8');
const helper = name => vm.runInNewContext(read('shared/logic/'+name+'.js')+'\n({migrateV2Entries})');
const source = read('variants/V2/BarSlot.qml');
const functions = source.slice(source.indexOf('    function parseRegion('),source.indexOf('    function saveOrder('));
function context() {
 const c = {
  leftBaseSlotCount:10, centerBaseSlotCount:1, rightBaseSlotCount:7,
  leftExtraSlotLimit:4, centerExtraSlotLimit:3, rightExtraSlotLimit:7,
  NordVpnLayout:helper('NordVpnLayout'), WallpaperLayout:helper('WallpaperLayout'),
  registry:Object.fromEntries(Array.from({length:23},(_,i)=>['G'+(i+1),true])),
  leftModel:model(),centerModel:model(),rightModel:model(),
  barSlot:{root:{trayWidgets:[]}}
 };
 vm.createContext(c);vm.runInContext(functions,c);return c;
}
function model() { return {rows:[],clear(){this.rows=[]},append(row){this.rows.push({...row})}}; }
const prior = 'B:G1,B:G2,B:G3,B:_,B:G5,B:G6,B:G4,B:G7,B:_,B:_|B:G8|B:G9,B:G10,B:G20,B:G14,B:G12,B:G13,B:G11,E:G18,E:G19,E:G16,E:G17,E:G15,E:G21';
const serialize = c => [c.leftModel,c.centerModel,c.rightModel].map(m=>m.rows.map(e=>(e.extra?'E:':'B:')+(e.gid||'_')).join(',')).join('|');
test('OneDrive appends to a full V2 right region and round-trips customized order',()=>{
 const c=context();assert.equal(c.applyOrder(prior),true);
 assert.equal(serialize(c),prior.replace('|B:G8|','|B:G8,E:G23|')+',E:G22');
 // A moved OneDrive and Display Manager remain in their selected slots.
 const customized=serialize(c).replace('B:_','B:G22').replace('E:G22','E:_')
  .replace('B:G1','B:G21').replace('E:G21','E:G1');
 assert.equal(c.applyOrder(customized),true);assert.equal(serialize(c),customized);
});
test('V2 restores standalone Indicators in the tray without adding a duplicate',()=>{
 const initial=context();assert.equal(initial.applyOrder(prior),true);
 const saved=serialize(initial).replace('E:G23','E:_')+'|G23';
 const restored=context();
 assert.equal(restored.applyOrder(saved),true,'Indicators already in the tray must not be migrated back into the center');
 assert.equal(serialize(restored)+'|'+restored.barSlot.root.trayWidgets.join(','),saved);
 assert.equal(restored.centerModel.rows.some(e=>e.gid==='G23'),false);
});
test('V2 still rejects Indicators duplicated between center and tray',()=>{
 const c=context();assert.equal(c.applyOrder(prior),true);
 const before=serialize(c);
 assert.equal(c.applyOrder(before+'|G23'),false);
 assert.equal(serialize(c),before);
 assert.equal(c.barSlot.root.trayWidgets.length,0);
});
test('OneDrive reuses a vacant slot without changing existing widgets or accepting duplicates',()=>{
 const c=context();const cached=prior.replace('B:_','B:G21').replace(',E:G21',',E:_');
 assert.equal(c.applyOrder(cached),true);
 assert.equal(c.leftModel.rows.filter(e=>e.gid==='G22').length,0);
 assert.equal(c.rightModel.rows.at(-1).gid,'G22');
 const result=serialize(c);
 assert.equal(c.applyOrder(result.replace('G22','G21')),false);
 assert.equal(serialize(c),result);
});
