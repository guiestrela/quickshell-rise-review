#!/usr/bin/env python3
"""QtTest pointer events against production visual tree in inert normal Window.
Layer-shell wrapper is replaced only in this fixture; not a live bar action.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile
repo=Path(__file__).resolve().parents[1]
source=(repo/'versions/V1/panels/DisplayManagerPanel.qml').read_text()
base=(repo/'versions/V1/tests/qr-display-panel-runtime.qml').read_text()
with tempfile.TemporaryDirectory(prefix='display-pointer-',dir=os.environ['TMPDIR']) as directory:
 folder=Path(directory); (folder/'panels').mkdir()
 visual=source.replace('import Quickshell\n','').replace('import Quickshell.Wayland\n','').replace('import QtQuick\n','import QtQuick\nimport QtQuick.Window\n').replace('PanelWindow {','Window {',1)
 visual = re.sub(r'    anchors \{[^}]*\}', '', visual, count=1)
 visual=re.sub(r'^    (?:WlrLayershell\..*|exclusionMode:.*|margins\..*)\n','',visual,flags=re.M)
 visual=visual.replace('    id: panel', '    id: panel\n    width: 520\n    height: 900',1)
 (folder/'panels/DisplayManagerPanel.qml').write_text(visual)
 fixture=base.replace('import Quickshell\n','').replace('import Quickshell.Wayland\n','').replace('ShellRoot {','Item {').replace('property bool displayManagerVisible: false','property bool displayManagerVisible: true').replace('Quickshell.screens.length ? Quickshell.screens[0] : null','Qt.application.screens[0]').replace('import "../panels" as Panels','import "panels" as Panels\nimport QtTest')
 fixture=fixture.replace('property color bg: "#202020"','property color bg: "#202020"\n property color paper: "#202020"\n property color fillHover: "#404040"\n property color sumi: "#808080"\n property int pillRadius: 6\n property color pillBorder: "#606060"\n property real pillBorderW: 1\n property real panelRadius: 6\n property real v2BarHeight: 30')
 fixture=fixture.replace('property var monitors: []','property var monitors: [{name:"DP-1",width:2560,height:1440,x:0,y:0,scale:1,transform:0,refreshRate:59.95,mirrorOf:"none"},{name:"DP-2",width:1920,height:1080,x:2560,y:0,scale:1,transform:0,refreshRate:60,mirrorOf:"none"}]\n property var calls: []\n property var positions: ({})')
 fixture=fixture.replace('property string selectedMonitor: ""','property string selectedMonitor: "DP-1"')
 fixture=fixture.replace('function monitor(name) { return null }','function monitor(name) { for(var m of monitors) if(m.name===name)return m; return null }')
 fixture=fixture.replace('function applyMonitor() { }','function applyMonitor(name,mode,x,y,scale,transform,mirror) { calls.push([name,mode,x,y,scale,transform,mirror]); return true }')
 fixture=fixture.replace('property bool busy: false','property bool busy: false\n property bool rollbackPending: false\n property int rollbackSeconds: 15\n property bool confirmationBusy: false\n property int keepCalls: 0\n property int revertCalls: 0\n function confirmChanges() { keepCalls++; rollbackPending=false }\n function revertChanges() { revertCalls++; rollbackPending=false }')
 fixture=fixture.replace('property bool brightnessAvailable: false' ,'property bool brightnessAvailable: true\n property var brightnessCalls: []')
 fixture=fixture.replace('function setBrightness() { }','function setBrightness(value) { brightnessCalls.push(value) }')
 fixture=fixture.replace('function setPosition() { }','function setPosition(name,x,y) { var next=Object.assign({},positions); next[name]={x:x,y:y}; positions=next }')
 fixture=fixture.replace('id: productionPanel; root: fakeRoot','id: productionPanel; root: fakeRoot; visible: true')
 controllerSource=(repo/'versions/V1/modules/DisplayManagerController.qml').read_text()
 toggleCode=controllerSource[controllerSource.index('    function toggleMirror()'):controllerSource.index('    function enableMonitor(name)')]
 fixture=fixture.replace('function applyMonitor(name,mode,x,y,scale,transform,mirror)', 'property var mirrorReturnStates: ({})\n'+toggleCode+'\nfunction applyMonitor(name,mode,x,y,scale,transform,mirror)')
 start=fixture.index('    Timer {')
 fixture=fixture[:start]+'''
    function find(item,name) {
      if(item.objectName===name) return item
      for(var child of item.children || []) { var match=find(child,name); if(match)return match }
      return null
    }
    TestCase { id: pointer; parent: productionPanel.contentItem; name: "DisplayPointer"; when: windowShown
      function test_pointerGeometry() {
        wait(300)
        try {
          var header=find(productionPanel.contentItem,"display-v1-title")
          var close=find(productionPanel.contentItem,"display-v1-close")
          var refresh=find(productionPanel.contentItem,"display-refresh")
          var frame=productionPanel.surfaceHost
          if(!header || !close || !refresh || header.font.pixelSize!==13 || header.font.letterSpacing!==2 || header.parent.height!==24 || !refresh.visible) throw new Error("V1 NordVPN header missing")
          if(frame.color!==fakeRoot.bg || frame.radius!==fakeRoot.pillRadius || frame.border.color!==fakeRoot.pillBorder || frame.border.width!==fakeRoot.pillBorderW) throw new Error("V1 native frame mismatch")
          productionPanel.requestActivate()
          pointer.mouseClick(frame,frame.width/2,12)
          pointer.wait(50)
          var stage=find(productionPanel.contentItem,"display-canvas")
          var card=null
          for(var child of stage.children) if(child.modelData && child.modelData.name==="DP-1") card=child
          if(!card) throw new Error("monitor delegate absent")
          var area=card.children[1], ratio=stage.ratio, originX=card.x, originY=card.y
          pointer.mousePress(area,15,15,Qt.LeftButton)
          if(!area.pressed) throw new Error("drag press not delivered: enabled="+area.enabled+" activeWindow="+productionPanel.active+" point="+JSON.stringify(area.mapToItem(productionPanel.contentItem,15,15)))
          pointer.mouseMove(area,35,25,80)
          pointer.mouseMove(area,55,35,80)
          pointer.mouseRelease(area,55,35,Qt.LeftButton)
          pointer.wait(100)
          if(fakeController.calls.length!==0 || Math.abs(card.x-originX)>.01 || Math.abs(card.y-originY)>.01 || fakeController.error.indexOf("cannot overlap")<0) throw new Error("overlapping mouse release must restore card and never dispatch: "+JSON.stringify(fakeController.calls))
          fakeController.error=""
          pointer.mousePress(area,70,30,Qt.LeftButton)
          pointer.mouseMove(area,50,30,80)
          pointer.mouseMove(area,30,30,80)
          pointer.mouseRelease(area,30,30,Qt.LeftButton)
          pointer.wait(100)
          if(fakeController.calls.length!==1 || fakeController.calls[0][2]>=0) throw new Error("pointer drag did not dispatch changed position: calls="+JSON.stringify(fakeController.calls)+" card="+[card.x,card.y,card.width,card.height]+" area="+[area.x,area.y,area.width,area.height]+" stage="+[stage.x,stage.y,stage.width,stage.height]+" window="+[productionPanel.width,productionPanel.height])
          console.log("DISPLAY_POINTER_PASS QtTest events; normal Window fixture")
          var rows=find(productionPanel.contentItem,"display-save").parent
          var column=rows.parent
          var footer=column.children[column.children.length-1]
          if(frame.width!==456 || footer.lineCount<2 || footer.text.replace(/\\s+/g," ")!=="Layout save creates a backup before updating the managed monitors.lua block.") throw new Error("footer must remain complete, wrap, and panel must narrow to 456")
          for(var row of column.children) if(row.children && row.children.length>1) {
            var rowRight=0
            for(var element of row.children) if(element.visible) rowRight=Math.max(rowRight,element.x+element.width)
            if(rowRight>row.width+1) throw new Error("narrow panel row clipped: "+rowRight+" > "+row.width)
          }
          productionPanel.connectedStyle=true
          pointer.wait(50)
          if(frame.width!==456 || footer.lineCount<2) throw new Error("V2 shared panel lost narrow/wrapped footer")
          for(var v2row of column.children) if(v2row.children && v2row.children.length>1) {
            var v2right=0
            for(var v2element of v2row.children) if(v2element.visible) v2right=Math.max(v2right,v2element.x+v2element.width)
            if(v2right>v2row.width+1) throw new Error("V2 narrow row clipped: "+v2right+" > "+v2row.width)
          }
          productionPanel.connectedStyle=false
          pointer.wait(50)
          var footerBottom=footer.mapToItem(frame,0,footer.height).y
          if(footerBottom > frame.height-12+1) throw new Error("footer clipped / scrollbar needed: "+footerBottom+" > "+(frame.height-12))
          var children=rows.children, right=0
          for(var child of children) right=Math.max(right,child.x+child.width)
          if(right>rows.width+1) throw new Error("save row overflows: "+right+" > "+rows.width)
          var mirrorButton=find(productionPanel.contentItem,"display-mirror")
          var mirrorBefore=fakeController.monitors.map(function(m){return Object.assign({},m)})
          var mirrorCalls=fakeController.calls.length
          if(mirrorButton.text!=="Mirror · OFF") throw new Error("Mirror OFF does not reflect compositor state")
          pointer.mouseClick(mirrorButton)
          if(fakeController.calls.length!==mirrorCalls+1 || fakeController.calls[mirrorCalls][6]!=="DP-2") throw new Error("Mirror ON click not dispatched")
          var mirrored=mirrorBefore.map(function(m){return Object.assign({},m)})
          mirrored[0].mirrorOf="DP-2"; mirrored[0].x=2560; mirrored[0].y=0; mirrored[0].refreshRate=60
          fakeController.monitors=mirrored
          pointer.wait(50)
          if(mirrorButton.text!=="Mirror · ON") throw new Error("Mirror ON does not reflect compositor state")
          productionPanel.connectedStyle=true
          pointer.mouseClick(mirrorButton)
          var returnCall=fakeController.calls[mirrorCalls+1]
          if(fakeController.calls.length!==mirrorCalls+2 || returnCall[6]!=="none" || returnCall[2]!==mirrorBefore[0].x || returnCall[3]!==mirrorBefore[0].y || returnCall[1]!=="2560x1440@59.950") throw new Error("Mirror OFF click failed to restore pre-mirror geometry/mode")
          fakeController.rollbackPending=true
          pointer.mouseClick(mirrorButton)
          if(fakeController.calls.length!==mirrorCalls+2) throw new Error("Mirror toggle not blocked during confirmation")
          fakeController.rollbackPending=false
          productionPanel.connectedStyle=false
          fakeController.monitors=mirrorBefore
          fakeController.calls.splice(mirrorCalls)
          pointer.wait(50)
          console.log("DISPLAY_MIRROR_POINTER_PASS ON V1/OFF V2, true state label, original mode/position, pending blocked; backend inert")
          var toggle=find(productionPanel.contentItem,"display-workspaces")
          productionPanel.requestActivate()
          productionPanel.contentItem.forceActiveFocus()
          toggle.forceActiveFocus()
          pointer.wait(50)
          var oldValue=fakeRoot.displayManagerAutoWorkspaces
          pointer.keyClick(Qt.Key_Space)
          pointer.wait(50)
          if(fakeRoot.displayManagerAutoWorkspaces===oldValue) throw new Error("workspace toggle inert by keyboard")
          var apply=find(productionPanel.contentItem,"display-position-apply"), spin=apply.parent.children[1]
          pointer.mouseClick(spin.contentItem,spin.contentItem.width/2,spin.contentItem.height/2)
          pointer.tryVerify(function() { return spin.contentItem.activeFocus },1000)
          pointer.keyClick(Qt.Key_A,Qt.ControlModifier)
          pointer.keyClick(Qt.Key_1); pointer.keyClick(Qt.Key_2); pointer.keyClick(Qt.Key_3)
          pointer.keyClick(Qt.Key_Return)
          pointer.mouseClick(apply,apply.width/2,apply.height/2)
          pointer.wait(50)
          if(fakeController.calls[fakeController.calls.length-1][2]!==123) throw new Error("SpinBox edit did not reach Apply: value="+spin.value+" text="+spin.contentItem.text+" focus="+spin.contentItem.activeFocus+" calls="+JSON.stringify(fakeController.calls))
          pointer.mouseClick(spin,12,spin.height/2)
          pointer.wait(50)
          if(spin.value!==122) throw new Error("minus must decrement once: value="+spin.value+" down="+JSON.stringify(spin.down.indicator.mapToItem(spin,0,0))+" up="+JSON.stringify(spin.up.indicator.mapToItem(spin,0,0)))
          pointer.mouseClick(spin,spin.width-12,spin.height/2)
          pointer.wait(50)
          if(spin.value!==123) throw new Error("plus must increment once")
          pointer.mouseClick(spin.contentItem,spin.contentItem.width/2,spin.contentItem.height/2)
          spin.contentItem.forceActiveFocus()
          pointer.keyClick(Qt.Key_A,Qt.ControlModifier)
          pointer.keyClick(Qt.Key_7)
          pointer.mouseClick(apply,apply.width/2,apply.height/2)
          pointer.wait(50)
          if(fakeController.calls[fakeController.calls.length-1][2]!==7) throw new Error("Apply without Enter ignored typed value: value="+spin.value+" text="+spin.contentItem.text+" calls="+JSON.stringify(fakeController.calls))
          var ySpin=apply.parent.children[2], previousY=ySpin.value
          pointer.mouseClick(ySpin,12,ySpin.height/2)
          pointer.wait(50)
          if(ySpin.value!==previousY-1) throw new Error("Y minus did not decrement")
          pointer.mouseClick(ySpin,ySpin.width-12,ySpin.height/2)
          pointer.wait(50)
          if(ySpin.value!==previousY) throw new Error("Y plus did not increment")
          pointer.mouseClick(ySpin.contentItem,ySpin.contentItem.width/2,ySpin.contentItem.height/2)
          ySpin.contentItem.forceActiveFocus()
          pointer.keyClick(Qt.Key_A,Qt.ControlModifier); pointer.keyClick(Qt.Key_5)
          pointer.mouseClick(apply,apply.width/2,apply.height/2)
          pointer.wait(50)
          if(fakeController.calls[fakeController.calls.length-1][3]!==5) throw new Error("Apply ignored typed Y without Enter")
          console.log("DISPLAY_STEPPER_APPLY_PASS X/Y minus/plus/typed Apply without Enter")
          var brightness=find(productionPanel.contentItem,"display-brightness")
          fakeController.brightnessCalls = []
          var oldBrightness = brightness.value
          brightness.forceActiveFocus()
          pointer.keyClick(Qt.Key_Right)
          pointer.wait(250)
          if(brightness.value===oldBrightness || fakeController.brightnessCalls.length!==1 || Math.round(fakeController.brightnessCalls[0])!==Math.round(brightness.value)) throw new Error("brightness keyboard must dispatch changed value once")
          console.log("DISPLAY_GEOMETRY_PASS save row; KEYBOARD_PASS toggle/SpinBox/brightness")
          fakeController.rollbackPending=true
          pointer.wait(100)
          var keep=find(productionPanel.contentItem,"display-keep"), revert=find(productionPanel.contentItem,"display-revert")
          var countdown=find(productionPanel.contentItem,"display-confirmation-countdown")
          if(!keep || !revert || !keep.visible || !countdown.text.includes("15") || apply.enabled || find(productionPanel.contentItem,"display-save").enabled) throw new Error("missing confirmation UI or pending guard")
          pointer.mouseClick(keep,keep.width/2,keep.height/2)
          pointer.wait(50)
          if(fakeController.keepCalls!==1 || fakeController.rollbackPending) throw new Error("Keep click inert")
          fakeController.rollbackPending=true
          pointer.wait(50)
          pointer.mouseClick(revert,revert.width/2,revert.height/2)
          pointer.wait(50)
          if(fakeController.revertCalls!==1 || fakeController.rollbackPending) throw new Error("Revert click inert")
          console.log("DISPLAY_CONFIRMATION_POINTER_PASS countdown/Keep/Revert/pending guards")
          productionPanel.requestActivate()
          pointer.mouseClick(frame,frame.width/2,12)
          frame.forceActiveFocus()
          pointer.wait(50)
          pointer.tryVerify(function() { return frame.activeFocus },1000)
          pointer.keyClick(Qt.Key_Escape)
          pointer.wait(50)
          if(fakeRoot.displayManagerVisible) throw new Error("V1 Escape did not dismiss like native panels")
          fakeRoot.displayManagerVisible=true
          pointer.wait(50)
          pointer.mouseClick(productionPanel.contentItem,productionPanel.width-4,productionPanel.height-4)
          pointer.wait(50)
          if(fakeRoot.displayManagerVisible) throw new Error("V1 outside click did not dismiss like native panels")
          fakeRoot.displayManagerVisible=true
          pointer.wait(50)
          pointer.mouseClick(frame,frame.width/2,12)
          if(!fakeRoot.displayManagerVisible) throw new Error("inside header click dismissed panel")
          pointer.mouseClick(close,close.width/2,close.height/2)
          pointer.wait(50)
          if(fakeRoot.displayManagerVisible) throw new Error("V1 X did not dismiss")
          console.log("DISPLAY_DISMISS_PASS V1 Escape/outside/X; inside preserved")
          fakeRoot.displayManagerVisible=true
          pointer.wait(50)

        } catch(error) { console.error("DISPLAY_POINTER_FAIL "+error); fail(String(error)) }
      }
    }
}'''
 (folder/'shell.qml').write_text(fixture)
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen'); env.pop('DISPLAY',None)
 result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(folder/'shell.qml')],env=env,text=True,capture_output=True,timeout=12)
 output=re.sub(r'\x1b\[[0-9;]*m','',result.stdout+result.stderr)
 if not (result.returncode==0 and 'DISPLAY_STEPPER_APPLY_PASS' in output and 'DISPLAY_CONFIRMATION_POINTER_PASS' in output and 'DISPLAY_POINTER_PASS' in output and 'DISPLAY_GEOMETRY_PASS' in output and 'DISPLAY_DISMISS_PASS' in output and 'DISPLAY_POINTER_FAIL' not in output):
  import shutil
  diagnostic=Path(os.environ['TMPDIR'])/'display-pointer-failed'
  shutil.copytree(folder,diagnostic,dirs_exist_ok=True)
  raise AssertionError(output+'\nDiagnostic: '+str(diagnostic))
 print('DISPLAY_POINTER_PASS QtTest events; normal Window fixture; DISPLAY_GEOMETRY_PASS save row; KEYBOARD_PASS toggle/SpinBox/brightness; DISPLAY_DISMISS_PASS V1 Escape/outside/X; DISPLAY_CONFIRMATION_POINTER_PASS countdown/Keep/Revert/pending guards')
