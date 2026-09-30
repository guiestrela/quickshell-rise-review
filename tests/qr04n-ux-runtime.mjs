import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
const project=fileURLToPath(new URL('..',import.meta.url));
const variant=process.argv.includes('--v2')?'v2':'v1';
const scratch=mkdtempSync(join(process.env.TMPDIR,'qr04n-ux-'));
try {
 let qml=readFileSync(join(project,`tests/qml/qr04n-${variant}-wiring.qml`),'utf8');
 const marker='host.verify(host.panel.visible, "instantiated VPN panel remained hidden")';
 assert.equal(qml.split(marker).length,2);
 qml=qml.replace(marker,marker+'; uxCheck.start(); return;');
 qml=qml.replace('    property int step: 0',`    property int step: 0
    property int uxPhase: 0
    property string tooltipText: ""
    property bool tooltipShown: false
    property var tooltipOwner: null
    function showTooltip(text,x,topY,bottomY,owner) { tooltipText=text; tooltipShown=true; tooltipOwner=owner }
    function hideTooltip(owner) { tooltipShown=false }
`);
 qml=qml.replace(/\n}\s*$/,`
 Timer { id: uxCheck; interval: 100; repeat: true; onTriggered: {
  try {
   var p=host.panel; var c=host.controller;
   if (host.uxPhase===0) {
    c.countryOptions=["Canada","United_States"]; c.countriesState="Ready"; c.vpnState="Connected";
    host.verify(p.selectCountry("Canada"),"valid country rejected");
    host.verify(!p.selectCountry(";touch bad"),"invalid country accepted");
    host.verify(p.countryTarget==="Canada" && !c.vpnBusy,"selection dispatched command");
    host.verify(p.selectAutoCountry("Canada"),"auto country rejected");
    p.autoConnectEnabled=true; host.uxPhase=1; return;
   }
   if(host.uxPhase===1) { p.applyAutoConnect(); host.uxPhase=2; return }
   if(c.vpnBusy) return;
   if(host.uxPhase===2) { p.autoConnectEnabled=false; p.applyAutoConnect(); host.uxPhase=3; return }
   if(host.uxPhase===3) {
    c.vpnState="Unknown";
    host.verify(!c.setAutoConnect(true,"Canada"),"unknown mutation accepted");
    host.verify(!c.setVpnSetting("protocol"),"unsupported protocol accepted");
    c.vpnState="Connected";
    host.verify(!c.setAutoConnect(true,"Canada;whoami"),"injection accepted");
    host.verify(c.connectVpnCountry("United_States"),"listed underscore country refused");
    host.uxPhase=4; return;
   }
   if(host.uxPhase===4) {
    console.log("QR04N_UX_RUNTIME_QML_PASS"); Qt.exit(0);
   }
  } catch(e) {console.error("QR04N_UX_FAIL",e); Qt.exit(1)}
 } }
}\n`);
 const log=join(scratch,'argv.bin'); const shell=join(scratch,'shell.qml'); writeFileSync(shell,qml);
 const run=spawnSync('qs',['-n','-p',shell],{encoding:'utf8',timeout:16000,env:{...process.env,DISPLAY:undefined,QT_QPA_PLATFORM:'wayland',QR04N_ARGV_LOG:log}});
 const output=(run.stdout||'')+(run.stderr||''); assert.equal(run.error,undefined,output);assert.equal(run.status,0,output);assert.match(output,/QR04N_UX_RUNTIME_QML_PASS/,output);
 const argv=readFileSync(log,'utf8').split('\n').filter(Boolean).map(x=>x.split('\0').filter(Boolean));
 assert.deepEqual(argv.filter(x=>['set','connect','disconnect','pause'].includes(x[0])),[['set','autoconnect','enabled','Canada'],['set','autoconnect','disabled'],['connect','United_States']]);
 console.log('QR04N_UX_RUNTIME_PASS '+variant+' selection inert; exact Auto-connect argv; Unknown/injection refused; recording stub only');
} finally {rmSync(scratch,{recursive:true,force:true});}
