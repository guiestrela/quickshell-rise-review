import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
function fn(qml,name){const start=qml.indexOf(`function ${name}(`);assert.ok(start>=0,`${name} missing`);let open=qml.indexOf('{',start),depth=0;for(let i=open;i<qml.length;i++){if(qml[i]==='{')depth++;if(qml[i]==='}'&&--depth===0)return qml.slice(start,i+1)}assert.fail('function incomplete')}
for(const variant of ['versions/V1','versions/V1/variants/V2']){
 test(`${variant}: left-click accordion toggles one device and preserves main connection button`,()=>{
  const qml=readFileSync(new URL(`../${variant}/panels/BluetoothPanel.qml`,import.meta.url),'utf8');
  const panel={expandedDeviceKey:'',actionBusy:false,cancelForgetDevice(){},trustError:''};
  const ctx={btPanel:panel,connProc:{running:false}};
  panel.deviceActionKey=vm.runInNewContext(`(${fn(qml,'deviceActionKey')})`,ctx);
  const toggle=vm.runInNewContext(`(${fn(qml,'toggleDeviceActions')})`,ctx);
  const a={adapterId:'hci0',mac:'AA:BB:CC:DD:EE:FF'},b={adapterId:'hci1',mac:'AA:BB:CC:DD:EE:FF'};
  toggle(a);assert.equal(panel.expandedDeviceKey,panel.deviceActionKey(a));
  toggle(a);assert.equal(panel.expandedDeviceKey,'');
  toggle(a);toggle(b);assert.equal(panel.expandedDeviceKey,panel.deviceActionKey(b));
  panel.actionBusy=true;toggle(b);assert.equal(panel.expandedDeviceKey,panel.deviceActionKey(b));
  assert.match(qml,/acceptedButtons: Qt.LeftButton/);
  assert.match(qml,/id: deviceActions/);
 });
 test(`${variant}: Trust reserves one operation and rejects unknown/already-trusted identities`,()=>{
  const qml=readFileSync(new URL(`../${variant}/panels/BluetoothPanel.qml`,import.meta.url),'utf8');
  const device={mac:'AA:BB:CC:DD:EE:FF',adapterId:'hci0',dbusPath:'/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF',name:'Synthetic'};
  const live={...device,trusted:false,adapter:{adapterId:'hci0'}};
  const panel={trustPending:false,trustError:'',trustTarget:null};
  Object.defineProperty(panel,'actionBusy',{get:()=>panel.trustPending});
  let starts=0,running=false;
  const proc={};Object.defineProperty(proc,'running',{get:()=>running,set:v=>{running=v;if(v)starts++}});
  const ctx={btPanel:panel,trustProc:proc,connProc:{running:false},Bluetooth:{devices:{values:[live]}}};
  panel.validBluetoothIdentity=vm.runInNewContext(`(${fn(qml,'validBluetoothIdentity')})`,ctx);
  panel.nativeDeviceForDevice=vm.runInNewContext(`(${fn(qml,'nativeDeviceForDevice')})`,ctx);
  const request=vm.runInNewContext(`(${fn(qml,'requestTrustDevice')})`,ctx);
  request(device);assert.equal(starts,1);assert.equal(panel.trustPending,true);assert.equal(panel.trustTarget.dbusPath,device.dbusPath);
  request(device);assert.equal(starts,1,'duplicate Trust is blocked before Process starts');
  panel.trustPending=false;running=false;live.trusted=true;
  request(device);assert.equal(starts,1,'already trusted is a state, not a second mutation');
  live.trusted=false;ctx.Bluetooth.devices.values=[];request(device);assert.equal(starts,1);
  ctx.Bluetooth.devices.values=[live];request({...device,dbusPath:'/bad/path'});assert.equal(starts,1);
  assert.match(qml,/id: trustVerify/);
 });
}
