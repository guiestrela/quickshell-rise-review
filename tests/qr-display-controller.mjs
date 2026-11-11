import { readQmlSource } from './qml-source.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const file = new URL('../shared/controllers/DisplayManagerController.qml', import.meta.url);
const source = readQmlSource(file, 'utf8');
const context = vm.createContext({controller:null,theme:{displayManagerAutoWorkspaces:true},hasDrafts:false,helperPath:'/rise/helper',guardPath:'/rise/guard',confirmationSeconds:15,rollbackPending:false,busy:false,loading:false,error:'',actionProc:{},monitors:[],positions:{},extraQueue:[],workspaceLoading:false,workspaceCommitPending:false,workspaceAssignments:{},workspaceOverrides:{},selectedMonitor:'DP-1',console});
context.controller=context;
for (const match of source.matchAll(/    function (\w+)\([^\n]*\) \{/g)) {
  const start=match.index+4; let cursor=source.indexOf('{',start), depth=1;
  while(depth && ++cursor<source.length) { if(source[cursor]==='{')depth++; else if(source[cursor]==='}')depth--; }
  vm.runInContext(source.slice(start,cursor+1),context);
}
context.monitors=[{name:'DP-1',width:2560,height:1440,refreshRate:59.95,scale:1,x:0,y:0,mirrorOf:'none'}];
assert.equal(context.applyMonitor('DP-1','2560x1440@59.95Hz',200,-100,1,0,'none'),true,'native Hyprland modes must work');
assert.equal(context.guardedAction,true,'layout changes retain the rollback guard');
assert.deepEqual(Array.from(context.actionProc.command).slice(0,2), ['/rise/guard','--apply']);
assert.equal(JSON.parse(context.actionProc.command[2])[1],'monitor');
context.busy=false;
assert.equal(context.applyMonitor('DP-1','2560x1440@59.95',0,0,1,0,'DP-1'),false,'self-mirror must be rejected before dispatch');
assert.equal(context.applyMonitor('DP-1','2560x1440@59.95',999999,0,1,0,'none'),false,'position bounds must be rejected');
context.monitors[0].disabled=false;
assert.equal(context.disableMonitor('DP-1'),false,'must not disable the last active monitor');
context.monitors.push({name:'DP-2',width:1920,height:1080,refreshRate:60,scale:1,x:2560,y:0,mirrorOf:'none',disabled:true});
context.theme={displayManagerAutoWorkspaces:true};
context.selectedMonitor='DP-1';
context.busy=false;
assert.equal(context.saveLayout(),true);
const payload=JSON.parse(context.actionProc.command.at(-1));
assert.equal(payload.monitors[0].mode,'2560x1440@59.95','saving must preserve fractional refresh');
assert.equal(payload.monitors[1].disabled,true,'saving must preserve disabled state');
assert.ok(payload.workspaces.every(w=>w.monitor==='DP-1'),'disabled outputs must not get workspaces');
console.log('DISPLAY_CONTROLLER_DISPATCH_PASS');
