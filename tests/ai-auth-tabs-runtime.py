#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import tempfile

base = Path(__file__).resolve().parents[1]
for variant in ('versions/V1', 'versions/V1/variants/V2'):
    source = (base / variant / 'panels/AiUsagePanel.qml').read_text()
    assert 'function applyAuthStatus(states)' in source, 'Missing login-based tab filter'
    start = source.index('    function applyAuthStatus(states)')
    end = source.index('\n    Process {', start)
    function = source[start:end]
    assert 'model: aiPanel.availableTools' in source
    assert 'aiPanel.availableTools.length' in source
    qml = '''import QtQuick
import Quickshell
ShellRoot {
 id: aiPanel
 property var availableTools: []
 property bool authChecked: false
 property QtObject root: QtObject { property string aiTool: "claude" }
 FUNCTION
 Component.onCompleted: Qt.callLater(function() {
  applyAuthStatus({codex:true, copilot:true, claude:false, opencode:false});
  if (availableTools.length !== 3 || availableTools[0].id !== "codex" || availableTools[1].id !== "opencode" || root.aiTool !== "codex") { Qt.exit(1); return; }
  root.aiTool = "copilot";
  applyAuthStatus({codex:true, copilot:true});
  if (root.aiTool !== "copilot") { Qt.exit(2); return; }
  applyAuthStatus({codex:false, copilot:false});
  if (availableTools.length !== 1 || availableTools[0].id !== "opencode" || root.aiTool !== "opencode" || !authChecked) { Qt.exit(3); return; }
  applyAuthStatus({codex:"true", claude:null});
  if (availableTools.length !== 1 || availableTools[0].id !== "opencode") { Qt.exit(4); return; }
  console.log("AI_AUTH_TABS_RUNTIME_PASS"); Qt.exit(0);
 })
}
'''.replace(' FUNCTION', function)
    with tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR')) as temp:
        path = Path(temp) / 'shell.qml'
        path.write_text(qml)
        env = dict(os.environ)
        env.pop('DISPLAY', None)
        p = subprocess.run(['qs', '-n', '--path', str(path)], env=env, capture_output=True, text=True, timeout=12)
        text = p.stdout + p.stderr
        print(variant, text)
        assert p.returncode == 0 and 'AI_AUTH_TABS_RUNTIME_PASS' in text
