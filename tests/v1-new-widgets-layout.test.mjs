import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const source=readFileSync(new URL('../variants/V1/BarSlot.qml',import.meta.url),'utf8');
const functionText=(name,next)=>source.slice(source.indexOf('    function '+name+'('),source.indexOf('    function '+next+'('));
test('new widgets migrate after the saved order and reject corrupt permutations',()=>{
 const applied=[];
 const context={leftModel:{count:10},centerModel:{count:1},rightModel:{count:10},
  registry:Object.fromEntries(Array.from({length:21},(_,i)=>['G'+(i+1),true])),
  NordVpnLayout:{migrateV1Order:()=>null},WallpaperLayout:{migrateV1Order:()=>null},
  applyTo:(model,ids)=>applied.push(Array.from(ids))};
 vm.createContext(context); vm.runInContext(functionText('applyOrder','saveOrder'),context);
 const old='G19,G7,G6,G5,G4,G3,G2,G1|G8|G18,G15,G16,G11,G13,G12,G14,G17,G10,G9';
 context.applyOrder(old);
 assert.deepEqual(applied[0],['G19','G7','G6','G5','G4','G3','G2','G1','G20','G21']);
 const saved=applied.map(a=>a.join(',')).join('|');applied.length=0;
 context.applyOrder(saved);assert.equal(applied.length,3);assert.equal(applied.flat().length,21);
 applied.length=0;context.applyOrder(old.replace('G7','G6'));assert.equal(applied.length,0);
});
test('new split slots preserve customized legacy boundaries',()=>{
 const context={leftSplits:Array(9).fill(true),rightSplits:Array(8).fill(true),boundarySplits:[true,true],
  _s2b:(s,n)=>Array.from({length:n},(_,i)=>s[i]==='1')};
 vm.createContext(context);vm.runInContext(functionText('applySplits','saveSplits'),context);
 context.applySplits('0101010|10101010|01');
 assert.deepEqual(Array.from(context.leftSplits),[false,true,false,true,false,true,false,false,false]);
 assert.deepEqual(Array.from(context.boundarySplits),[false,true]);
 context.applySplits('101010|10101010|10');
 assert.deepEqual(Array.from(context.leftSplits),[true,false,true,false,true,false,true,false,false]);
});
