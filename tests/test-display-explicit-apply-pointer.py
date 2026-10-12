#!/usr/bin/env python3
"""Qt6 pointer events on production panel; layer replaced by Window, controller inert."""
import os,re,subprocess,tempfile
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
source=(repo/'versions/V1/panels/DisplayManagerPanel.qml').read_text();base=(repo/'versions/V1/tests/qr-display-panel-runtime.qml').read_text()
controller=(repo/'versions/V1/modules/DisplayManagerController.qml').read_text()
def method(name):
 start=controller.index('    function '+name+'(');opening=controller.index('{',start);depth=1;i=opening+1
 while depth:
  if controller[i]=='{':depth+=1
  if controller[i]=='}':depth-=1
  i+=1
 return controller[start:i]
with tempfile.TemporaryDirectory(prefix='apply-pointer-',dir=os.environ['TMPDIR']) as directory:
 root=Path(directory);(root/'panels').mkdir()
 visual=source.replace('import Quickshell\n','').replace('import Quickshell.Wayland\n','').replace('import QtQuick\n','import QtQuick\nimport QtQuick.Window\n').replace('PanelWindow {','Window {',1)
 visual=re.sub(r'    anchors \{[^}]*\}','',visual,count=1);visual=re.sub(r'^    (?:WlrLayershell\..*|exclusionMode:.*|margins\..*)\n','',visual,flags=re.M);visual=visual.replace('    id: panel','    id: panel\n    width: 520\n    height: 900',1)
 (root/'panels/DisplayManagerPanel.qml').write_text(visual)
 fixture=base.replace('import Quickshell\n','').replace('import Quickshell.Wayland\n','').replace('ShellRoot {','Item {').replace('property bool displayManagerVisible: false','property bool displayManagerVisible: true').replace('Quickshell.screens.length ? Quickshell.screens[0] : null','Qt.application.screens[0]').replace('import "../panels" as Panels','import "panels" as Panels\nimport QtTest')
 fixture=fixture.replace('property color bg: "#202020"','property color bg: "#202020"\n property color paper: "#202020"\n property color fillHover: "#404040"\n property color sumi: "#808080"\n property int pillRadius: 6\n property color pillBorder: "#606060"\n property real pillBorderW: 1\n property real panelRadius: 6\n property real v2BarHeight: 30')
 fixture=fixture.replace('property var monitors: []','property var monitors: [{name:"DP-1",width:2560,height:1440,x:0,y:0,scale:1,transform:0,refreshRate:60,mirrorOf:"none",disabled:false,availableModes:["2560x1440@60Hz"]},{name:"DP-2",width:1920,height:1080,x:2560,y:0,scale:1,transform:0,refreshRate:60,mirrorOf:"none",disabled:false,availableModes:["1920x1080@60Hz"]}]')
 fixture=fixture.replace('property string selectedMonitor: ""','property string selectedMonitor: "DP-2"')
 fixture=fixture.replace('function monitor(name) { return null }','function monitor(name) { for(var m of monitors) if(m.name===name)return m;return null }')
 fixture=fixture.replace('property bool busy: false','property bool busy: false\n property bool rollbackPending:false\n property int rollbackSeconds:0\n property bool confirmationBusy:false\n property bool displayStateReady:true\n property var savedDisplayStates:({})\n property var positions:({})\n property var mirrorReturnStates:({})\n property int backendCalls:0\n function confirmChanges(){rollbackPending=false}\n function revertChanges(){rollbackPending=false}')
 fixture=fixture.replace('property bool brightnessAvailable: false','property bool brightnessAvailable: true').replace('property int brightnessPercent: 0','property int brightnessPercent: 70')
 for name in ['applyMonitor','disableMonitor','setBrightness','setTextSize']:
  fixture=fixture.replace('function '+name+'() { }','function '+name+'() { backendCalls++ }')
 fixture=fixture.replace('function enableMonitor() { }',method('enableMonitor'))
 fixture=fixture.replace('function refresh() { refreshCount++ }',method('toggleMirror')+'\n function refresh() { refreshCount++ }')
 fixture=fixture.replace('function applyDrafts() { applyCalls.push','function applyDrafts() { rollbackPending=true;rollbackSeconds=5;applyCalls.push')
 fixture=fixture.replace('id: productionPanel\n','id: productionPanel; visible: true\n')
 fixture=fixture[:fixture.index('    Timer {')]+'''
 function find(item,name){if(item.objectName===name)return item;for(var child of item.children||[]){var result=find(child,name);if(result)return result}return null}
 TestCase { id: pointer; parent:productionPanel.contentItem; name:"ExplicitApplyPointer"; when:windowShown
  function test_00_mode_display(){
   wait(200)
   var mode=find(productionPanel.contentItem,"display-resolution")
   for(var connected of [false,true]) {
    productionPanel.connectedStyle=connected;fakeController.drafts=({});fakeController.selectedMonitor="DP-1";wait(50)
    compare(mode.displayText,"2560x1440@60Hz")
    fakeController.stageMonitor("DP-1",{mode:"1920x1080@60"});wait(50)
    compare(mode.displayText,"1920x1080@60")
    fakeController.selectedMonitor="DP-2";wait(50)
    compare(mode.displayText,"1920x1080@60Hz")
    compare(fakeController.backendCalls,0);compare(fakeController.applyCalls.length,0);compare(fakeController.rollbackSeconds,0)
   }
   fakeController.drafts=({})
   console.log("MODE_DISPLAY_QML_PASS V1/V2 actual ComboBox displayText live/draft/monitor-switch with zero backend calls")
  }
  function test_edits_wait_for_Apply(){
   wait(250)
   for(var connected of [false,true]){
    productionPanel.connectedStyle=connected;fakeController.backendCalls=0;fakeController.drafts=({});fakeController.draftBrightness=({});fakeController.draftTextSizeIndex=-1;fakeController.applyCalls=[];fakeController.rollbackPending=false;fakeController.rollbackSeconds=0;fakeController.selectedMonitor="DP-2";fakeRoot.displayManagerAutoWorkspaces=true;productionPanel.draftAutoWorkspaces=true
    fakeController.draftWorkspaceAssignments=({})
    wait(80);productionPanel.requestActivate()
    var workspaceRow=find(productionPanel.contentItem,"display-monitor-workspaces")
    var scaleControl=find(productionPanel.contentItem,"display-scale")
    verify(workspaceRow.y>=scaleControl.parent.y+scaleControl.parent.height,"Workspaces row must be below Scale")
    var workspaceThree=find(productionPanel.contentItem,"display-workspace-3")
    mouseClick(workspaceThree);wait(30)
    verify(workspaceThree.checked);compare(fakeController.draftWorkspaceAssignments["3"],"DP-2")
    compare(fakeController.applyCalls.length,0);compare(fakeController.rollbackSeconds,0)
    for(var n=1;n<=10;n++) { var btn=find(productionPanel.contentItem,"display-workspace-"+n);verify(btn!==null);verify(btn.x+btn.width<=btn.parent.width+1,"Workspace buttons must fit the native row") }
    console.log("WORKSPACE_POINTER_PASS below Scale, ten native buttons, selected monitor ownership, zero Apply/timer before click V"+(connected?2:1))
    var stage=find(productionPanel.contentItem,"display-canvas"),card=null
    for(var child of stage.children)if(child.modelData&&child.modelData.name==="DP-2")card=child
    verify(card!==null)
    var area=card.children[1],point=area.mapToItem(productionPanel.contentItem,30,25)
    mousePress(productionPanel.contentItem,point.x,point.y,Qt.LeftButton)
    verify(area.pressed)
    mouseMove(productionPanel.contentItem,point.x+20,point.y,80)
    mouseMove(productionPanel.contentItem,point.x+8,point.y,80)
    mouseRelease(productionPanel.contentItem,point.x+8,point.y,Qt.LeftButton);wait(60)
    compare(fakeController.previewMonitor("DP-2").x,2560);compare(fakeController.applyCalls.length,0);compare(fakeController.backendCalls,0);compare(fakeController.rollbackSeconds,0);verify(!fakeController.rollbackPending)
    var rotation=find(productionPanel.contentItem,"display-rotation");rotation.currentIndex=1;rotation.activated(1)
    var scale=find(productionPanel.contentItem,"display-scale");scale.currentIndex=1;scale.activated(1)
    var mode=find(productionPanel.contentItem,"display-resolution");mode.currentIndex=1;mode.activated(1)
    var textSize=find(productionPanel.contentItem,"display-text-size");textSize.currentIndex=2;textSize.activated(2)
    var brightness=find(productionPanel.contentItem,"display-brightness");brightness.forceActiveFocus();keyClick(Qt.Key_Left);wait(40)
    var toggle=find(productionPanel.contentItem,"display-workspaces");mouseClick(toggle);wait(40)
    verify(fakeRoot.displayManagerAutoWorkspaces);verify(!productionPanel.draftAutoWorkspaces)
    var mirror=find(productionPanel.contentItem,"display-mirror");mouseClick(mirror);wait(40);mouseClick(mirror);wait(40)
    var disable=find(productionPanel.contentItem,"display-disable"),enable=find(productionPanel.contentItem,"display-enable");mouseClick(disable);wait(40);verify(fakeController.previewMonitor("DP-2").disabled);compare(fakeController.monitors[1].disabled,false);mouseClick(enable);wait(40);verify(!fakeController.previewMonitor("DP-2").disabled)
    compare(fakeController.backendCalls,2);compare(fakeController.applyCalls.length,0);compare(fakeController.rollbackSeconds,0);verify(!fakeController.rollbackPending)
    verify(!find(productionPanel.contentItem,"display-save").enabled)
    var apply=find(productionPanel.contentItem,"display-position-apply"),spinY=apply.parent.children[2]
    spinY.contentItem.forceActiveFocus();keyClick(Qt.Key_A,Qt.ControlModifier);keyClick(Qt.Key_1);keyClick(Qt.Key_0);keyClick(Qt.Key_0)
    compare(fakeController.applyCalls.length,0)
    mouseClick(apply);wait(60)
    compare(fakeController.applyCalls.length,1);compare(fakeController.rollbackSeconds,5);verify(fakeController.rollbackPending)
    compare(fakeController.applyCalls[0].monitors[1].y,100)
    verify(!fakeRoot.displayManagerAutoWorkspaces)
    var keep=find(productionPanel.contentItem,"display-keep");mouseClick(keep);wait(40);verify(!fakeController.rollbackPending)
   }
   console.log("EXPLICIT_APPLY_POINTER_PASS V1/V2 drag, mode/scale/rotation, Enable/Disable/Mirror/workspaces stay draft; brightness/font live without timer; typed Apply dispatches once and enables 5s; Keep click; layer Window + controller inert")
  }
 }
}
'''
 (root/'shell.qml').write_text(fixture)
 env=os.environ.copy();env.pop('DISPLAY',None);env['QT_QPA_PLATFORM']='wayland'
 z=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(root/'shell.qml')],env=env,capture_output=True,text=True,timeout=12);output=z.stdout+z.stderr
 assert z.returncode==0 and 'EXPLICIT_APPLY_POINTER_PASS' in output,output
 assert not any(k in output for k in ['ReferenceError','TypeError','Cannot assign']),output
 print(next(l[l.index('EXPLICIT_APPLY_POINTER_PASS'):] for l in output.splitlines() if 'EXPLICIT_APPLY_POINTER_PASS' in l))
 assert 'MODE_DISPLAY_QML_PASS' in output, output
 print(next(l[l.index('MODE_DISPLAY_QML_PASS'):] for l in output.splitlines() if 'MODE_DISPLAY_QML_PASS' in l))
 assert output.count('WORKSPACE_POINTER_PASS') == 2, output
 for line in output.splitlines():
  if 'WORKSPACE_POINTER_PASS' in line: print(line[line.index('WORKSPACE_POINTER_PASS'):])
