#!/usr/bin/env python3
"""Test the production Copilot header geometry using real Qt text metrics."""
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
for variant in ('versions/V1', 'versions/V1/variants/V2'):
    source = (repo / variant / 'panels/AiUsagePanel.qml').read_text()
    start = source.index('                Item {', source.index('// ── GitHub Copilot'))
    end = source.index('                UiText {\n                    visible:', start)
    header = source[start:end].replace('UiText {', 'Text {')
    qml = '''import QtQuick
import Quickshell
ShellRoot {
 id: aiPanel
 property bool showCopilot: true
 property string cpPlan: "Individual · free educational"
 property bool cpFresh: true
 property QtObject root: QtObject {
  property color ink: "white"
  property color sumi: "gray"
  property color sealRaw: "orange"
  property string mono: "monospace"
 }
 Item { id: host; width: 336
 __PRODUCTION_HEADER__
 }
 Timer { interval: 100; running: true; onTriggered: {
  var header = host.children[0]; var title = header.children[0]; var status = header.children[1];
  if (title.x + title.width > status.x - 7 || header.height < title.implicitHeight || title.lineCount < 2) {
   console.error("AI_HEADER_OVERFLOW", title.width, status.x, header.height, title.implicitHeight, title.lineCount);
   Qt.exit(1); return;
  }
  console.log("AI_HEADER_GEOMETRY_PASS"); Qt.exit(0);
 }}
}
'''.replace('__PRODUCTION_HEADER__', header)
    with tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR')) as temp:
        path = Path(temp) / 'shell.qml'
        path.write_text(qml)
        env = dict(os.environ)
        env.pop('DISPLAY', None)
        result = subprocess.run(['qs', '-n', '--path', str(path)], env=env,
                                text=True, capture_output=True, timeout=12)
        output = result.stdout + result.stderr
        print(variant, output)
        if result.returncode or 'AI_HEADER_GEOMETRY_PASS' not in output:
            raise SystemExit(result.returncode or 1)
print('AI_COPILOT_HEADER_RUNTIME_PASS both variants; extracted production header, Qt text metrics')
