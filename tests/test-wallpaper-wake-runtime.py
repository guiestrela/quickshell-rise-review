#!/usr/bin/env python3
"""Real Process wake snapshots + actual wallpaper event callbacks, effects inert."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

REPO=Path(__file__).resolve().parents[1]
BRIDGE=REPO/'versions/V1/core/WallpaperWakeBridge.qml'
assert BRIDGE.exists(), 'Missing safe bridge: wake control remains disabled in scoped host'
with tempfile.TemporaryDirectory(prefix='wake-runtime-',dir=os.environ['TMPDIR']) as directory:
    temp=Path(directory);state=temp/'state';state.write_text('{"schema":1,"locked":false,"screensaverShowing":false}')
    reader=temp/'reader.py';reader.write_text('import pathlib\nprint((pathlib.Path(__file__).parent/"state").read_text())\n')
    source=BRIDGE.read_text()
    begin=source.index('    readonly property string readerPath:')
    end=source.index('\n',begin)
    source=source[:begin]+'    readonly property string readerPath: '+json.dumps(str(reader))+source[end:]
    source=source.replace('interval: 1000','interval: 30')
    (temp/'WallpaperWakeBridge.qml').write_text(source)
    for variant,rel in enumerate(['versions/V1/modules/WallpaperManagerService.qml','versions/V1/variants/V2/modules/WallpaperManagerService.qml'],1):
        service=(REPO/rel).read_text();start=service.index('    function wakeShuffle()');end=service.index('        function onWallpaperManagerFolderChanged()',start)
        event=service[start:end]+'    }\n'
        event=event.replace('interval: 400','interval: 40')
        (temp/f'WakeV{variant}.qml').write_text('import QtQuick\nItem { id: manager; required property var theme; property string pinnedPath:""; property int calls:0; function hasShuffleOutput(){return true} function shuffleAll(force){calls++}\n'+event+'}\n')
    qml='''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
 property int phase: 0
 property int stableTicks: 0
 WallpaperWakeBridge { id: bridge }
 QtObject {
  id: theme
  property bool wallpaperShuffleOnWake:true
  readonly property bool wallpaperWakeAvailable: bridge.available
  readonly property bool wallpaperSessionLocked: bridge.locked
  readonly property bool wallpaperScreensaverShowing: bridge.screensaverShowing
 }
 WakeV1 { id: one; theme:theme }
 WakeV2 { id: two; theme:theme }
 FileView { id: state; path: STATE_FILE; blockWrites:true; atomicWrites:true }
 function setState(locked,showing){state.setText(JSON.stringify({schema:1,locked:locked,screensaverShowing:showing}))}
 function check(ok,message){if(!ok){console.error("WAKE_RUNTIME_FAIL",phase,message);Qt.quit();throw Error(message)}}
 function count(n){check(one.calls===n&&two.calls===n,"shuffle count V1/V2 expected "+n)}
 Timer {interval:30;repeat:true;running:true;onTriggered:{
  if(phase===0&&bridge.available){count(0);setState(true,false);phase++}
  else if(phase===1&&bridge.locked){count(0);setState(false,false);phase++}
  else if(phase===2&&one.calls===1&&two.calls===1){setState(false,true);phase++}
  else if(phase===3&&bridge.screensaverShowing){count(1);setState(false,false);phase++}
  else if(phase===4&&one.calls===2&&two.calls===2){setState(true,false);phase++}
  else if(phase===5&&bridge.locked){state.setText("malformed");phase++}
  else if(phase===6&&!bridge.available){count(2);setState(false,false);phase++}
  else if(phase===7&&bridge.available&&!bridge.locked){if(++stableTicks<5)return;count(2);theme.wallpaperShuffleOnWake=false;setState(true,false);phase++}
  else if(phase===8&&bridge.locked){setState(false,false);phase++}
  else if(phase===9&&!bridge.locked){if(++stableTicks<10)return;count(2);console.log("WAKE_RUNTIME_PASS V1/V2 unlock/screensaver, first sample/recovery/disabled inert");Qt.quit()}
 }}
 Timer {interval:4500;running:true;onTriggered:{console.error("WAKE_RUNTIME_FAIL timeout");Qt.quit()}}
}
'''.replace('STATE_FILE',json.dumps(str(state)))
    probe=temp/'shell.qml';probe.write_text(qml)
    env=os.environ.copy();env.pop('DISPLAY',None);env['QT_QPA_PLATFORM']='wayland'
    result=subprocess.run(['qs','-n','-p',str(probe)],env=env,capture_output=True,text=True,timeout=6)
    output=result.stdout+result.stderr
    assert result.returncode==0 and 'WAKE_RUNTIME_PASS' in output and 'WAKE_RUNTIME_FAIL' not in output,output
    assert not any(s in output for s in ['ReferenceError','TypeError','Cannot assign']),output
    print('PASS: actual Process + V1/V2 wallpaper callbacks; unlock/screensaver each once, no startup/recovery/off shuffle; helper/state private, selection backend inert, zero real session/wallpaper changes')
