#!/usr/bin/env python3
"""Exercise the production detail row with the real UiText renderer."""
from pathlib import Path
import os
import subprocess
import tempfile
repo = Path(__file__).resolve().parents[1]
for variant in ('versions/V1', 'versions/V1/variants/V2'):
    source = (repo / variant / 'panels/AiUsagePanel.qml').read_text()
    start = source.index('    component DetailRow:')
    end = source.index('\n    // ── compact', start)
    component = source[start:end]
    qml = '''import QtQuick
import Quickshell
import "MODULES"
ShellRoot {
 id: aiPanel
 property QtObject root: QtObject {
  property color sumiHi: "gray"
  property color ink: "white"
  property string mono: "monospace"
 }
 __COMPONENT__
 Column { id: col; width: 336; spacing: 6
  DetailRow { k: "Local activity (1h, incl. cached)"; v: "492k tok/h" }
  DetailRow { k: "Weekly resets in"; v: "5d 22h • Tue 16:52" }
  DetailRow { k: "Latest"; v: "openai/very-long-model-name-for-layout-regression" }
 }
 Timer { interval: 100; running: true; onTriggered: {
  for (var i=0; i<col.children.length; i++) {
   var row=col.children[i], key=row.children[0], val=row.children[1];
   if (key.contentWidth > key.width + 1 || val.contentWidth > val.width + 1 || row.height < Math.max(key.implicitHeight,val.implicitHeight) || key.x + key.width > val.x - 5) {
    console.error("AI_DETAIL_OVERFLOW", i, key.contentWidth, key.width, val.contentWidth, val.width, row.height); Qt.exit(1); return;
   }
  }
  console.log("AI_DETAIL_ROW_RUNTIME_PASS"); Qt.exit(0);
 }}
}
'''.replace('MODULES', (repo / variant / 'modules').as_uri()).replace('__COMPONENT__', component)
    with tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR')) as temp:
        path=Path(temp)/'shell.qml'; path.write_text(qml)
        env=dict(os.environ);env.pop('DISPLAY',None)
        p=subprocess.run(['qs','-n','--path',str(path)],env=env,text=True,capture_output=True,timeout=12)
        output=p.stdout+p.stderr; print(variant,output)
        if p.returncode or 'AI_DETAIL_ROW_RUNTIME_PASS' not in output: raise SystemExit(p.returncode or 1)
