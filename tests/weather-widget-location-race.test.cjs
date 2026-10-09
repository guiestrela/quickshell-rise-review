const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
function block(src,needle){ const start=src.indexOf(needle); assert.ok(start>=0,needle); const open=src.indexOf('{',start); let depth=1,i=open+1;for(;depth && i<src.length;i++){if(src[i]==='{')depth++;if(src[i]==='}')depth--;}return src.slice(open+1,i-1); }
for(const variant of ['versions/V1','versions/V1/variants/V2']){
 const source=fs.readFileSync(path.join(root,variant,'modules/WeatherWidget.qml'),'utf8');
 const c={rootMod:{locationSettings:{name:'A',latitude:0,longitude:0},locationGeneration:1,requestSettings:{name:'A',latitude:0,longitude:0},requestGeneration:1,weatherLoaded:false,weatherUnavailable:false,weatherIcon:'·',weatherPlace:'',weatherTemp:'',refreshPending:false,glyphForCode:(code)=>String(code),isNight:()=>false},weatherProc:{running:true},WeatherData:{},Qt:{callLater:f=>f()}};
 vm.createContext(c);vm.createContext(c.WeatherData);vm.runInContext(fs.readFileSync(path.join(root,'versions/V1/integrations/WeatherData.js'),'utf8').replace(/^\.pragma library\s*/,''),c.WeatherData);
 c.rootMod.locationSettings={name:'B',latitude:1,longitude:1};c.rootMod.locationGeneration=2;
 // Delayed complete stdout from A after a location change: actual QML JS callback.
 const finish=vm.runInContext('(function(){'+block(source,'onStreamFinished:')+'})',c);
 finish.call({text:JSON.stringify({current:{temperature_2m:12,weather_code:0,is_day:1}})});
 assert.equal(c.rootMod.weatherLoaded,false,variant+': old response must not be relabelled as the new location');
 const refresh=vm.runInContext('(function(force){'+block(source,'function refresh(force)')+'})',c);
 refresh(true);assert.equal(c.weatherProc.running,true);assert.equal(c.rootMod.refreshPending,true);
 assert.equal(c.rootMod.requestSettings.name,'A','active request snapshot must remain immutable');
 c.weatherProc.running=false;refresh(false);
 assert.equal(c.rootMod.requestSettings.name,'B');assert.equal(c.rootMod.requestGeneration,2);
 finish.call({text:JSON.stringify({current:{temperature_2m:20,weather_code:3,is_day:1}})});
 assert.equal(c.rootMod.weatherLoaded,true);assert.equal(c.rootMod.weatherPlace,'B');assert.equal(c.rootMod.weatherTemp,'20');
}
console.log('PASS V1/V2 old location reply discarded, running request immutable, latest location accepted');
