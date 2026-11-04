import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const source=read('variants/V1/BarSlot.qml');
const defaults=vm.runInNewContext(read('variants/V1/modules/V1Defaults.js').replace(/^\.pragma library\s*/m,'')+'\n defaultOrder()');
const nord=vm.runInNewContext(read('shared/logic/NordVpnLayout.js')+'\n({migrateV1Order,swapModels})');
const wallpaper=vm.runInNewContext(read('shared/logic/WallpaperLayout.js')+'\n({migrateV1Order})');
function model(ids) {return {rows:Array.from(ids),get count(){return this.rows.length},get(i){return {gid:this.rows[i]}},setProperty(i,key,value){this.rows[i]=value}}}
function state() {
 const c={leftModel:model(defaults.left),centerModel:model(defaults.center),rightModel:model(defaults.right),
  registry:Object.fromEntries(Array.from({length:22},(_,i)=>['G'+(i+1),true])),NordVpnLayout:nord,WallpaperLayout:wallpaper};
 vm.createContext(c);
 vm.runInContext(source.slice(source.indexOf('    function gidsOf('),source.indexOf('    function saveOrder(')),c);
 return c;
}
const old='G1,G2,G3,G4,G5,G6,G7,G19,G20,G21,G22|G8|G9,G10,G17,G14,G12,G13,G11,G16,G15,G18';
test('V1 expands legacy order in place and persists cross-region moves into empty slots',()=>{
 const c=state();c.applyOrder(old);
 assert.deepEqual(c.leftModel.rows.slice(0,11),old.split('|')[0].split(','));
 assert.deepEqual(c.centerModel.rows,['G8','','']);
 assert.equal(c.leftModel.rows.filter(x=>x==='').length,4);
 assert.equal(c.rightModel.rows.filter(x=>x==='').length,4);
 nord.swapModels(c.leftModel,c.centerModel,1,1);
 nord.swapModels(c.centerModel,c.rightModel,0,10); // Move the clock off the first center slot.
 const saved=c.serializeOrder();const restored=state();restored.applyOrder(saved);
 assert.equal(restored.serializeOrder(),saved);
 assert.equal(restored.centerModel.rows[1],'G2');
 assert.equal(restored.leftModel.rows[1],'');
 assert.equal(restored.rightModel.rows[10],'G8');
 for (const invalid of [saved.replace('G3','G4'),saved.replace('G3','G99'),saved.replace('G3','')]) {
  restored.applyOrder(invalid);assert.equal(restored.serializeOrder(),saved);
 }
});
test('V1 full defaults are a unique widget permutation with ten empty drop targets',()=>{
 const values=[...defaults.left,...defaults.center,...defaults.right];
 assert.equal(values.length,32);assert.equal(values.filter(x=>x==='').length,10);
 assert.equal(new Set(values.filter(Boolean)).size,22);
});
test('V2 permits twenty side slots and eight center slots without deleting occupied slots',()=>{
 const s=read('variants/V2/BarSlot.qml');
 const side=Number(s.match(/sideSlotCapacity: (\d+)/)[1]);
 const centerExtra=Number(s.match(/centerExtraSlotLimit: (\d+)/)[1]);
 assert.equal(side,20);assert.equal(centerExtra+1,8);
 const c={_orderLoaded:true,saves:0,extraSlotCount:(m,base)=>m.count-base,saveOrder(){}};
 vm.createContext(c);vm.runInContext(s.slice(s.indexOf('    function addExtraSlot('),s.indexOf('    function resetModel(')),c);
 const m={rows:Array.from({length:10},(_,i)=>({gid:'G'+(i+1),extra:false})),get count(){return this.rows.length},get(i){return this.rows[i]},append(row){this.rows.push({...row})},remove(i){this.rows.splice(i,1)}};
 for(let i=0;i<30;i++)c.addExtraSlot(m,10,side-10);
 assert.equal(m.count,20);
 m.rows[19].gid='G22';c.removeExtraSlot(m,19,10);assert.equal(m.count,20);
 m.rows[19].gid='';c.removeExtraSlot(m,19,10);assert.equal(m.count,19);
});
