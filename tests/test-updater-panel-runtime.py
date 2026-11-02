#!/usr/bin/env python3
"""Shared updater UI and real variant adapters; Process and FileView are inert."""
from pathlib import Path
import json
import os
import re
import subprocess
import tempfile
from qml_fixture_source import qml_fixture_text, qml_fixture_bytes

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-updater-panel-', dir='/tmp') as directory:
    temp = Path(directory)
    runtime = temp / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant in ['V1', 'V2']:
        folder = temp / variant
        for sub in ['common', 'panels', 'modules']:
            (folder / sub).mkdir(parents=True)
        text = qml_fixture_text(repo / 'shared/panels/ArchUpdaterPanel.qml')
        text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', text, flags=re.M)
        text = text.replace('import QtQuick\n', 'import QtQuick\nimport "../modules"\n', 1)
        text = text.replace('PanelWindow {', 'Rectangle {\n width:900; height:700; property var screen', 1)
        text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n', '', text, flags=re.M)
        text = text.replace('Quickshell.env("HOME")', '"/fixture"')
        for name in ['packageBackendProbe', 'panelUpdateRunner', 'themeRemoveProc']:
            text = text.replace('id: ' + name + '\n', 'id: ' + name + '; objectName: "' + name + '"\n')
        (folder / 'common/ArchUpdaterPanel.qml').write_text(text)
        adapter = qml_fixture_text(repo / 'variants' / variant / 'panels/ArchUpdaterPanel.qml')
        (folder / 'panels/ArchUpdaterPanel.qml').write_text(adapter.replace('../../../shared/panels', '../common'))
        for name in ['UiText', 'IconText', 'TooltipMixin', 'PillShadow', 'SidePanelPositioner']:
            source = repo / 'shared/components' / (name + '.qml') if name in ['UiText', 'IconText', 'TooltipMixin'] else repo / 'variants' / variant / 'modules' / (name + '.qml')
            (folder / 'modules' / (name + '.qml')).write_bytes(qml_fixture_bytes(source))
        (folder / 'modules/ConnectedPanelSurface.qml').write_text('import QtQuick\nItem { objectName:"connected-surface"; property var root; property bool ownerActive; property real targetX; property real reveal }')
        (folder / 'common/Process.qml').write_text('''import QtQuick
QtObject { property var command:[]; property bool running:false; property var stdout; property var stderr; signal exited(int code); signal started() }
''')
        (folder / 'common/StdioCollector.qml').write_text('import QtQuick\nQtObject { property string text:""; property bool waitForEnd:false; signal streamFinished() }')
        (folder / 'common/FileView.qml').write_text('''import QtQuick
QtObject { property string path; property bool watchChanges:false; property string contents:"{}"; signal loaded(); signal fileChanged(); function text(){return contents} function reload(){} }
''')
        colors = {'bg','pillBorder','panelBorder','fillActive','fillHover','fillIdle','fillPrimaryHover','green','indigo','ink','inkDeep','paper','seal','sealRaw','sep','sumi'}
        strings = {'activeUpdateTab':'packages','archGateState':'clean','archGateListDate':'','archScanError':'','archScanHash':'fixture','archScanId':'fixture','themeUpdChecked':'','themeNamePath':'/fixture/theme.name','mono':'monospace','barPosition':'top','omarchyInstallRoot':'/fixture'}
        arrays = {'archUpdates','archGateResults','themeUpdList'}
        booleans = {'archVisible','archRefreshing','archGateDegraded','themeUpdChecking','themeUpdCurrentStale','themeUpdDegraded'}
        numbers = {'pillRadius':6,'panelRadius':12,'tileRadius':4,'panelButtonRadius':8,'pillBorderW':1,'v2BarHeight':33,'archBarX':400,'archCaretBarX':410,'archScanMaxAge':3600,'fillHoverAlpha':0.2}
        fields = sorted(set(re.findall(r'\broot\.(\w+)', text + '\n' + adapter)))
        theme = []
        for field in fields:
            if field in ['archGateRescan','closeArchUpdatesPanel']:
                continue
            if field == 'activePopupScreen':
                theme.append('property var activePopupScreen: ({width:900,height:700})')
            elif field in colors:
                theme.append('property color '+field+': "#999999"')
            elif field in strings:
                theme.append('property string '+field+': '+json.dumps(strings[field]))
            elif field in arrays:
                theme.append('property var '+field+': []')
            elif field in booleans:
                theme.append('property bool '+field+': false')
            else:
                theme.append('property real '+field+': '+str(numbers.get(field,0)))
        theme += ['property bool barVertical:false','property real verticalBarWidth:40','property bool styleShadow:false','property color pillShadow:"black"','property int gateCalls:0','function archGateRescan(){gateCalls++}','function closeArchUpdatesPanel(){archVisible=false}','function verticalAnchorY(name){return 300}','property var tooltipOwner:null','property string tooltipText:""','function showTooltip(){}','function hideTooltip(){}']
        qml = '''import QtQuick
import QtTest
import "VARIANT/panels"
Item {
 width:900; height:700
 QtObject { id:theme; THEME }
 ArchUpdaterPanel { id:panel; root:theme }
 TestCase {
  name:"UpdaterVARIANT"; when:windowShown
  function test_probe_guard_and_style() {
   var probe=findChild(panel,"packageBackendProbe")
   verify(probe.running);compare(probe.command[1],"--probe")
   verify(!panel.canUpdate)
   probe.stdout.text="arch\\tapply\\trelative-path\\t2";probe.stdout.streamFinished()
   compare(panel.packageUpdateBackend,"detecting")
   probe.stdout.text="arch\\tapply\\t/fixture/apply\\t2";probe.stdout.streamFinished()
   probe.running=false;probe.exited(0)
   verify(panel.packageUpdateBackendAvailable);verify(!panel.canUpdate,"empty repo scan must block a full upgrade")
   panel.packageUpdateBackend="probe-failed";panel.retryPackageBackendProbe()
   verify(probe.running);compare(panel.packageApplyProtocol,"")
   probe.stdout.text="omarchy\\tupdate\\t/fixture/update\\tlegacy";probe.stdout.streamFinished()
   probe.running=false;probe.exited(0)
   verify(panel.usesOmarchyUpdater);verify(panel.canUpdate)
   var runner=findChild(panel,"panelUpdateRunner")
   compare(runner.command.length,0);verify(!runner.running)
   theme.archVisible=true;tryCompare(panel,"reveal",1)
   var card=panel.surfaceHost, modern="VARIANT"==="V2"
   compare(card.width,520);verify(card.height<=460)
   compare(card.radius,modern?12:6);compare(card.border.width,modern?0:1)
   compare(card.color.a,modern?0:1);compare(panel.buttonRadius,modern?8:4)
   var surface=findChild(card,"connected-surface")
   compare(surface!==null,modern)
   if(modern)compare(surface.targetX,theme.archCaretBarX)
   theme.barPosition="bottom"
   tryVerify(function(){return Math.abs(card.y-(panel.height-panel.barBottom-panel.gap-card.height))<0.01})
   theme.barVertical=true;theme.barPosition="left"
   tryCompare(card,"x",theme.verticalBarWidth+panel.gap)
   theme.barVertical=false;theme.barPosition="top"
   tryCompare(card,"y",panel.barBottom+panel.gap)
   card.forceActiveFocus();keyClick(Qt.Key_Escape);compare(theme.archVisible,false)
   verify(!runner.running);compare(runner.command.length,0)
   verify(!findChild(panel,"themeRemoveProc").running)
  }
 }
}
'''.replace('VARIANT',variant).replace('THEME','\n'.join(theme))
        probe = temp / ('tst_' + variant + '.qml')
        probe.write_text(qml)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='', QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=str(runtime))
        result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(probe)],env=env,capture_output=True,text=True,timeout=15)
        output=result.stdout+result.stderr
        print(output,end='')
        assert result.returncode==0,output
        assert not re.search(r'ReferenceError|TypeError|Binding loop|Unable to assign',output),output
