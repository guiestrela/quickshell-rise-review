#!/usr/bin/env python3
"""Real Qt pointer tests with inert backend; no system/network mutation."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT / 'versions/V1/modules/NetworkDnsSection.qml'
assert SOURCE.exists(), 'Missing DNS selector component'
source = SOURCE.read_text()
assert source.count('/usr/bin/omarchy-dns') == 2
for panel in [PROJECT / 'versions/V1/panels/NetworkPanel.qml', PROJECT / 'versions/V1/variants/V2/panels/NetworkPanel.qml']:
    assert 'NetworkDnsSection {' in panel.read_text(), f'Missing DNS selector: {panel}'

with tempfile.TemporaryDirectory(prefix='network-dns-', dir=os.environ['TMPDIR']) as temp:
    root = Path(temp)
    (root/'state').write_text('DHCP')
    fake = root/'dns-fake'
    fake.write_text('''#!/usr/bin/python3
import pathlib,sys,time
root=pathlib.Path(__file__).parent
if len(sys.argv)==1:
 print((root/'state').read_text());sys.exit(0)
with (root/'actions').open('a') as out:out.write(sys.argv[1]+'\\n')
time.sleep(.15)
if (root/'fail').exists():sys.exit(1)
if (root/'mismatch').exists():sys.exit(0)
(root/'state').write_text(sys.argv[1])
''')
    fake.chmod(0o700)
    (root/'NetworkDnsSection.qml').write_text(source.replace('import Quickshell.Io\n', ''))
    (root/'qmldir').write_text('singleton Backend 1.0 Backend.qml\n')
    (root/'Backend.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property string provider: "DHCP"; property var actions: []; property bool fail: false; property bool mismatch: false }')
    (root/'StdioCollector.qml').write_text('import QtQuick\nQtObject { property string text: ""; property bool waitForEnd: false }')
    (root/'Process.qml').write_text('import QtQuick\nimport "." as Fixture\nQtObject {\n id: proc\n property var command: []\n property bool running: false\n property var stdout\n property var stderr\n signal exited(int exitCode)\n property Timer done: Timer {\n  interval: 80\n  onTriggered: {\n   var code=0\n   if(proc.command.length===1) proc.stdout.text=Fixture.Backend.provider\n   else {\n    Fixture.Backend.actions=Fixture.Backend.actions.concat([proc.command[1]])\n    if(Fixture.Backend.fail) code=1\n    else if(!Fixture.Backend.mismatch) Fixture.Backend.provider=proc.command[1]\n   }\n   proc.running=false\n   proc.exited(code)\n  }\n }\n onRunningChanged: if(running) done.restart()\n}\n')
    (root/'UiText.qml').write_bytes((PROJECT/'versions/V1/modules/UiText.qml').read_bytes())
    qml = '''import QtQuick
import QtTest
import "." as Fixture
Item {
 visible: true; width: 300; height: 220
 QtObject { id: theme; property color seal: "#70a0c0"; property color ink: "#dddddd"; property color sumiHi: "#999999"; property color sep: "#444444"; property color fillActive: "#223344"; property color fillHover: "#334455"; property color fillIdle: "#222222"; property string mono: "monospace"; property int tileRadius: 4 }
 NetworkDnsSection { id: dns; width: 276; theme: theme; panelOpen: true }
 TestCase {
  name: "DNS"; parent: dns; when: windowShown
  function test_selector() {
   tryCompare(dns, "ready", true, 2000); compare(dns.provider, "DHCP")
   compare(dns.providers.length, 3)
   verify(!dns.choose("Custom")); verify(!dns.choose("Google; touch /tmp/forbidden")); verify(!dns.choose("google")); verify(!dns.choose("DHCP"))
   var buttons=["Cloudflare","Google","DHCP"]
   for (var i=0; i<buttons.length; ++i) {
    var hit=findChild(dns,"dns-hit-"+buttons[i]); verify(hit!==null)
    var old=dns.provider
    if (i===2) { findChild(dns,"dns-choice-"+buttons[i]).forceActiveFocus(); keyClick(Qt.Key_Space) }
    else mouseClick(hit,hit.width/2,hit.height/2)
    verify(dns.busy); compare(dns.provider,old); verify(!dns.choose("Google"))
    tryCompare(dns,"busy",false,2000); compare(dns.provider,buttons[i]); compare(dns.error,"")
    var selected=findChild(dns,"dns-choice-"+buttons[i]); verify(selected.active)
    verify(selected.width*3+8 <= dns.width+.01)
    verify(selected.labelFits)
   }
   Fixture.Backend.provider="Custom"; dns.refresh(); tryCompare(dns,"busy",false,2000)
   compare(dns.provider,"Custom")
   for (var j=0;j<dns.providers.length;++j) verify(!findChild(dns,"dns-choice-"+dns.providers[j]).active)
   Fixture.Backend.fail=true; verify(dns.choose("Cloudflare")); tryCompare(dns,"busy",false,2000)
   compare(dns.provider,"Custom"); verify(dns.error!=="")
   dns.refresh(); tryCompare(dns,"busy",false,2000); verify(dns.error!=="")
   compare(Fixture.Backend.actions.join(","),"Cloudflare,Google,DHCP,Cloudflare")
   console.log("DNS_POINTER_PASS")
  }
 }
}
'''
    probe=root/'shell.qml';probe.write_text(qml)
    env=os.environ.copy();env.pop('DISPLAY',None);env['QT_QPA_PLATFORM']='wayland'
    try:
        z=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(probe)],env=env,capture_output=True,text=True,timeout=5)
        output=z.stdout+z.stderr
    except subprocess.TimeoutExpired as exc:
        output=(exc.stdout or b'').decode(errors='replace')+(exc.stderr or b'').decode(errors='replace')
    assert 'DNS_POINTER_PASS' in output and 'FAIL!' not in output, output
    print('PASS: Qt pointer/keyboard layout; three providers, no optimistic selection, busy guard, Custom, failure, invalid inputs; backend inert')
