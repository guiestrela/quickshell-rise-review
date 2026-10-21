#!/usr/bin/env python3
"""Real Quickshell collector/exit ordering against fixture-only Python programs."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='vpn-selection-process-', dir=os.environ['TMPDIR']) as directory:
    temp = Path(directory)
    for name in ['NordVpnController.qml', 'NordVpnProtocol.js']:
        shutil.copyfile(ROOT / 'versions/V1/modules' / name, temp / name)
    cli = temp / 'fixture-cli'
    cli.write_text('''#!/usr/bin/env python3
import sys
if sys.argv[1:] == ['status']: print('Status: Disconnected')
elif sys.argv[1:] == ['settings']: print('Protocol: VPN_PROTOCOL_UNSPECIFIED')
elif sys.argv[1:] == ['countries']: print('Fixture')
else: raise SystemExit('fixture refuses non-read command')
''')
    cli.chmod(0o700)
    reader = temp / 'fixture-reader.py'
    reader.write_text('''import json, sys, time
payload = json.dumps({'schema':1,'technology':'NORDLYNX','protocol':'UDP'}) + ' ' * 3000
sys.stdout.write(payload[:20]); sys.stdout.flush(); time.sleep(0.05)
sys.stdout.write(payload[20:]); sys.stdout.flush()
''')
    shell = '''import QtQuick
import Quickshell
ShellRoot {
 property int fixturePhase: 0
 NordVpnController { id: vpn; enabled: true; refreshInterval: 60000; cli: CLI; selectionReader: READER }
 SCENARIO
 Timer { interval: 20; running: true; repeat: true
  onTriggered: {
   if (vpn.vpnSettings["selection-source"] === "daemon-rpc") {
    if (vpn.vpnSettings.technology !== "NORDLYNX" || vpn._selectionRequest !== null) throw new Error("wrong selection/owner")
    if (EXPECT_PHASE && fixturePhase !== 1) throw new Error("scenario did not execute")
    console.log("PASS real Quickshell fixture: drained JSON selection")
    Qt.quit()
   }
  }
 }
 Timer { interval: 4000; running: true
  onTriggered: { console.log("FAIL fixture readback: " + JSON.stringify(vpn.vpnSettings) + " request=" + JSON.stringify(vpn._selectionRequest)); Qt.quit() }
 }
}
'''
    env = os.environ.copy()
    env.pop('DISPLAY', None)
    env.pop('WAYLAND_DISPLAY', None)
    env.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='')
    scenarios = {
        'collector drain': '',
        'overlapping generations': 'vpn._settingsGeneration += 2; vpn.refreshSelectionReadback()',
        'disable/re-enable': 'vpn.enabled = false; vpn.enabled = true; vpn.refreshSelectionReadback()',
    }
    for name, action in scenarios.items():
        scenario = '''Timer { interval: 1; running: true; repeat: true
 onTriggered: {
  if (!fixturePhase && vpn._selectionRequest) { fixturePhase = 1; ACTION }
 }
}'''.replace('ACTION', action) if action else ''
        config = shell.replace('CLI', json.dumps(str(cli))).replace('READER', json.dumps(str(reader)))
        config = config.replace('SCENARIO', scenario).replace('EXPECT_PHASE', 'true' if action else 'false')
        (temp / 'shell.qml').write_text(config)
        run = subprocess.run(['qs', '--no-color', '-p', str(temp)], env=env, capture_output=True, text=True, timeout=10)
        output = run.stdout + run.stderr
        assert run.returncode == 0 and 'PASS real Quickshell fixture: drained JSON selection' in output, output
        assert not any(error in output for error in ['ReferenceError', 'TypeError', 'Cannot assign', 'FAIL fixture']), output
        print(f'PASS real Quickshell fixture: {name}; fixture-only CLI/reader, zero VPN commands')
