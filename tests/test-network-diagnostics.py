#!/usr/bin/env python3
"""Native network feature UI with real Process and private fake helper CLIs."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-network-diagnostics-', dir='/tmp') as temporary:
    folder = Path(temporary)
    for name in ('components', 'services', 'bin', 'runtime'):
        (folder/name).mkdir(mode=0o700)
    for name in ('NetworkDiagnosticsSection.qml', 'UiText.qml'):
        shutil.copy2(repo/'shared/components'/name, folder/'components'/name)
    shutil.copy2(repo/'shared/services/NetworkDiagnostics.qml', folder/'services/NetworkDiagnostics.qml')
    (folder/'selected').write_text('auto')
    for name in ('omarchy-network-status', 'omarchy-network-band', 'omarchy-network-captive-portal'):
        helper = folder/'bin'/name
        helper.write_text('''#!/usr/bin/python3
import json,os,sys,time
from pathlib import Path
root=Path(os.environ['RISE_NETWORK_FIXTURE'])
name=Path(sys.argv[0]).name
if name=='omarchy-network-status':
 print('iface\\twlan-fixture\\nrouter_ping_ms\\t0\\ninternet_ping_ms\\t20')
elif name=='omarchy-network-band' and len(sys.argv)==1:
 print('band\\t5\\navailable\\t2.4 5 6\\nselected\\t'+(root/'selected').read_text())
else:
 with (root/'actions').open('a') as out:out.write(json.dumps([name]+sys.argv[1:])+'\\n')
 if name=='omarchy-network-band':
  time.sleep(.15)
  if sys.argv[1]=='6':sys.exit(1)
  (root/'selected').write_text(sys.argv[1])
''')
        helper.chmod(0o700)
    (folder/'shell.qml').write_text('''import QtQuick
import QtQuick.Window
import Quickshell
import "components"
Scope {
 id: test
 QtObject {
  id: theme
  property bool networkVisible: false
  property int tileRadius: 6
  property string mono: "monospace"
  property color fillActive: "#332222"
  property color fillHover: "#303030"
  property color fillIdle: "#202020"
  property color seal: "#ff7788"
  property color sep: "#555555"
  property color ink: "#dddddd"
  property color sumiHi: "#aaaaaa"
 }
 Window {
  id: window
  width: 320; height: 420; visible: true; color: "#111111"
  NetworkDiagnosticsSection {
   id: section
   x: 12; y: 12; width: 296
   theme: theme
   panelOpen: theme.networkVisible
   networkMode: "wifi"
  }
 }
 function check(ok, message) { if (!ok) throw new Error(message) }
 Timer {
  interval: 30; repeat: true; running: true
  property int phase: 0
  property int ticks: 0
  onTriggered: {
   try {
    ticks++
    if (ticks>250) throw new Error("network fixture timeout phase="+phase)
    var d=section.controller
    if (phase===0) {
     theme.networkVisible=true; phase=1
    } else if (phase===1 && d.canSelectBand && d.routerMs===0) {
     d.resetSamples()
     d.acceptStatus("iface\\twlan-fixture\\nrouter_ping_ms\\t0\\ninternet_ping_ms\\t20")
     d.acceptStatus("iface\\twlan-fixture\\nrouter_ping_ms\\t4\\ninternet_ping_ms\\t")
     test.check(d.packetLoss===50 && d.routerMs===2 && d.internetMs===20,"latency/loss/zero sample")
     d.acceptStatus("iface\\tnew-interface\\ninternet_ping_ms\\t10")
     test.check(d.packetLoss===0 && d.routerMs===-1,"interface reset")
     test.check(!d.setBand("60"),"invalid band rejected")
     if (d.setBand("2.4")) { theme.networkVisible=false; phase=2 }
    } else if (phase===2 && !d.bandBusy) {
     test.check(d.pendingBand==="","pending action released after closing")
     theme.networkVisible=true; phase=3
    } else if (phase===3 && d.selectedBand==="2.4" && !d.bandBusy) {
     if (d.setBand("6")) phase=4
    } else if (phase===4 && !d.bandBusy && d.bandError!=="") {
     test.check(d.selectedBand==="2.4" && d.pendingBand==="","failed action rolls back presentation")
     section.connectivity="limited"
     test.check(!d.openPortal(),"limited is not a captive portal")
     section.connectivity="portal"
     section.networkMode="none"
     test.check(section.visible,"portal remains accessible without a default route")
     test.check(d.openPortal(),"portal action")
     test.check(!theme.networkVisible,"release exclusive panel before browser")
     phase=5; ticks=0
    } else if (phase===5 && ticks>8) {
     phase=6
     var preview=Quickshell.env("RISE_NETWORK_PREVIEW")
     if (preview) window.contentItem.grabToImage(function(image) {
      image.saveToFile(preview); console.log("NETWORK_DIAGNOSTICS_PASS"); Qt.quit()
     })
     else { console.log("NETWORK_DIAGNOSTICS_PASS"); Qt.quit() }
    }
   } catch(error) { console.error(error); Qt.exit(1) }
  }
 }
}
''')
    environment = {**os.environ, 'RISE_NETWORK_FIXTURE':str(folder),
                   'PATH':str(folder/'bin')+':/usr/bin:/bin',
                   'XDG_RUNTIME_DIR':str(folder/'runtime'), 'QT_QPA_PLATFORM':'offscreen',
                   'QT_QUICK_BACKEND':'software', 'QT_QPA_PLATFORMTHEME':''}
    result = subprocess.run(['timeout','12','qs','-n','-p',str(folder/'shell.qml')],
                            capture_output=True,text=True,timeout=20,env=environment)
    output = result.stdout + result.stderr
    assert result.returncode==0 and 'NETWORK_DIAGNOSTICS_PASS' in output, output
    assert not re.search(r'ERROR|ReferenceError|TypeError|Unable to assign|Binding loop', output), output
    actions=[json.loads(line) for line in (folder/'actions').read_text().splitlines()]
    assert actions==[['omarchy-network-band','2.4'],['omarchy-network-band','6'],
                     ['omarchy-network-captive-portal','http://ping.omacom.io/nm-check.txt']],actions
    print('PASS: native network helpers, band actions/failure, panel close, latency/loss, portal and fixed argv')
