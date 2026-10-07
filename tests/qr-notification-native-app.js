// Inert native actions only; no real notification, app, message or URI.
const fs=require('fs'), vm=require('vm'), assert=require('assert/strict'),path=require('path');
const ctx={};vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(__dirname,'../versions/V1/integrations/NotificationActions.js'),'utf8').replace(/^\.pragma library\s*/,''),ctx);
assert.equal(typeof ctx.invokeDefault,'function','Selected native app action is missing');
for (const app of ['Thunderbird','Hermes','ChatGPT']) {
 let hits=0;
 const entry={backend:'omarchy',id:12,timestamp:12345,appName:app,summary:'Fixture',body:'Fixture only'};
 const row={originalId:12,timestamp:12345,app,summary:entry.summary,body:entry.body,execArgv:''};
 const ref={id:12,appName:app,summary:entry.summary,body:entry.body,tracked:true,actions:[{identifier:'default',invoke(){hits++;}}]};
 const service={popupModel:{count:1,get(){return row;}},liveRefs:{12:ref},isRestoredRow(){return false;}};
 assert.equal(ctx.invokeDefault(service,entry),true);assert.equal(hits,1);
 row.execArgv='["untrusted"]';assert.equal(ctx.invokeDefault(service,entry),false);row.execArgv='';
 ref.tracked=false;assert.equal(ctx.invokeDefault(service,entry),false);ref.tracked=true;
 row.timestamp++;assert.equal(ctx.invokeDefault(service,entry),false);row.timestamp--;
 ref.appName='different';assert.equal(ctx.invokeDefault(service,entry),false);ref.appName=app;
 ref.body='changed';assert.equal(ctx.invokeDefault(service,entry),false);ref.body=entry.body;
 service.isRestoredRow=()=>true;assert.equal(ctx.invokeDefault(service,entry),false);service.isRestoredRow=()=>false;
 service.popupModel.count=2;assert.equal(ctx.invokeDefault(service,entry),false);service.popupModel.count=1;
 ref.actions=[];assert.equal(ctx.invokeDefault(service,entry),false);
 ref.actions=[{identifier:'default',invoke(){hits++;}},{identifier:'default',invoke(){hits++;}}];
 assert.equal(ctx.invokeDefault(service,entry),false);assert.equal(hits,1);
}
console.log('Native app selected action and replay/identity/command denials PASS');
