#!/usr/bin/env python3
"""Exercise both real panels with a stub controller; never change system DNS."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'tests/qml/NordVPNPresentationHarness.qml').read_text()
source = source.replace('/home/guiestrela/Work/quickshell-rise-review', str(root))
source = source.replace('    property var controller:', '    property var dnsCalls: []\n    property var controller:', 1)
source = source.replace('setVpnSetting: function(_, __) {}, setAutoConnect:', '''setDnsServers: function(value) { harness.dnsCalls.push(["set", value]); return true },
        resetDnsServers: function() { harness.dnsCalls.push(["reset"]); return true },
        setVpnSetting: function(_, __) {}, setAutoConnect:''')
source = source[:source.index('    Timer {')] + '''
    Timer {
        interval: 350; running: true
        onTriggered: {
            try {
                const dns = harness.panel.testTargets["vpn-setting-dns"]
                if (!dns || !dns.enabled) throw new Error("DNS click disabled")
                dns.clicked(null)
                if (!harness.panel.dnsEditorExpanded) throw new Error("editor did not open")
                if (harness.dnsCalls.length) throw new Error("opening editor changed DNS")
                harness.panel.testDnsInput.text = "1.1.1.1, 8.8.8.8"
                harness.panel.testDnsSetHandler.clicked(null)
                harness.panel.testDnsResetHandler.clicked(null)
                if (JSON.stringify(harness.dnsCalls) !== JSON.stringify([["set", "1.1.1.1, 8.8.8.8"], ["reset"]]))
                    throw new Error("wrong DNS actions: " + JSON.stringify(harness.dnsCalls))
                dns.clicked(null)
                if (harness.panel.dnsEditorExpanded) throw new Error("editor did not collapse")
                harness.controller = Object.assign({}, harness.controller, {canMutate: false})
                Qt.callLater(function() {
                    if (dns.enabled || harness.panel.testDnsSetHandler.enabled || harness.panel.testDnsResetHandler.enabled) {
                        console.error("DNS_EDITOR_FAIL busy guards"); Qt.exit(1); return
                    }
                    console.log("DNS_EDITOR_PASS " + harness.variant)
                    Qt.exit(0)
                })
            } catch (e) { console.error("DNS_EDITOR_FAIL " + e); Qt.exit(1) }
        }
    }
}
'''
with tempfile.TemporaryDirectory(prefix='rise-dns-editor-') as tmp:
    for variant in ('V1', 'V2'):
        file = Path(tmp) / 'shell.qml'
        file.write_text(source.replace('required property string variant', f'property string variant: "{variant}"'))
        result = subprocess.run(['qs', '-n', '-p', str(file)], capture_output=True, text=True,
                                timeout=15, env={**os.environ, 'QT_QPA_PLATFORM': 'wayland',
                                                 'QT_QPA_PLATFORMTHEME': '', 'DISPLAY': ''})
        output = result.stdout + result.stderr
        assert result.returncode == 0 and f'DNS_EDITOR_PASS {variant}' in output, output
        print(f'{variant}: DNS click, editor, Apply, Reset and busy guards PASS')
