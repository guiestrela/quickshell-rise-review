#!/usr/bin/env python3
"""Exercise tray panels with fake apps; never access the session tray service."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

repo=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-tray-',dir='/tmp') as directory:
    base=Path(directory)
    runtime=base/'runtime'
    runtime.mkdir(mode=0o700)
    for variant,path in [('V1','versions/V1'),('V2','versions/V1/variants/V2')]:
        folder=base/variant
        panels,modules=folder/'panels',folder/'modules'
        panels.mkdir(parents=True); modules.mkdir()
        text=(repo/path/'panels/TrayPanel.qml').read_text()
        text=re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n','',text,flags=re.M)
        text=text.replace('PanelWindow {','Rectangle {\n width:800; height:700\n property var screen',1)
        text=re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n','',text,flags=re.M)
        text=text.replace('SystemTray.items.values','trayPanel.root.fixtureItems').replace('SystemTray.items','trayPanel.root.fixtureItems')
        text=text.replace('SystemTrayItem modelData','var modelData').replace('Status.NeedsAttention','"attention"')
        for identity in ['appRow','activateMa','pinMa','menuMa']:
            text=text.replace('id: '+identity+'\n','id: '+identity+'; objectName: "'+identity+'"\n')
        (panels/'TrayPanel.qml').write_text(text)
        for name in ['UiText','PillShadow','SidePanelPositioner','TooltipMixin']:
            (modules/f'{name}.qml').write_bytes((repo/path/'modules'/f'{name}.qml').read_bytes())
        (modules/'ConnectedPanelSurface.qml').write_text('import QtQuick\nItem { property var root; property bool ownerActive; property real targetX; property real reveal }')
        fields=set(re.findall(r'trayPanel\.root\.(\w+)',text))
        theme=[]
        functions={'trayDisplayName','trayDescription','openTrayMenu','trayToggleHide'}
        colors={'bg','pillBorder','panelBorder','ink','sumi','sumiHi','fillHover','fillIdle','seal','sep'}
        for field in sorted(fields):
            if field in functions or field=='fixtureItems': continue
            if field in colors: theme.append(f'property color {field}: "#999999"')
            elif field=='activePopupScreen': theme.append('property var activePopupScreen: ({width:800,height:700})')
            elif field=='trayPinned': theme.append('property var trayPinned: []')
            elif field=='trayVisible': theme.append('property bool trayVisible: false')
            elif field in {'mono','barPosition'}: theme.append(f'property string {field}: "'+('monospace' if field=='mono' else 'top')+'"')
            else: theme.append(f'property real {field}: 6')
        theme+=['property bool barVertical:false','property real verticalBarWidth:40',
                'property bool styleShadow:false','property color pillShadow:"black"',
                'property var tooltipOwner:null','property string tooltipText:""',
                'function showTooltip() {}','function hideTooltip() {}',
                'function verticalAnchorY(name) { return 200 }',
                'property int activations:0','property int menus:0',
                'property var fixtureItems: [{id:"fixture",status:"attention",hasMenu:true,onlyMenu:false,menu:({}),icon:"",activate:function(){theme.activations++}}]',
                'function trayDisplayName(item) { return item.id }',
                'function trayDescription(item,name) { return "Fixture description" }',
                'function openTrayMenu() { menus++ }',
                'function trayToggleHide(item) { trayPinned=[item.id] }']
        qml='''import QtQuick
import QtTest
import "VARIANT/panels"
Item {
 width:800; height:700
 QtObject { id:theme; THEME }
 TrayPanel { id:panel; root:theme }
 TestCase {
  name:"TrayVARIANT"; when:windowShown
  function test_actions_and_pinning() {
   compare(panel.hiddenCount,1)
   compare(panel.attentionCount,1)
   theme.trayVisible=true
   tryCompare(panel,"visible",true)
   mouseClick(findChild(panel,"menuMa"))
   compare(theme.menus,1)
   mouseClick(findChild(panel,"activateMa"))
   compare(theme.trayVisible,false)
   tryCompare(theme,"activations",1)
   theme.trayVisible=true
   tryCompare(panel,"visible",true)
   mouseClick(findChild(panel,"pinMa"))
   compare(theme.trayPinned,["fixture"])
   compare(panel.hiddenCount,0)
   compare(panel.attentionCount,0)
   compare(theme.trayVisible,false)
  }
 }
}
'''.replace('VARIANT',variant).replace('THEME','\n'.join(theme))
        probe=base/f'tst_{variant}.qml';probe.write_text(qml)
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',QT_QPA_PLATFORMTHEME='',XDG_RUNTIME_DIR=str(runtime))
        result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(probe)],env=env,capture_output=True,text=True,timeout=15)
        output=result.stdout+result.stderr;print(output,end='')
        if result.returncode: raise SystemExit(result.returncode)
        assert not any(e in output for e in ['ReferenceError','TypeError','Binding loop','Unable to assign',' ERROR'])
