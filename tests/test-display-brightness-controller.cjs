const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../versions/V1/modules/DisplayManagerController.qml'),'utf8');
const c={selectedMonitor:'DP-2',focusedMonitor:'DP-1',brightnessAvailable:true,calls:[],error:'',safeMonitor:n=>/^DP-[12]$/.test(n),command:args=>{c.calls.push(args);return true}};
vm.createContext(c);vm.runInContext(source.slice(source.indexOf('    function setBrightness(value)'),source.indexOf('    function setTextSize(index)')),c);
assert.equal(c.setBrightness(73),true);assert.equal(c.calls[0][3],'DP-2','selected monitor must win over focused monitor');
assert.equal(c.calls[0][5],'73');c.brightnessAvailable=false;assert.equal(c.setBrightness(72),false);assert.equal(c.calls.length,1);
console.log('BRIGHTNESS_CONTROLLER_PASS selected DP-2 != focus DP-1; unavailable blocked');
