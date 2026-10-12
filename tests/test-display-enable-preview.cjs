const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const src=fs.readFileSync(path.join(__dirname,'../versions/V1/modules/DisplayManagerController.qml'),'utf8');
function method(name){let start=src.indexOf('    function '+name+'('),open=src.indexOf('{',start),depth=1,i=open+1;for(;depth;i++){if(src[i]==='{')depth++;if(src[i]==='}')depth--;}return src.slice(start,i);}
const a={name:'A',width:1000,height:1000,x:0,y:0,scale:1,transform:0,refreshRate:60,disabled:false,mirrorOf:'none'},b={...a,name:'B',disabled:true};
const c={monitors:[a,b],drafts:{A:{...a,x:1000}},positions:{},savedDisplayStates:{B:{...b,disabled:false}},displayStateReady:true,busy:false,loading:false,rollbackPending:false,error:'',calls:[]};c.monitor=n=>c.monitors.find(m=>m.name===n);c.safeMonitor=n=>/^[A-Za-z0-9_.:-]{1,64}$/.test(n);c.applyMonitor=(...args)=>{c.calls.push(args);return true};vm.createContext(c);
for(const name of ['validSavedDisplayState','previewMonitor','stageMonitor','enableMonitor'])vm.runInContext(method(name),c);
Object.defineProperty(c,'previewMonitors',{get:()=>c.monitors.map(m=>c.previewMonitor(m.name))});
assert.equal(c.enableMonitor('B',true),true,'Pending move of A frees the original saved B position');assert.equal(c.drafts.B.x,0);assert.equal(c.drafts.B.disabled,false);assert.equal(c.calls.length,0,'Enable must remain a preview');
c.drafts={};assert.equal(c.enableMonitor('B',true),false,'Saved position actually occupied in the preview must still be blocked');assert.equal(c.calls.length,0);
console.log('ENABLE_PREVIEW_PASS pending peer position respected, original B position preserved, actual preview overlap blocked, zero dispatch');
