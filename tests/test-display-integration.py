#!/usr/bin/env python3
"""Compile full variants (no instantiation) and real QML Process with inert CLIs."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
assert os.environ.get('WAYLAND_DISPLAY') and os.environ.get('XDG_RUNTIME_DIR'), 'Wayland runtime required'
with tempfile.TemporaryDirectory(prefix='display-integration-', dir=os.environ['TMPDIR']) as folder:
    root = Path(folder)
    shutil.copytree(repo / 'versions/V1', root / 'V1')
    helper = root / 'helper'
    helper.write_text('''#!/usr/bin/python3
import json, sys, time, os
from pathlib import Path
if sys.argv[2] == 'monitors':
 if Path(os.environ['DISPLAY_QUERY_GATE']).exists() and Path(os.environ['DISPLAY_QUERY_GATE']).read_text()=='slow': time.sleep(30)
 print(json.dumps([dict(name='DP-1',width=2560,height=1440,refreshRate=59.95,x=0,y=0,scale=1,transform=0,disabled=False,mirrorOf='none',availableModes=['2560x1440@59.95Hz'])]))
elif sys.argv[2] == 'text-size':
 if sys.argv[-1]=='12': time.sleep(30)
 print('text size updated')
else:
 time.sleep(.15); print('fixture operation denied',file=sys.stderr); sys.exit(1)
''')
    helper.chmod(0o700)
    guard = root / 'guard'
    guard.write_text("""#!/usr/bin/python3
import json,sys,time,os
from pathlib import Path
p=Path(os.environ['DISPLAY_GUARD_STATE']); token='a'*32
if sys.argv[1]=='--apply':
 args=json.loads(sys.argv[2])
 if args[args.index('--mode')+1]!='preferred':
  time.sleep(.15);print('fixture operation denied',file=sys.stderr);sys.exit(1)
 if sys.argv[-1]!='5':print('Expected five-second confirmation',file=sys.stderr);sys.exit(1)
 data=dict(token=token,status='pending',remaining=5,deadline=time.monotonic()+1.2)
elif sys.argv[1]=='--confirm':data=dict(token=token,status='confirmed',remaining=0)
elif sys.argv[1]=='--revert':data=dict(token=token,status='reverted',remaining=0)
else:
 data=json.loads(p.read_text())
 if data['status']=='pending' and time.monotonic()>=data['deadline']:data['status']='reverted';data['remaining']=0
