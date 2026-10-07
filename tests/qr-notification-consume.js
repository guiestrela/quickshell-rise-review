// Run exact QML functions in a JS fixture. No app, shell, cache or UI effects.
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),path=require('path');
function fn(text,name){let start=text.indexOf('function '+name+'(');assert.ok(start>=0,'Missing '+name);let brace=text.indexOf('{',start),depth=1,end=brace+1;while(depth&&end<text.length){if(text[end]==='{')depth++;if(text[end]==='}')depth--;end++;}return text.slice(start,end);}
for(const variant of ['versions/V1','versions/V1/variants/V2']){
 const t=fs.readFileSync(path.join(__dirname,'..',variant,'panels/NotificationPanel.qml'),'utf8');let writes=0,invokes=0;
 const panel={dismissed:{old:true},cacheLoaded:true,pendingNotificationKey:'',browserOpenReplySeen:false,notificationReplySeen:false,nativeBrowserClaims:{},appOpenHelper:'app-fixture',browserOpenHelper:'browser-fixture',notificationActionHelper:'special-fixture',saveCache(){writes++;},runNotificationAction(){invokes++;}};
 const root={notifVisible:true};const ctx={notifPanel:panel,root,browserOpenProc:{running:false},notificationOpenProc:{running:false},NotificationActions:{serviceFor(){return null;},invokeDefault(){return false;}}};vm.createContext(ctx);
 for(const name of ['consumeNotification','finishBrowserOpen','finishNotificationAction','openNotification']){vm.runInContext(fn(t,name),ctx);panel[name]=ctx[name];}
 let seq=20;
 function entry(key,app='Hermes'){return {key,backend:'omarchy',appName:app,id:++seq,timestamp:12345,summary:'Fixture',body:'Fixture'};}
 ctx.openNotification(entry('one'));assert.equal(root.notifVisible,false);assert.equal(ctx.browserOpenProc.command[1],'app-fixture');assert.equal(panel.dismissed.one,undefined);
 ctx.finishBrowserOpen({ok:true});assert.equal(panel.dismissed.one,true);assert.equal(panel.dismissed.old,true);assert.equal(writes,1);
 ctx.finishBrowserOpen({ok:false,message:'late'});assert.equal(writes,1);assert.equal(root.notifVisible,false);
 ctx.browserOpenProc.running=false;root.notifVisible=true;ctx.openNotification(entry('two'));ctx.finishBrowserOpen({ok:false,message:'failed'});assert.equal(panel.dismissed.two,undefined);assert.equal(root.notifVisible,true);
 ctx.browserOpenProc.running=false;root.notifVisible=true;ctx.NotificationActions.invokeDefault=()=>true;ctx.openNotification(entry('native'));assert.equal(panel.dismissed.native,true);assert.equal(root.notifVisible,false);
 ctx.NotificationActions.invokeDefault=()=>false;ctx.browserOpenProc.running=false;root.notifVisible=true;ctx.openNotification(entry('special','omarchy-action'));assert.equal(ctx.notificationOpenProc.command[1],'special-fixture');ctx.finishNotificationAction({ok:true});assert.equal(panel.dismissed.special,true);
 const before=writes;ctx.openNotification(entry('closed'));assert.equal(writes,before);assert.equal(panel.dismissed.closed,undefined);
 console.log(variant+' exact-key consume success/native/special; failure retained; closed/late guards PASS');
}
