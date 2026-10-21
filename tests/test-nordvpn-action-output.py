#!/usr/bin/env python3
"""Real shared V1/V2 controller and Process, with a fixture-only CLI.

Never invokes the installed NordVPN client or changes the host network.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='nordvpn-output-', dir=os.environ['TMPDIR']) as directory:
    temp = Path(directory)
    log = temp / 'argv.jsonl'
    cli = temp / 'fixture-cli'
    cli.write_text('''#!/usr/bin/python3
import json, pathlib, sys, time
with pathlib.Path(__file__).with_name('argv.jsonl').open('a') as log:
    log.write(json.dumps(sys.argv[1:])+'\\n')
args=sys.argv[1:]
if args==['status']: print('Status: Connected\\nCountry: Testland')
elif args==['settings']: print('Routing: enabled\\nMeshnet: enabled')
elif args==['countries']: print('Brazil')
elif args==['set','routing','off']:
    time.sleep(.08)
    print('\\x1b[33mRouting is in use by Meshnet. Disable Meshnet first.\\x1b[0m')
elif args==['set','routing','on']:
    time.sleep(.08)
    print('Routing is already enabled.')
elif args==['set','dns','9.9.9.9']:
    time.sleep(.08)
    print('Fixture DNS backend failure',file=sys.stderr);sys.exit(7)
elif args==['pause','5m']:
    time.sleep(.08)
    print('Fixture pause accepted')
else: print('Fixture command failed',file=sys.stderr); sys.exit(7)
''')
    cli.chmod(0o700)
    urls = [(ROOT / relative).as_uri() for relative in [
        'versions/V1/modules/NordVpnController.qml',
        'versions/V1/variants/V2/modules/NordVpnController.qml',
    ]]
    qml = '''import QtQuick
import Quickshell
Scope {
 id: host
 property var urls: URLS
 property var c: null
 property int variant: 0
 property int phase: 0
 property int settleTicks: 0
 property bool failed: false
 function check(ok, message) {
  if (!ok) { failed=true; console.error("NORDVPN_OUTPUT_FAIL",variant,phase,message); Qt.quit(); throw Error(message) }
 }
 function load() {
  var component=Qt.createComponent(urls[variant]);check(component.status===Component.Ready,component.errorString())
  c=component.createObject(host,{cli:CLI_PATH,enabled:true,refreshInterval:60000});check(c!==null,"controller missing");phase=0
 }
 Component.onCompleted: load()
 Timer { interval:20;repeat:true;running:!host.failed;onTriggered: {
  if (host.phase===0 && host.c.canMutate && host.c.vpnSettings.routing==="enabled") {
   host.check(!host.c.setVpnSetting("routing"),"Meshnet dependency accepted")
   host.check(/Meshnet/.test(host.c.vpnMessage),"dependency reason missing")
   host.check(!host.c.setVpnSetting("post-quantum-vpn"),"Post-quantum accepted with Meshnet enabled")
   host.check(/Meshnet/.test(host.c.vpnMessage),"Post-quantum Meshnet reason missing")
   host.c.vpnSettings={"post-quantum-vpn":"disabled",meshnet:"disabled",technology:"OPENVPN"}
   host.check(!host.c.setVpnSetting("post-quantum-vpn"),"Post-quantum accepted without NordLynx")
   host.check(/NordLynx/.test(host.c.vpnMessage),"Post-quantum technology reason missing")
   // Model an outdated UI snapshot: the daemon still refuses on stdout/exit 0.
   host.c.vpnSettings={routing:"enabled",meshnet:"disabled"}
   host.check(host.c.setVpnSetting("routing"),"fixture action rejected");host.phase=1
  } else if (host.phase===1 && !host.c.vpnBusy) {
   host.check(/Meshnet/.test(host.c.vpnActionMessage),"stdout warning lost behind generic success: "+host.c.vpnActionMessage)
   host.check(host.c.vpnActionMessage.indexOf("\\u001b")<0,"ANSI escape leaked")
   host.check(!/completed/i.test(host.c.vpnActionMessage),"dependency claimed success")
   host.check(host.c.setVpnSetting("routing"),"second fixture action rejected");host.phase=2
  } else if (host.phase===2 && !host.c.vpnBusy) {
   // Both actions requested OFF from the same unrefreshed snapshot. Now test ON.
   host.c.vpnSettings={routing:"disabled",meshnet:"enabled"}
   host.check(host.c.setVpnSetting("routing"),"ON fixture action rejected");host.phase=3
  } else if (host.phase===3 && !host.c.vpnBusy) {
   host.check(host.c.vpnActionMessage==="Routing is already enabled.","output missing or stale between commands")
   host.c.vpnSettings={dns:"1.1.1.1"}
   host.check(host.c.setDnsServers("1.1.1.1"),"existing DNS should be a successful no-op")
   host.check(!host.c.vpnBusy && /already/.test(host.c.vpnActionMessage),"existing DNS launched another write")
   host.check(host.c.setDnsServers("9.9.9.9"),"DNS fixture failure action rejected");host.phase=4
  } else if (host.phase===4 && !host.c.vpnBusy) {
   host.check(host.c.vpnMessage==="Fixture DNS backend failure","real CLI stderr was lost: "+host.c.vpnMessage)
   host.c.refresh();host.settleTicks=0;host.phase=5
  } else if (host.phase===5 && ++host.settleTicks>=25) {
   host.check(host.c.vpnMessage==="Fixture DNS backend failure","status polling erased the action error")
   host.check(host.c.pauseVpn("5m"),"next fixture action rejected")
   host.check(host.c.vpnMessage==="","new action retained the old DNS error");host.phase=6
  } else if (host.phase===6 && !host.c.vpnBusy) {
   host.check(host.c.vpnMessage==="" && host.c.vpnActionMessage==="Fixture pause accepted","new result retained stale output")
   console.log("NORDVPN_OUTPUT_PASS",host.variant)
   host.c.enabled=false;host.c.destroy();host.variant++
   if(host.variant===host.urls.length)Qt.quit();else host.load()
  }
 }}
 Timer {interval:7000;running:true;onTriggered:{host.check(false,"timeout")}}
}
'''.replace('URLS', json.dumps(urls)).replace('CLI_PATH', json.dumps(str(cli)))
    shell = temp / 'shell.qml'
    shell.write_text(qml)
    env = os.environ.copy()
    env.pop('DISPLAY', None)
    env['QT_QPA_PLATFORM'] = 'wayland'
    result = subprocess.run(['qs', '-n', '-p', str(shell)], env=env, capture_output=True, text=True, timeout=10)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and output.count('NORDVPN_OUTPUT_PASS') == 2 and 'NORDVPN_OUTPUT_FAIL' not in output, output
    assert not any(error in output for error in ['ReferenceError', 'TypeError', 'Cannot assign']), output
    argv = [json.loads(line) for line in log.read_text().splitlines()]
    actions = [args for args in argv if args and args[0]=='set']
    assert actions == [['set','routing','off'],['set','routing','off'],['set','routing','on'],['set','dns','9.9.9.9']] * 2, actions
    assert [args for args in argv if args and args[0]=='pause'] == [['pause','5m']] * 2
    print('PASS V1/V2: dependency guards and existing DNS issue no action; stdout warnings preserved; real DNS stderr survives status polling; fixture-only CLI, no host VPN mutations')
