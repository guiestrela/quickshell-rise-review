import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
function library(name) {
 const source=readFileSync(new URL(`../shared/logic/${name}.js`,import.meta.url),'utf8').replace(/^\.pragma library\s*/m,'');
 const context=vm.createContext({}); vm.runInContext(source,context); return context;
}
test('quiet state updates DND and malformed state preserves the last known value',()=>{
 const api=library('ThemeIntegrations'), owner={notifSilenced:false};
 assert.equal(api.parseNotificationsState(owner,{},'{"dnd":true}'),true);
 assert.equal(owner.notifSilenced,true);
 for (const raw of ['{','null','[]','{}','{"dnd":"false"}']) {
  assert.equal(api.parseNotificationsState(owner,{},raw),false);
  assert.equal(owner.notifSilenced,true);
 }
 api.parseNotificationsState(owner,{},'{"dnd":false}');
 assert.equal(owner.notifSilenced,false);
});
test('Omarchy per-monitor workspace focus uses the custom dispatch expression',()=>{
 const api=library('ThemeIntegrations'), calls=[];
 const owner={omarchyPerMonitorWorkspaces:true,hyprUsesLua:true};
 const env={Hyprland:{dispatch:value=>calls.push(['hyprland',value])},
  Quickshell:{execDetached:argv=>calls.push(['exec',argv])}};
 api.gotoWorkspace(owner,env,2,'DP-2');
 assert.equal(JSON.stringify(calls),JSON.stringify([['exec',['hyprctl','dispatch','o.workspaces.focus(2, "DP-2")']]]));
 owner.omarchyPerMonitorWorkspaces=false;
 api.gotoWorkspace(owner,env,2,'DP-2');
 assert.equal(JSON.stringify(calls[1]),JSON.stringify(['exec',['hyprctl','dispatch','hl.dsp.focus({ workspace = 2 })']]));
});
test('Display Manager routes Omarchy Lua expressions through hyprctl dispatch',()=>{
 const source=readFileSync(new URL('../shared/controllers/DisplayManagerController.qml',import.meta.url),'utf8');
 const start=source.indexOf('    function dispatchHyprlandExpression(');
 const open=source.indexOf('{',start);let depth=1,end=open+1;
 for(;depth&&end<source.length;end++){if(source[end]==='{')depth++;if(source[end]==='}')depth--;}
 const calls=[],context=vm.createContext({Quickshell:{execDetached:argv=>calls.push(argv)}});
 vm.runInContext(source.slice(start,end),context);
 context.dispatchHyprlandExpression('o.workspaces.focus(2, "DP-2")');
 assert.equal(JSON.stringify(calls),JSON.stringify([['hyprctl','dispatch','o.workspaces.focus(2, "DP-2")']]));
 assert.match(source,/controller\.dispatchHyprlandExpression\(\s*"o\.workspaces\.focus\(/);
 assert.match(source,/controller\.dispatchHyprlandExpression\("hl\.dsp\.focus\(\{ workspace = /);
});
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
