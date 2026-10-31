#!/usr/bin/env python3
"""Exercise production media browsers with inert workers and fictitious paths."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-media-browser-', dir='/tmp') as directory:
    base = Path(directory)
    runtime = base / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant, source in [('V1','versions/V1'),('V2','versions/V1/variants/V2')]:
        folder = base / variant
        folder.mkdir()
        text = (repo / source / 'panels/MediaBrowserPanel.qml').read_text()
        text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', text, flags=re.M)
        text = text.replace('PanelWindow {', 'Rectangle {\n width:1200; height:900\n property var screen', 1)
        text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n', '', text, flags=re.M)
        text = text.replace('Process {','InertProcess {').replace('StdioCollector {','InertCollector {')
        text = text.replace('Quickshell.env("HOME")','"/fixture"')
        text = text.replace('Quickshell.execDetached(["xdg-open", path])','panel.root.recordOpen(path)')
        text = text.replace('id: stage\n','id: stage; objectName: "stage"\n')
        for identity in ['deleteProc','copyProc','scanProc','warmProc']:
            text = re.sub(r'\bid: '+identity+r'(?=;|\n)', 'id: '+identity+'; objectName: "'+identity+'"', text)
        (folder / 'MediaBrowserPanel.qml').write_text(text)
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
            if field in {'openImagePicker','pinWallpaper','setWallpaperManagerFolder','recordOpen'}: continue
            if field in colors: theme.append(f'property color {field}: "#999999"')
            elif field=='activePopupScreen': theme.append('property var activePopupScreen: ({width:1200,height:900})')
            elif field=='wallpaperSourcePaths': theme.append('property var wallpaperSourcePaths: []')
            elif field=='mediaBrowserVisible': theme.append('property bool mediaBrowserVisible: false')
            elif field=='tileRadius': theme.append('property real tileRadius: 6')
            else: theme.append(f'property string {field}: ""')
        theme+=['property string opened: ""','function recordOpen(path) { opened=path }']
        qml='''import QtQuick
import QtTest
import "VARIANT"
Item {
 width:1200; height:900
 QtObject { id: theme; THEME }
 MediaBrowserPanel { id: picker; root:theme }
 TestCase {
  name:"MediaBrowserVARIANT"; when:windowShown
  function test_filter_delete_confirmation_and_close() {
   theme.mediaBrowserMode="screenshots"
   theme.mediaBrowserVisible=true
   picker.applyScan("/fixture/blue.png\\n/fixture/red.png",false)
   compare(picker.filtered.length,2)
   picker.moveSel(100)
   compare(picker.selFilt,1)
   picker.filterText="blue"
   compare(picker.filtered.length,1)
   compare(picker.selFilt,0)
   picker.filterText=""
   tryCompare(picker,"ready",true)
   var stage=findChild(picker,"stage")
   verify(stage !== null)
   stage.forceActiveFocus()
   var worker=findChild(picker,"deleteProc")
   keyClick(Qt.Key_Delete)
   compare(picker.confirmDelete,true)
   compare(worker.running,false)
   keyClick(Qt.Key_Escape)
   compare(picker.confirmDelete,false)
   compare(worker.running,false)
   keyClick(Qt.Key_Delete)
   keyClick(Qt.Key_Delete)
   compare(worker.running,true)
   verify(worker.command[2].indexOf("gio trash")>=0)
   compare(picker.confirmDelete,false)
   picker.copyFocused()
   compare(findChild(picker,"copyProc").running,true)
   picker.openSelected()
   compare(theme.opened,"/fixture/blue.png")
   compare(theme.mediaBrowserVisible,false)
   compare(picker.loaded,false)
   compare(picker.imageArray.length,0)
   compare(findChild(picker,"scanProc").running,false)
   compare(findChild(picker,"warmProc").running,false)
   picker.applyScan("/fixture/late.png",false)
   compare(picker.imageArray.length,0)
  }
 }
}
'''.replace('VARIANT',variant).replace('THEME','\n'.join(theme))
        thumbnail=base/'thumbnail.svg'
        thumbnail.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="2" height="2"><rect width="2" height="2" fill="gray"/></svg>')
        qml=qml.replace('/fixture/blue.png\\n/fixture/red.png', '/fixture/blue.png\\t'+str(thumbnail)+'\\n/fixture/red.png\\t'+str(thumbnail))
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
