#!/usr/bin/env python3
"""Exercise production image pickers with inert workers and fictitious paths."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-picker-', dir='/tmp') as directory:
    base = Path(directory)
    runtime = base / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant, source in [('V1','versions/V1'),('V2','versions/V1/variants/V2')]:
        folder = base / variant
        folder.mkdir()
        text = (repo / source / 'panels/ImageCarouselPanel.qml').read_text()
        text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', text, flags=re.M)
        text = text.replace('PanelWindow {', 'Rectangle {\n width:1200; height:900\n property var screen', 1)
        text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n', '', text, flags=re.M)
        text = text.replace('Process {','InertProcess {').replace('StdioCollector {','InertCollector {')
        text = text.replace('Quickshell.env("HOME")','"/fixture"')
        text = text.replace('Quickshell.execDetached(["xdg-open", url])','theme.recordOpen(url)')
        for identity in ['applyThemeProc','applyBgProc']:
            text = text.replace('id: '+identity+';', 'id: '+identity+'; objectName: "'+identity+'";')
        (folder / 'ImageCarouselPanel.qml').write_text(text)
        (folder / 'ImagePickerModel.js').write_bytes((repo/source/'panels/ImagePickerModel.js').read_bytes())
        (folder/'InertProcess.qml').write_text('''import QtQuick
QtObject { property var command: []; property bool running: false; property var stdout; property var stderr; signal exited(int exitCode) }
''')
        (folder/'InertCollector.qml').write_text('''import QtQuick
QtObject { property string text: ""; property bool waitForEnd: false; signal streamFinished() }
''')
        (folder/'SplitParser.qml').write_text('import QtQuick\nQtObject { signal read(string line) }')
        (folder/'ClippingRectangle.qml').write_text('import QtQuick\nRectangle {}')
        fields=set(re.findall(r'panel\.root\.(\w+)',text))
        theme=[]
        colors={'fillHover','fillIdle','frameWeak','ink','paper','seal','sep','sumiHi'}
        for field in sorted(fields):
            if field in {'openImagePicker','pinWallpaper','setWallpaperManagerFolder'}: continue
            if field in colors: theme.append(f'property color {field}: "#999999"')
            elif field=='activePopupScreen': theme.append('property var activePopupScreen: ({width:1200,height:900})')
            elif field=='wallpaperSourcePaths': theme.append('property var wallpaperSourcePaths: []')
            elif field=='imagePickerVisible': theme.append('property bool imagePickerVisible: false')
            elif field=='tileRadius': theme.append('property real tileRadius: 6')
            else: theme.append(f'property string {field}: ""')
        theme+=['property string pinned: ""','function pinWallpaper(path) { pinned=path }',
                'function openImagePicker(mode) { imagePickerMode=mode; imagePickerVisible=true }',
                'function setWallpaperManagerFolder(path) { wallpaperManagerFolder=path }']
        qml='''import QtQuick
import QtTest
import "VARIANT"
Item {
 width:1200; height:900
 QtObject { id: theme; THEME }
 ImageCarouselPanel { id: picker; root:theme }
 TestCase {
  name:"ImagePickerVARIANT"; when:windowShown
  function test_filter_selection_and_apply() {
   picker.applyScan("/fixture/blue-sky.png\\n/fixture/red-sun.png",false)
   compare(picker.filtered.length,2)
   compare(picker.currentLabel,"Blue Sky")
   picker.moveSel(100)
   compare(picker.selFilt,1)
   picker.filterText="blue"
   compare(picker.filtered.length,1)
   compare(picker.selFilt,0)
   theme.imagePickerMode="wallpaper"
   theme.wallpaperManagerFolder="/fixture"
   picker.applySelected()
   compare(theme.pinned,"/fixture/blue-sky.png")
   picker.filterText=""
   theme.imagePickerMode="theme"
   theme.omarchyInstallRoot="/fixture/omarchy"
   picker.applySelected()
   var worker=findChild(picker,"applyThemeProc")
   compare(worker.running,true)
   compare(worker.command,["env","OMARCHY_PATH=/fixture/omarchy","omarchy-theme-set","blue-sky"])
   picker.filterText="missing"
   compare(picker.filtered.length,0)
   worker.running=false
   picker.applySelected()
   compare(worker.running,false)
   picker.applyScan("",false)
   compare(picker.imagesLoaded,false)
   compare(picker.scanDone,true)
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
