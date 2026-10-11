#!/usr/bin/env python3
"""Exercise real Qt FileView persistence with controller methods and inert dispatch."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
assert os.environ.get('WAYLAND_DISPLAY') and os.environ.get('XDG_RUNTIME_DIR')
with tempfile.TemporaryDirectory(prefix='display-position-', dir=os.environ['TMPDIR']) as folder:
    root = Path(folder)
    home = root / 'home'
    (home / '.cache/quickshell-rise').mkdir(parents=True)
    production = (repo / 'versions/V1/modules/DisplayManagerController.qml').read_text()
    start = production.index('    function command(args) {')
    end = production.index('    function applyMonitor(', start)
    # Replace only external dispatch in the scratch copy; production methods and FileView stay real.
    production = production[:start] + '    property var dispatchProbe: []\n    function command(args) { dispatchProbe = args; return true }\n' + production[end:]
    (root / 'Controller.qml').write_text(production)
    (root / 'shell.qml').write_text('''import QtQuick
import Quickshell
Scope {
 id: test
 property int ticks: 0
 property bool dispatched: false
 QtObject { id: theme; property bool displayManagerAutoWorkspaces: true }
 Controller { id: c; theme: theme }
 function fail(message) { console.error("POSITION_RUNTIME_FAIL " + message); Qt.quit() }
 Timer {
  interval: 20; running: true; repeat: true
  onTriggered: {
   if (++test.ticks > 150) { test.fail("load timeout: " + c.error); return }
   if (!c.displayStateReady) return
   stop()
   var active={name:"DP-1",width:2560,height:1440,x:0,y:560,scale:1,transform:0,disabled:false,mirrorOf:"none",refreshRate:155}
   var target={name:"DP-2",width:2560,height:1440,x:2579,y:-50,scale:1.25,transform:1,disabled:false,mirrorOf:"none",refreshRate:59.951}
   if (Quickshell.env("MEMORY_TEST_MODE") === "capture") {
    c.monitors=[active,target]
    c.positions=({"DP-2":{x:123,y:456}})
    if (!c.disableMonitor("DP-2") || c.dispatchProbe.length === 0 || !c.displayStateSaved) { test.fail("disable persistence " + c.error); return }
    console.log("POSITION_RUNTIME_PASS capture real FileView saved before inert dispatch")
   } else if (Quickshell.env("MEMORY_TEST_MODE") === "write-failure") {
    c.monitors=[active,target]
    if (c.disableMonitor("DP-2") || c.dispatchProbe.length > 0) { test.fail("write failure dispatched disable"); return }
    console.log("POSITION_RUNTIME_PASS write failure rejects disable")
   } else {
    target.disabled=true;target.x=0;target.y=0;target.width=0;target.height=0;target.transform=0;target.scale=1;target.refreshRate=0
    c.monitors=[active,target]
    c.positions=({"DP-2":{x:0,y:0}})
    if(!c.enableMonitor("DP-2") || c.dispatchProbe.length === 0) { test.fail("restore from disk: " + c.error); return }
    var args = c.dispatchProbe
    for (var key of ["--monitor", "--mode", "--x", "--y", "--scale", "--transform", "--mirror"]) {
     var expected = ({"--monitor":"DP-2", "--mode":"2560x1440@59.951", "--x":"2579", "--y":"-50", "--scale":"1.25", "--transform":"1", "--mirror":"none"})[key]
     if(args[args.indexOf(key)+1]!==expected) { test.fail("wrong restored " + key); return }
    }
    console.log("POSITION_RUNTIME_PASS fresh process restores saved position/mode/scale/rotation")
   }
   Qt.quit()
  }
 }
}
''')
    env = os.environ.copy()
    env.pop('DISPLAY', None)
    env.update(HOME=str(home), QT_QPA_PLATFORM='wayland', RISE_DISPLAY_MANAGER_APPLY='/usr/bin/false', RISE_DISPLAY_MANAGER_GUARD='/usr/bin/false')
    for mode in ['capture', 'restore', 'write-failure']:
        env['MEMORY_TEST_MODE'] = mode
        if mode == 'write-failure':
            denied_home = root / 'read-only-home'
            denied_dir = denied_home / '.cache/quickshell-rise'
            denied_dir.mkdir(parents=True)
            denied_dir.chmod(0o500)
            env['HOME'] = str(denied_home)
        try:
            result = subprocess.run(['qs', '-n', '-p', str(root / 'shell.qml')], env=env, text=True, capture_output=True, timeout=7)
        except subprocess.TimeoutExpired as exc:
            raise AssertionError(f'{mode}: {(exc.stdout or b"").decode(errors="replace")} {(exc.stderr or b"").decode(errors="replace")}') from exc
        output = result.stdout + result.stderr
        assert result.returncode == 0 and 'POSITION_RUNTIME_PASS' in output and 'POSITION_RUNTIME_FAIL' not in output, output
        assert not any(s in output for s in ['ReferenceError', 'TypeError', 'Cannot assign']), output
        if mode == 'capture':
            saved = json.loads((home / '.cache/quickshell-rise/display-return-states.json').read_text())
            assert saved['DP-2']['x'] == 2579 and saved['DP-2']['y'] == -50
        print(next(line[line.index('POSITION_RUNTIME_PASS'):] for line in output.splitlines() if 'POSITION_RUNTIME_PASS' in line))
