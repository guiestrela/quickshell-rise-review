#!/usr/bin/env python3
"""Exercise production media panel with an inert player and spectrum worker."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-mpris-', dir='/tmp') as directory:
    base = Path(directory)
    runtime = base / 'runtime'
    runtime.mkdir(mode=0o700)
    panels, modules = base / 'panels', base / 'modules'
    panels.mkdir()
    modules.mkdir()
    source = repo / os.environ.get('RISE_MPRIS_SOURCE','versions/V1')
    text = (source / 'panels/MprisPanel.qml').read_text()
    text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', text, flags=re.M)
    text = text.replace('PanelWindow {', 'Rectangle {\n    width: 800; height: 700\n    property var screen', 1)
    text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n', '', text, flags=re.M)
    text = text.replace('id: card\n', 'id: card; objectName: "card"\n')
    text = text.replace('Process {','InertProcess {').replace('FileView {','InertFileView {')
    (panels/'InertFileView.qml').write_text('import QtQuick\nQtObject { property string path; property bool watchChanges; property bool printErrors; signal fileChanged(); signal loaded(); signal loadFailed(); function reload() {} function text() { return "" } }')
    (panels/'InertProcess.qml').write_text('import QtQuick\nQtObject { property var command: []; property bool running:false; property var stdout }')
    (panels/'SplitParser.qml').write_text('import QtQuick\nQtObject { property string splitMarker; signal read(string line) }')
    (modules/'MprisArtwork.qml').write_text('import QtQuick\nItem { property var player; property string source: "" }')
    (modules/'MprisSelect.qml').write_text('''import QtQuick
Item {
 property var player: fake
 property bool active:true
 property bool playing:fake.playing
 QtObject { id:fake
  property string identity:"Fixture"; property string dbusName:"fixture"
  property string trackArtUrl:""; property string trackTitle:"Fixture song"
  property string trackArtist:"Fixture artist"; property string trackAlbum:"Fixture album"
  property real position:15; property real length:120
  property bool playing:false; property bool canGoPrevious:true; property bool canGoNext:true
  property int toggles:0
  function togglePlaying() { toggles++; playing=!playing }
  function previous() {} function next() {}
 }
}
''')
    (panels / 'MprisPanel.qml').write_text(text)
    for name in ['UiText', 'IconText', 'PillShadow', 'SidePanelPositioner']:
        (modules / f'{name}.qml').write_bytes((source / 'modules' / f'{name}.qml').read_bytes())
    (modules / 'ConnectedPanelSurface.qml').write_text('''import QtQuick
Item { property var root; property bool ownerActive; property real targetX; property real reveal }
''')
    theme = []
    colors = {'bg','pillBorder','fillActive','ink','panelBorder','seal','sep','sumi','sumiHi','color01','color03','color04','color05','color06','color07'}
    for field in sorted(set(re.findall(r'mprisPanel\.root\.(\w+)', text))):
        if field in colors:
            theme.append(f'property color {field}: "#999999"')
        elif field == 'activePopupScreen':
            theme.append('property var activePopupScreen: ({width:800,height:700})')
        elif field == 'mono':
            theme.append('property string mono: "monospace"')
        elif field == 'barPosition':
            theme.append('property string barPosition: "top"')
        elif field == 'mprisVisible':
            theme.append('property bool mprisVisible:false')
        elif field == 'omarchyCurrentRoot':
            theme.append('property string omarchyCurrentRoot:"/fixture"')
        else:
            theme.append(f'property real {field}: 6')
    theme += ['property bool barVertical: false', 'property real verticalBarWidth: 40',
              'property bool styleShadow: false', 'property color pillShadow: "black"',
              'function verticalAnchorY(name) { return 200 }']
    qml = '''import QtQuick
import QtTest
import "panels"
Item {
 width:800; height:700
 QtObject { id: theme; THEME }
 MprisPanel { id: panel; root: theme }
 TestCase {
  name: "MprisPanel"; when: windowShown
  function test_player_keyboard_and_lifecycle() {
   compare(panel.fmtTime(65),"1:05")
   compare(panel.fmtTime(-1),"0:00")
   theme.mprisVisible=true
   tryCompare(panel,"visible",true)
   tryCompare(panel,"curLen",120)
   compare(panel.curPos,15)
   var card=findChild(panel,"card")
   card.forceActiveFocus()
   keyClick(Qt.Key_Space)
   compare(panel.player.toggles,1)
   compare(panel.playing,true)
   panel.player.position=42
   tryVerify(function(){ return panel.curPos>=42 },1500)
   keyClick(Qt.Key_Escape)
   compare(theme.mprisVisible,false)
   tryCompare(panel,"visible",false)
   var finalPosition=panel.curPos
   wait(600)
   compare(panel.curPos,finalPosition)
  }
 }
}
'''.replace('THEME', '\n'.join(theme))
    probe = base / 'tst_mpris.qml'
    probe.write_text(qml)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               QT_QPA_PLATFORMTHEME='', XDG_RUNTIME_DIR=str(runtime))
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(probe)],
                            env=env, text=True, capture_output=True, timeout=15)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode:
        raise SystemExit(result.returncode)
    assert not any(error in output for error in ['ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign', ' ERROR'])
