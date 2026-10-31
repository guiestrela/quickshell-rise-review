#!/usr/bin/env python3
"""Exercise production wallpaper controls with inert service and file chooser."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-wallpanel-', dir='/tmp') as directory:
    base = Path(directory)
    runtime = base / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant, relative in [('V1','versions/V1'),('V2','versions/V1/variants/V2')]:
        source = repo / relative
        folder = base / variant
        panels, modules = folder / 'panels', folder / 'modules'
        panels.mkdir(parents=True)
        modules.mkdir()
        text = (source / 'panels/WallpaperManagerQuickPanel.qml').read_text()
        text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n','',text,flags=re.M)
        text = text.replace('PanelWindow {','Rectangle {\n width:1000; height:900\n property var screen',1)
        text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n','',text,flags=re.M)
        (panels/'WallpaperManagerQuickPanel.qml').write_text(text)
        (modules/'PillShadow.qml').write_bytes((source/'modules/PillShadow.qml').read_bytes())
        (modules/'SidePanelPositioner.qml').write_bytes((source/'modules/SidePanelPositioner.qml').read_bytes())
        (modules/'ConnectedPanelSurface.qml').write_text('import QtQuick\nItem { property var root; property bool ownerActive; property real targetX; property real reveal }')
        (modules/'WallpaperExternalPicker.qml').write_text('''import QtQuick
Item {
 property bool busy:false; property string targetDisplay:"all"; property url currentFolder
 property url selectedFolder; property url selectedFile; property string selectionKind
 signal accepted(); signal failed(string message)
 function open() { busy=true }
}
''')
        theme=[]
        colors={'fillActive','fillHover','fillIdle','ink','muted','paper','pillBorder','seal','sep'}
        functions={'setWallpaperPerDisplay','setWallpaperProfile','setWallpaperShuffleSettings','wallpaperProfileFor'}
        values={'activePopupScreen':'({width:1000,height:900})',
                'wallpaperManagerServiceApi':'service','wallpaperManagerSettings':'({perDisplayConfig:true})',
                'wallpaperOutputs':'[{name:"DP-1"},{name:"DP-2"}]'}
        strings={'mono':'monospace','wallpaperManagerDisplay':'DP-1',
                 'wallpaperManagerTab':'displays','currentBackgroundsPath':'/fixture'}
        for field in sorted(set(re.findall(r'panel\.root\.(\w+)',text))):
            if field in functions: continue
            if field in colors: theme.append(f'property color {field}: "#999999"')
            elif field in values: theme.append(f'property var {field}: {values[field]}')
            elif field in strings: theme.append(f'property string {field}: "{strings[field]}"')
            elif field in {'wallpaperManagerVisible','wallpaperShuffleOnWake','wallpaperWakeAvailable'}:
                theme.append(f'property bool {field}: false')
            else: theme.append(f'property real {field}: 6')
        theme += ['property bool styleShadow:false','property color pillShadow: "black"','property bool barVertical:false','property real verticalBarWidth:40',
                  'function verticalAnchorY(name) { return 200 }',
                  'property var saved: ({folder:"/fixture",pinned:"",recursive:false,mode:"single",scaling:"zoom"})',
                  'function wallpaperProfileFor(display) { return saved }',
                  'function setWallpaperProfile(patch) { var next=Object.assign({},saved,patch); saved=next }',
                  'function setWallpaperPerDisplay(value) { wallpaperManagerSettings=({perDisplayConfig:value}) }',
                  'function setWallpaperShuffleSettings(patch) {}']
        qml='''import QtQuick
import QtTest
import "VARIANT/panels"
Item {
 width:1000; height:900
 QtObject { id:service
  property bool scanInFlight:false
  property var scanJobs:[]; property var scanErrors:({}); property var pool:[]
  property var liveScreens:[{name:"DP-1"},{name:"DP-2"}]
  function pathFor(name) { return "" }
  function countFor(name) { return 0 }
  function poolFor(name) { return [] }
  function outputNames() { return ["DP-1","DP-2"] }
  function nextAll() {}
  function scanFolder(name) {}
 }
 QtObject { id:theme; THEME }
 WallpaperManagerQuickPanel { id:panel; root:theme }
 TestCase {
  name:"WallpaperVARIANT"; when:windowShown
  function test_controls_and_busy_dismissal() {
   theme.wallpaperManagerVisible=true
   tryCompare(panel,"visible",true)
   var fit=findChild(panel,"wallpaper-scale-fitWidth")
   verify(fit !== null)
   function clickButton(button) {
    for(var i=0;i<button.children.length;i++) {
     if(button.children[i].toString().indexOf("MouseArea")>=0) {
      mouseClick(button.children[i]); return
     }
    }
    fail("button has no pointer handler")
   }
   clickButton(fit)
   compare(theme.saved.scaling,"fitWidth")
   compare(fit.selected,true)
   var second=findChild(panel,"wallpaper-display-DP-2")
   clickButton(second)
   compare(theme.wallpaperManagerDisplay,"DP-2")
   compare(second.selected,true)
   panel.folderPicker.busy=true
   compare(panel.visible,false)
   panel.dismiss()
   compare(theme.wallpaperManagerVisible,true)
   panel.folderPicker.busy=false
   compare(panel.visible,true)
   panel.dismiss()
   compare(theme.wallpaperManagerVisible,false)
  }
 }
}
'''.replace('VARIANT',variant).replace('THEME','\n'.join(theme))
        probe=base/f'tst_{variant}.qml'
        probe.write_text(qml)
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',
                 QT_QPA_PLATFORMTHEME='',XDG_RUNTIME_DIR=str(runtime))
        result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(probe)],env=env,
                              capture_output=True,text=True,timeout=15)
        output=result.stdout+result.stderr
        print(output,end='')
        if result.returncode: raise SystemExit(result.returncode)
        assert not any(e in output for e in ['ReferenceError','TypeError','Binding loop','Unable to assign',' ERROR'])
