#!/usr/bin/env python3
"""Exercise the actual panel auth process without legacy installed helpers."""
import os
from pathlib import Path
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
for variant in ('versions/V1', 'versions/V1/variants/V2'):
    source = (REPO / variant / 'panels/AiUsagePanel.qml').read_text()
    start = source.index('    property var availableTools: []')
    end = source.index('    readonly property bool   showClaude:', start)
    block = source[start:end]
    for mode in ('success', 'nonzero', 'missing', 'timeout'):
        with tempfile.TemporaryDirectory(prefix='rise-ai-auth-') as temp:
            plugin = Path(temp) / 'plugin'
            panel = plugin / variant / 'panels/Probe.qml'
            panel.parent.mkdir(parents=True)
            helper = plugin / 'scripts/rise-ai-auth-status'
            helper.parent.mkdir()
            helper.write_text('print(\'{"codex":true}\')\n')
            setup = {
                'success': '',
                'nonzero': 'authStatusProcess.command = ["python3", "-c", "raise SystemExit(1)"];',
                'missing': 'authStatusProcess.command = ["/nonexistent/rise-auth-helper"];',
                'timeout': 'authStatusProcess.command = ["python3", "-c", "import time; time.sleep(10)"];',
            }[mode]
            expected = '2' if mode == 'success' else '1'
            panel.write_text('''import QtQuick
import Quickshell
import Quickshell.Io
Item {
 id: aiPanel
 property QtObject root: QtObject {
  property string aiTool: "claude"
  property bool aiUsageVisible: false
 }
 BLOCK
 Component.onCompleted: {
  SETUP
  authStatusWatchdog.interval = 1000
  refreshAuthStatus()
 }
 Timer {
  interval: 1500; running: true
  onTriggered: {
   if (!authChecked || availableTools.length !== EXPECTED || authStatusProcess.running) {
    console.log("AUTH_PROCESS_FAIL", authChecked, JSON.stringify(availableTools), JSON.stringify(authStatusProcess.command), authStatusProcess.running); Qt.exit(1); return
   }
   console.log("AUTH_PROCESS_PASS"); Qt.exit(0)
  }
 }
}
'''.replace(' BLOCK', block).replace('SETUP', setup).replace('EXPECTED', expected))
            entry = plugin / 'shell.qml'
            entry.write_text('import Quickshell\nimport "' + variant + '/panels" as Panel\nShellRoot { Panel.Probe {} }\n')
            result = subprocess.run(['qs', '-n', '-p', str(entry)], capture_output=True,
                                    text=True, env=dict(os.environ), timeout=8)
            output = result.stdout + result.stderr
            assert result.returncode == 0 and 'AUTH_PROCESS_PASS' in output, output
            print(f'{variant}: {mode} passed')
