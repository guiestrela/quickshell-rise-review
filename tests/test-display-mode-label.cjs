const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const src=fs.readFileSync(path.join(__dirname,'../versions/V1/panels/DisplayManagerPanel.qml'),'utf8');
const live={name:'DP-1',width:2560,height:1440,refreshRate:154.998,availableModes:['2560x1440@155.00Hz','1920x1080@60.00Hz']};
const legacyOptions=['preferred',...live.availableModes];
// Prove the production selector resolves a real mode, not the legacy fallback.
const context={controller:{savedDisplayStates:{}},panel:{selectedDisplay:live},model:legacyOptions};vm.createContext(context);
const old=src.match(/currentIndex: \{ var m = panel.selectedDisplay; return m && m.mode \? Math.max\(0, model.indexOf\(m.mode\)\) : 0 \}/);
if(old){const code=old[0].slice('currentIndex: '.length);const index=vm.runInContext('(function()'+code+')()',context);assert.notEqual(legacyOptions[index],'preferred','Actual active dimensions must be shown instead of preferred');}
function method(name){let start=src.indexOf('    function '+name+'(');assert.ok(start>=0,'Missing mode helper '+name);let open=src.indexOf('{',start),depth=1,i=open+1;for(;depth;i++){if(src[i]==='{')depth++;if(src[i]==='}')depth--;}return src.slice(start,i);}
for(const name of ['displayMode','sameMode','modeOptions','modeIndex'])vm.runInContext(method(name),context);
let modes=context.modeOptions(live);assert.equal(modes[context.modeIndex(live,modes)],'2560x1440@155.00Hz');
const draft={...live,mode:'1920x1080@60.00'};modes=context.modeOptions(draft);assert.equal(modes[context.modeIndex(draft,modes)],'1920x1080@60.00Hz','Hz suffix must not reset pending selection to preferred');
const preferred={...live,mode:'preferred'};modes=context.modeOptions(preferred);assert.equal(modes[context.modeIndex(preferred,modes)],'preferred','Explicit preferred draft stays intentional until Apply/readback');
const absent={...live,availableModes:['1920x1080@60Hz']};modes=context.modeOptions(absent);assert.equal(modes[context.modeIndex(absent,modes)],'2560x1440@154.998','Unlisted actual mode must still be shown');
const other={...live,name:'DP-2',width:1920,height:1080,refreshRate:60};modes=context.modeOptions(other);assert.equal(modes[context.modeIndex(other,modes)],'1920x1080@60.00Hz');
context.controller.savedDisplayStates['DP-2']={width:2560,height:1440,refreshRate:155};assert.equal(context.displayMode({name:'DP-2',disabled:true,width:0,height:0,refreshRate:0}),'2560x1440@155');
console.log('MODE_LABEL_PASS live mode, Hz/decimal normalization, pending choice, explicit preferred, absent advertised mode, monitor switch and remembered disabled mode');
