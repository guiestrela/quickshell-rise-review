#!/usr/bin/env python3
"""Exercise the exact percentage label binding from both production widgets."""
import os
from pathlib import Path
import subprocess
import tempfile
repo=Path(__file__).resolve().parents[1]
for v in ('versions/V1','versions/V1/variants/V2'):
    text=(repo/v/'modules/ClaudeWidget.qml').read_text()
    start=text.index('            text: rootMod.blocked')
    end=text.index('            color:',start)
    binding=text[start:end]
    qml='''import QtQuick
import Quickshell
ShellRoot {
 QtObject { id: rootMod
  property bool blocked: false
  property bool selSignal: false
  property bool selHas: true
  property int pct5h: 71
 }
 Text { id: label
 __BINDING__
 }
 Timer { interval: 100; running: true; onTriggered: {
  if(label.text !== "71%") { console.error("AI_PERCENT_STALE_LOST",label.text);Qt.exit(1);return; }
  rootMod.pct5h=0;
  if(label.text !== "00%") { Qt.exit(2);return; }
  rootMod.selHas=false;
  if(label.text !== "··") { Qt.exit(3);return; }
  rootMod.blocked=true;
  if(label.text !== "BLK") { Qt.exit(4);return; }
  console.log("AI_PERCENT_BINDING_PASS");Qt.exit(0);
 }}
}
'''.replace('__BINDING__',binding)
    with tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR')) as tmp:
        p=Path(tmp)/'shell.qml';p.write_text(qml)
        env=dict(os.environ);env.pop('DISPLAY',None)
        r=subprocess.run(['qs','-n','--path',str(p)],env=env,text=True,capture_output=True,timeout=12)
        out=r.stdout+r.stderr;print(v,out)
        if r.returncode or 'AI_PERCENT_BINDING_PASS' not in out:raise SystemExit(r.returncode or 1)
