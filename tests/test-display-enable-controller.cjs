const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../versions/V1/modules/DisplayManagerController.qml'),'utf8');
const context={monitors:[],positions:{},savedDisplayStates:{},displayStateReady:true,calls:[],error:''};context.monitor=name=>context.monitors.find(m=>m.name===name);context.applyMonitor=(...args)=>{context.calls.push(args);return true};vm.createContext(context);vm.runInContext(source.slice(source.indexOf('    function enableMonitor(name)'),source.indexOf('    function saveLayout()')),context);
const active={name:'DP-1',width:2560,height:1440,x:0,y:560,scale:1,transform:0,disabled:false,mirrorOf:'none',refreshRate:155};
const off={name:'DP-2',width:2560,height:1440,x:0,y:0,scale:1,transform:0,disabled:true,mirrorOf:'none',refreshRate:59.951};
function reset(monitors,positions={}){context.monitors=monitors;context.positions=positions;context.calls.length=0;context.error='';}
reset([active,off]);assert.equal(context.enableMonitor('DP-2'),true);assert.deepEqual(context.calls[0],['DP-2','2560x1440@59.951',2560,0,1,0,'none'],'Enable must avoid the actual overlapping 0,0 and preserve the existing mode');
reset([active,{...off,x:2560,y:0,scale:1.5,transform:1}]);context.enableMonitor('DP-2');assert.deepEqual(context.calls[0],['DP-2','2560x1440@59.951',2560,0,1.5,1,'none']);
reset([active,off],{'DP-2':{x:-2560,y:560}});context.enableMonitor('DP-2');assert.equal(context.calls[0][2],-2560);assert.equal(context.calls[0][3],560);
reset([{...active,scale:2,transform:1,y:0},off]);context.enableMonitor('DP-2');assert.equal(context.calls[0][2],720,'Peer bounds must use rotated logical width / scale');
reset([active,{...off,x:2560,y:560}]);context.enableMonitor('DP-2');assert.equal(context.calls[0][2],2560,'Touching edges are valid');
reset([active,{...off,refreshRate:0,x:-2560}]);assert.equal(context.enableMonitor('DP-2'),false);assert.equal(context.calls.length,0,'Unknown refresh must not select a preferred mode with different dimensions');
reset([active,{...off,refreshRate:NaN}]);assert.equal(context.enableMonitor('DP-2'),false);assert.equal(context.calls.length,0);
reset([active,{...off,width:0}]);assert.equal(context.enableMonitor('DP-2'),false);assert.equal(context.calls.length,0);
reset([active,{...off,scale:NaN}]);assert.equal(context.enableMonitor('DP-2'),false);assert.equal(context.calls.length,0);
reset([active,off]);assert.equal(context.enableMonitor('missing'),false);assert.equal(context.calls.length,0);
reset([{...active,width:0},off]);assert.equal(context.enableMonitor('DP-2'),false);assert.equal(context.calls.length,0);
assert.match(fs.readFileSync(path.join(__dirname,'../versions/V1/variants/V2/modules/DisplayManagerController.qml'),'utf8'),/Shared\.DisplayManagerController/);
console.log('ENABLE_CONTROLLER_PASS actual overlap, position/mode/rotation/scale preservation, logical dimensions, touching edges and invalid geometry rejected; shared V1/V2');
