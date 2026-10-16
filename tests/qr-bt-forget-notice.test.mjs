import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
for(const variant of ['versions/V1','versions/V1/variants/V2']){
 test(`${variant}: forget success notice expires after five seconds`,()=>{
  const qml=readFileSync(new URL(`../${variant}/panels/BluetoothPanel.qml`,import.meta.url),'utf8');
  assert.match(qml,/id: forgetNoticeTimer\s+interval: 5000; repeat: false\s+onTriggered: btPanel\.forgetNotice = ""/);
  assert.match(qml,/onForgetNoticeChanged:\s*\{[\s\S]*?forgetNoticeTimer\.restart\(\)/);
  const request=qml.slice(qml.indexOf('function requestForgetDevice('),qml.indexOf('function cancelForgetDevice('));
  assert.match(request,/forgetNotice = ""/,'new confirmation must not display an old success notice');
 });
}
