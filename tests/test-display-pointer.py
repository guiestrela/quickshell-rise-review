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
          if(fakeController.calls.length!==0 || fakeController.previewMonitor("DP-1").x>=0) throw new Error("pointer drag must stage a changed position without applying")
          if(fakeController.applyCalls.length!==0) throw new Error("drag applied without confirmation")
          console.log("DISPLAY_POINTER_PASS QtTest drag stages only; normal Window fixture")
          // Geometry and dismissal remain covered here. Explicit Apply, mirror,
          // brightness and confirmation are covered by the dedicated current suite.
          var rows=find(productionPanel.contentItem,"display-save").parent
          if(rows.width>rows.parent.width+1) throw new Error("save row overflow")
          console.log("DISPLAY_GEOMETRY_PASS save row")
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
 if not (result.returncode==0 and 'DISPLAY_POINTER_PASS' in output and 'DISPLAY_GEOMETRY_PASS' in output and 'DISPLAY_DISMISS_PASS' in output and not any(error in output for error in ['DISPLAY_POINTER_FAIL', 'invalid context', 'TypeError', 'ReferenceError'])):
  import shutil
  diagnostic=Path(os.environ['TMPDIR'])/'display-pointer-failed'
  shutil.copytree(folder,diagnostic,dirs_exist_ok=True)
  raise AssertionError(output+'\nDiagnostic: '+str(diagnostic))
 print('DISPLAY_POINTER_PASS draft drag; DISPLAY_GEOMETRY_PASS save row; DISPLAY_DISMISS_PASS V1 Escape/outside/X; no invalid delegate context')