p.write_text(json.dumps(data));print(json.dumps(data))
""")
    guard.chmod(0o700)
    binpath = root / 'bin'; binpath.mkdir()
    state = binpath / 'omarchy-monitor-state'
    state.write_text('#!/usr/bin/python3\nprint("70\\na\\nb\\nc\\nd\\nDP-1\\ne\\n[]")\n'); state.chmod(0o700)
    shell = root / 'shell.qml'
    shell.write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "V1/modules" as Modules
import "V1" as VariantOne
import "V1/variants/V2" as VariantTwo
Scope {
 id: test
 property int phase: 0
 property int ticks: 0
 property var components: []
 FileView { id: gate; path: Quickshell.env("DISPLAY_QUERY_GATE"); printErrors: false }
 QtObject { id: theme; property bool displayManagerAutoWorkspaces: true }
 Modules.DisplayManagerController { id: c; theme: theme }
 function fail(message) { console.error("DISPLAY_INTEGRATION_FAIL " + message); Qt.quit() }
 Component.onCompleted: {
  for (var path of ["V1/Theme.qml","V1/variants/V2/Theme.qml", "V1/VariantRoot.qml", "V1/variants/V2/VariantRoot.qml"]) {
   var component=Qt.createComponent(path)
   components.push(component)
   if (component.status === Component.Error) { fail(component.errorString()); return }
  }
  c.positions=({"DP-1":{x:999,y:999},"DISCONNECTED":{x:0,y:0}})
  c.refresh()
 }
 Timer {
  interval: 25; running: true; repeat: true
  onTriggered: {
   test.ticks++
   if(test.ticks>200) { test.fail("bounded fixture timeout phase="+test.phase+" error="+c.error); return }
   if(test.phase===0 && !c.loading) {
    if(c.monitors.length!==1 || c.monitors[0].refreshRate!==59.95 || !c.brightnessAvailable) { test.fail("real query lifecycle: "+c.error); return }
    if(c.positions["DP-1"].x!==0 || c.positions["DISCONNECTED"]!==undefined) { test.fail("stale positions survive refresh"); return }
    if(!c.applyMonitor("DP-1","2560x1440@59.95Hz",0,0,1,0,"none")) { test.fail("dispatch"); return }
    if(c.applyMonitor("DP-1","preferred",0,0,1,0,"none")) { test.fail("busy guard"); return }
    c.refresh()
    if(c.loading) { test.fail("query launched during action"); return }
    test.phase=1
   } else if(test.phase===1 && !c.busy && !c.loading) {
    if(!c.error.includes("fixture operation denied")) { test.fail("stderr lifecycle "+c.error); return }
    c.actionTimeoutMs=250
    c.setTextSize(3)
    test.ticks=0; test.phase=2
   } else if(test.phase===2 && !c.busy && !c.loading) {
    if(c.pendingTextSizeIndex!==-1) { test.fail("timed-out text size remains pending"); return }
    if(!c.error.toLowerCase().includes("timed out")) { test.fail("timeout must remain visible "+c.error); return }
    for(var component of test.components) if(component.status!==Component.Ready) { test.fail(component.errorString()); return }
    c.queryTimeoutMs=250
    gate.setText("slow")
    c.refresh()
    test.ticks=0; test.phase=3
   } else if(test.phase===3 && !c.loading) {
    if(!c.error.toLowerCase().includes("query timed out")) { test.fail("query watchdog "+c.error); return }
    gate.setText("fast")
    c.refresh(); test.phase=4
   } else if(test.phase===4 && !c.loading) {
    if(c.monitors.length!==1 || c.error!=="") { test.fail("query recovery"); return }
    c.setTextSize(4); test.phase=5
   } else if(test.phase===5 && !c.busy && !c.loading) {
    if(c.textSizeIndex!==4 || c.error!=="") { test.fail("successful text size selection"); return }
    c.actionTimeoutMs=15000
    c.applyMonitor("DP-1","preferred",0,0,1,0,"none"); test.phase=6
   } else if(test.phase===6 && !c.busy && !c.loading) {
    if(c.rollbackPending!==true || c.rollbackSeconds!==5) { test.fail("missing confirmation timer"); return }
    if(c.saveLayout() || c.applyMonitor("DP-1","preferred",0,0,1,0,"none")) { test.fail("pending guard allows changes/save"); return }
    c.confirmChanges(); test.phase=7
   } else if(test.phase===7 && !c.confirmationBusy && !c.rollbackPending && !c.loading) {
    if(c.error!=="" || c.rollbackSeconds!==0) { test.fail("keep failed "+c.error); return }
    c.applyMonitor("DP-1","preferred",0,0,1,0,"none"); test.phase=8
   } else if(test.phase===8 && !c.busy && !c.loading) {
    if(c.rollbackPending!==true) { test.fail("second apply not protected"); return }
    c.revertChanges(); test.phase=9
   } else if(test.phase===9 && !c.confirmationBusy && !c.rollbackPending && !c.loading) {
    if(!c.error.includes("restored")) { test.fail("manual revert not reported "+c.error); return }
    c.applyMonitor("DP-1","preferred",0,0,1,0,"none"); test.phase=10
   } else if(test.phase===10 && !c.busy && !c.loading) {
    if(c.rollbackPending!==true) { test.fail("third apply not protected"); return }
    test.ticks=0; test.phase=11
   } else if(test.phase===11 && !c.rollbackPending && !c.loading) {
    if(!c.error.includes("restored")) { test.fail("automatic revert not reported "+c.error); return }
    console.log("DISPLAY_INTEGRATION_PASS variants compile; Process query/error/busy/timeouts/confirmation/keep/manual+automatic revert")
    Qt.quit()
   }
  }
 }
}
''')
    env = os.environ.copy(); env.pop('DISPLAY', None)
    env.update(QT_QPA_PLATFORM='wayland', RISE_DISPLAY_MANAGER_APPLY=str(helper), RISE_DISPLAY_MANAGER_GUARD=str(guard), DISPLAY_GUARD_STATE=str(root/'guard-state'), DISPLAY_QUERY_GATE=str(root/'query-gate'), PATH=str(binpath)+':'+env['PATH'])
    result = subprocess.run(['qs','-n','-p',str(shell)], env=env, text=True, capture_output=True, timeout=12)
    output = re.sub(r'\x1b\[[0-9;]*m','', result.stdout+result.stderr)
    assert result.returncode==0 and 'DISPLAY_INTEGRATION_PASS' in output and 'DISPLAY_INTEGRATION_FAIL' not in output, output
    assert not re.search(r'(ReferenceError|TypeError|Cannot assign|is not a type)', output), output
    print('DISPLAY_INTEGRATION_PASS variants compile; Process query/error/busy/timeouts/confirmation/keep/manual+automatic revert')
