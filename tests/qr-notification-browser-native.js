// Local fixture callbacks only. Never invoke real notifications or URLs.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const path = require('path');
const file = path.join(__dirname,'../versions/V1/integrations/NotificationActions.js');
assert.ok(fs.existsSync(file), 'Selected native notification bridge is missing');
const ctx = {}; vm.createContext(ctx);
vm.runInContext(fs.readFileSync(file,'utf8').replace(/^\.pragma library\s*/,''),ctx);
const entry = {backend:'omarchy',id:9,timestamp:12345,appName:'Chromium',summary:'Fixture',body:'never a URL command'};
let invoked = 0;
const row = {originalId:9,timestamp:12345,app:'Chromium',summary:'Fixture',body:entry.body,execArgv:''};
const ref = {id:9,appName:'Chromium',summary:'Fixture',body:entry.body,tracked:true,
 actions:[{identifier:'default',invoke(){invoked++;}}]};
const service = {popupModel:{count:1,get(){return row;}},liveRefs:{9:ref},isRestoredRow(){return false;}};
assert.equal(ctx.invokeChromium(service,entry),true);
assert.equal(invoked,1);
row.timestamp++;
assert.equal(ctx.invokeChromium(service,entry),false);assert.equal(invoked,1);
row.timestamp--;service.isRestoredRow=()=>true;
assert.equal(ctx.invokeChromium(service,entry),false);assert.equal(invoked,1);
service.isRestoredRow=()=>false;row.execArgv='["evil"]';
assert.equal(ctx.invokeChromium(service,entry),false);assert.equal(invoked,1);
row.execArgv='';ref.summary='changed';
assert.equal(ctx.invokeChromium(service,entry),false);assert.equal(invoked,1);
ref.summary='Fixture';ref.actions.push({identifier:'default',invoke(){throw Error('ambiguous');}});
assert.equal(ctx.invokeChromium(service,entry),false);assert.equal(invoked,1);
console.log('Selected native callback and timestamp/restored/argv/ref/duplicate-action denial PASS');
