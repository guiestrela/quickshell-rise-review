import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
function library(name) {
 const source=readFileSync(new URL(`../shared/logic/${name}.js`,import.meta.url),'utf8').replace(/^\.pragma library\s*/m,'');
 const context=vm.createContext({}); vm.runInContext(source,context); return context;
}
test('tooltip ownership is independent of the active variant and caller',()=>{
 const api=library('ThemePanels'), first={}, second={}, a={}, b={};
 api.showTooltip(first,{},'CPU',20,10,30,a);
 api.showTooltip(second,{},'GPU',40,30,50,b);
 assert.equal(first.tooltipY,20); assert.equal(second.tooltipY,40);
 api.hideTooltip(first,{},b); assert.equal(first.tooltipShown,true);
 api.hideTooltip(first,{},a); assert.equal(first.tooltipShown,false);
 assert.equal(second.tooltipShown,true); assert.equal(second.tooltipOwner,b);
});
test('palette and compact helpers use the supplied owner, without shared state',()=>{
 const palette=library('ThemePalette'), values=library('ThemeValues');
 const a={color01:'#aa0000',color02:'#00aa00'},b={color01:'#0000aa',color02:'#aaaa00'};
 assert.equal(palette.paletteColor(a,{},'color02'),'#00aa00');
 assert.equal(palette.paletteColor(b,{},'color02'),'#aaaa00');
 assert.equal(values.evenW(a,{},13),14);
 assert.equal(values.aiPct(a,{},120),100);
 assert.equal(values.aiPct(b,{},-3),0);
});
test('AI window parsing invokes methods on the supplied owner',()=>{
 const api=library('ThemeAiUsage'), values=library('ThemeValues');
 const owner={aiWindowLabel:n=>api.aiWindowLabel(owner,{},n),aiPct:n=>values.aiPct(owner,{},n)};
 const data=api.aiCodexWindowFromCache(owner,{}, {minutes:300,utilization:0.43,reset:123});
 assert.equal(data.label,'5h'); assert.equal(data.pct,43); assert.equal(data.resetTs,123);
});
