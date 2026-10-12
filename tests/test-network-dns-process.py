#!/usr/bin/env python3
"""Actual Quickshell Process/readback with a private, nonprivileged DNS helper."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dns-process-', dir=os.environ['TMPDIR']) as temp:
    root = Path(temp)
    for name, value in [('state','DHCP'), ('fail',''), ('mismatch','')]:
        (root/name).write_text(value)
    fake = root/'dns-fake'
    fake.write_text('''#!/usr/bin/python3
import pathlib,sys,time
root=pathlib.Path(__file__).parent
if len(sys.argv)==1:
 print((root/'state').read_text());sys.exit(0)
with (root/'actions').open('a') as out:out.write(sys.argv[1]+'\\n')
time.sleep(.1)
if (root/'fail').read_text()=='yes':sys.exit(1)
if (root/'mismatch').read_text()=='yes':sys.exit(0)
(root/'state').write_text(sys.argv[1])
''')
    fake.chmod(0o700)
    source=(PROJECT/'versions/V1/modules/NetworkDnsSection.qml').read_text()
    (root/'NetworkDnsSection.qml').write_text(source.replace('/usr/bin/omarchy-dns', str(fake)))
    (root/'UiText.qml').write_bytes((PROJECT/'versions/V1/modules/UiText.qml').read_bytes())
    qml='''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
 property int phase: 0
 QtObject { id: theme; property color seal: "#70a0c0"; property color ink: "#dddddd"; property color sumiHi: "#999999"; property color sep: "#444444"; property color fillActive: "#223344"; property color fillHover: "#334455"; property color fillIdle: "#222222"; property string mono: "monospace"; property int tileRadius: 4 }
 NetworkDnsSection { id: dns; width: 276; theme: theme; panelOpen: true }
 FileView { id: state; path: %s; blockWrites: true; atomicWrites: true; printErrors: false }
 FileView { id: fail; path: %s; blockWrites: true; atomicWrites: true; printErrors: false }
 FileView { id: mismatch; path: %s; blockWrites: true; atomicWrites: true; printErrors: false }
 function check(value,message) { if(!value) { console.error("DNS_PROCESS_FAIL",phase,message);Qt.quit();throw Error(message) } }
 Timer {
  interval: 30; repeat: true; running: true
  onTriggered: {
   if(dns.busy) return
   if(phase===0) {
    check(dns.ready&&dns.provider==="DHCP","initial provider")
    check(!dns.choose("Custom")&&!dns.choose("cloudflare")&&!dns.choose("Google;exit")&&!dns.choose("DHCP"),"allowlist/no-op")
    check(dns.choose("Cloudflare"),"choose Cloudflare")
    check(dns.busy&&dns.provider==="DHCP"&&!dns.choose("Google"),"pending/busy guard")
   } else if(phase===1) {
    check(dns.ready&&dns.provider==="Cloudflare"&&dns.error==="","Cloudflare readback")
    check(dns.choose("Google"),"choose Google")
   } else if(phase===2) {
    check(dns.ready&&dns.provider==="Google"&&dns.error==="","Google readback")
    check(dns.choose("DHCP"),"choose DHCP")
   } else if(phase===3) {
    check(dns.provider==="DHCP"&&dns.error==="","DHCP readback")
    state.setText("Custom");dns.refresh()
   } else if(phase===4) {
    check(dns.ready&&dns.provider==="Custom","Custom retained")
    fail.setText("yes");check(dns.choose("Cloudflare"),"failed action starts")
   } else if(phase===5) {
    check(dns.ready&&dns.provider==="Custom"&&dns.error!=="","action failure not success")
    dns.refresh()
   } else if(phase===6) {
    check(dns.error!=="","failure not erased by refresh")
    fail.setText("");mismatch.setText("yes");check(dns.choose("Google"),"mismatch starts")
   } else if(phase===7) {
    check(dns.provider==="Custom"&&dns.error!=="","exit zero without matching readback is failure")
    state.setText("malformed");dns.refresh()
   } else {
    check(!dns.ready&&dns.error!==""&&!dns.choose("DHCP"),"malformed read fails closed")
    console.log("DNS_PROCESS_PASS");Qt.quit()
   }
   phase++
  }
 }
 Timer { interval: 3500; running: true; onTriggered: { console.error("DNS_PROCESS_FAIL timeout");Qt.quit() } }
}
''' % tuple(json.dumps(str(root/name)) for name in ['state','fail','mismatch'])
    probe=root/'shell.qml';probe.write_text(qml)
    env=os.environ.copy();env.pop('DISPLAY',None);env['QT_QPA_PLATFORM']='wayland'
    z=subprocess.run(['qs','-n','-p',str(probe)],env=env,capture_output=True,text=True,timeout=5)
    output=z.stdout+z.stderr
    assert z.returncode==0 and 'DNS_PROCESS_PASS' in output and 'DNS_PROCESS_FAIL' not in output,output
    assert not any(value in output for value in ['ReferenceError','TypeError','Cannot assign']),output
    assert (root/'actions').read_text().splitlines()==['Cloudflare','Google','DHCP','Cloudflare','Google']
    print('PASS: real Process + private helper; three selections/readbacks, failure, mismatched successful exit, Custom preserved, malformed data blocked, no overlapping writes; zero real DNS mutation')
