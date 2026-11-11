#!/usr/bin/env python3
"""Exercise the production V1 SlotRow and drag handlers with inert widgets."""
from pathlib import Path
import os,subprocess,tempfile,shutil
repo=Path(__file__).resolve().parents[1]
source=(repo/'variants/V1/BarSlot.qml').read_text()
start=source.index('    component SlotRow: Row {');opening=source.index('{',start);depth=1;end=opening+1
while depth:
    depth += (source[end]=='{')-(source[end]=='}');end+=1
row=source[start:end]
drag=source[source.index('    property bool dragging:'):source.index('    // ── order persistence')]
with tempfile.TemporaryDirectory(prefix='rise-empty-slots-',dir=os.environ.get('TMPDIR')) as folder:
    base=Path(folder);runtime=base/'runtime';runtime.mkdir(mode=0o700)
    shutil.copy2(repo/'shared/logic/NordVpnLayout.js',base/'NordVpnLayout.js')
    qml='''pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "NordVpnLayout.js" as NordVpnLayout
Item {
 id:barSlot
 width:1000; height:70
 property var root: theme
 property color accent:theme.seal
 property bool _orderLoaded:false
 function saveOrder() {}
 QtObject {
  id:theme
  property bool barUnlocked:false
  property bool barVertical:false
  property bool layoutProtected:false
  property bool trayDragActive:false
  property bool trayDropActive:false
  property int wsPillPad:4
  property int pillRadius:12
  property int tileRadius:10
  property color fillIdle:"#222222"
  property color sep:"#555555"
  property color sumi:"#aaaaaa"
  property color seal:"#aaffaa"
  property string mono:"monospace"
 }
 Item {id:island;property int narrowStage:0;function groupVisibleAtStage(gid,stage){return true} function scheduleNarrowUpdate(){} }
 property var registry: ({G1:fixture,G8:fixture})
 Component {id:fixture;Rectangle {implicitWidth:34;implicitHeight:22;color:"#99aa99"}}
 DRAG
 ROW
 ListModel {id:leftModel;ListElement {gid:"G1"} ListElement {gid:""}}
 ListModel {id:centerModel;ListElement {gid:"G8"} ListElement {gid:""}}
 ListModel {id:rightModel;ListElement {gid:""}}
 SlotRow {id:leftRowItem;x:0;rmodel:leftModel}
 SlotRow {id:centerRowItem;x:400;rmodel:centerModel}
 SlotRow {id:rightRowItem;x:800;rmodel:rightModel}
 TestCase {
  name:"V1EmptySlots";when:windowShown
  function test_placeholders_and_drag() {
   wait(250)
   compare(leftRowItem.rep.itemAt(1).visible,false)
   compare(leftRowItem.width,34)
   barSlot.scale=0.7 // Edit mode can scale the bar on narrower outputs.
   theme.barUnlocked=true
   wait(300)
   verify(leftRowItem.rep.itemAt(1).visible)
   compare(leftRowItem.rep.itemAt(1).width,32)
   verify(centerRowItem.rep.itemAt(1).visible)
   mousePress(leftRowItem,15,16,Qt.LeftButton)
   verify(barSlot.dragging)
   var target=centerRowItem.rep.itemAt(1)
   var point=target.mapToItem(barSlot,5,16)
   mouseMove(barSlot,point.x,point.y,30)
   compare(barSlot.dropModel,centerModel)
   compare(barSlot.dropIndex,1)
   mouseRelease(barSlot,point.x,point.y,Qt.LeftButton)
   compare(centerModel.get(1).gid,"G1")
   compare(leftModel.get(0).gid,"")
   verify(!barSlot.dragging)
   theme.barUnlocked=false
   wait(300)
   compare(leftRowItem.rep.itemAt(0).visible,false)
   compare(leftRowItem.width,0)
   verify(centerRowItem.rep.itemAt(1).visible)
  }
 }
}
'''.replace('DRAG',drag).replace('ROW',row)
    probe=base/'tst_slots.qml';probe.write_text(qml)
    r=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(probe)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',QT_QPA_PLATFORMTHEME='',XDG_RUNTIME_DIR=str(runtime)),text=True,capture_output=True,timeout=20)
    output=r.stdout+r.stderr;print(output,end='')
    assert r.returncode==0,r.returncode
    assert not any(x in output for x in ['ReferenceError','TypeError','Binding loop','Unable to assign'])
