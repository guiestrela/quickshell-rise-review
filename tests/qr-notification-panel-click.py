#!/usr/bin/env python3
"""Pointer regression for the exact production handlers, with an inert executor."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1] / 'versions/V1'
RUNNER = '/usr/lib/qt6/bin/qmltestrunner'


def extract(text, name):
    start = text.find('function ' + name + '(')
    if start < 0:
        return ''
    opening = text.index('{', start)
    depth, index = 1, opening + 1
    while depth:
        depth += (text[index] == '{') - (text[index] == '}')
        index += 1
    return text[start:index]


TEMPLATE = '''import QtQuick
import QtTest
import "NotificationActions.js" as NotificationActions
Item {
 width:400; height:300
 Item {
  id:notifPanel
  property var root: ({_notifOmarchyShellBackend:true,notifVisible:true})
  property var nativeBrowserClaims: ({})
  property string pendingNotificationKey: ""
  property var consumed: []
  function consumeNotification(key) { consumed=consumed.concat([key]) }
  property string notificationActionError:""
  property bool notificationReplySeen:false
  property string notificationActionHelper:"/fixture/notification-crash-action.py"
  property var modelData: ({id:11,active:true,backend:"omarchy",appName:"omarchy-action",summary:"Process crashed: fixture A",body:"Click to diagnose with AI",timestamp:2000000001})
  property var dispatched:[]
  function runNotificationAction(argv) { dispatched=dispatched.concat([argv]) }
  HANDLERS
  Rectangle {
   id:card
   width:300; height:100
   MouseArea { anchors.fill:parent; onClicked:notifPanel.openNotification(notifPanel.modelData) }
  }
 }
 Item { id:browserOpenProc; property bool running:false }
 Item { id:notificationOpenProc; property var command:[]; property bool running:false }
 TestCase {
  name:"VARIANT_SelectedNotificationPointer"
  when:windowShown
  function init() {
   notifPanel.root=({_notifOmarchyShellBackend:true,notifVisible:true})
   notifPanel.notificationActionError=""
   notifPanel.dispatched=[]
   notifPanel.nativeBrowserClaims=({})
   notifPanel.pendingNotificationKey=""
   notifPanel.consumed=[]
   notificationOpenProc.command=[];notificationOpenProc.running=false
  }
  function test_pointer_passes_selected_identity_not_invokeLast() {
   mouseClick(card,70,50,Qt.LeftButton)
   compare(notificationOpenProc.command.length,4)
   compare(notificationOpenProc.command[2],"--entry")
   var request=JSON.parse(notificationOpenProc.command[3])
   compare(request.id,11)
   compare(request.summary,"Process crashed: fixture A")
   compare(notifPanel.root.notifVisible,true)
   compare(notifPanel.dispatched.length,0)
  }
  function test_duplicate_pointer_does_not_restart_dispatch() {
   mouseClick(card,70,50,Qt.LeftButton)
   var before=JSON.stringify(notificationOpenProc.command)
   notifPanel.modelData.id=99
   mouseClick(card,70,50,Qt.LeftButton)
   compare(JSON.stringify(notificationOpenProc.command),before)
   notifPanel.modelData.id=11
  }
  function test_terminal_failure_cannot_be_overwritten_by_late_success() {
   mouseClick(card,70,50,Qt.LeftButton)
   notifPanel.finishNotificationAction({ok:false,message:"Notification action timed out."})
   notifPanel.finishNotificationAction({ok:true})
   compare(notifPanel.root.notifVisible,true)
   compare(notifPanel.notificationActionError,"Notification action timed out.")
  }
  function test_success_closes_only_after_launch_reply() {
   mouseClick(card,70,50,Qt.LeftButton)
   compare(notifPanel.root.notifVisible,true)
   notifPanel.finishNotificationAction({ok:true})
   compare(notifPanel.root.notifVisible,false)
  }
  function test_failure_remains_visible_and_explains() {
   mouseClick(card,70,50,Qt.LeftButton)
   notifPanel.finishNotificationAction({ok:false,message:"Verified crash unavailable"})
   compare(notifPanel.root.notifVisible,true)
   compare(notifPanel.notificationActionError,"Verified crash unavailable")
  }
 }
}
'''


def main():
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='', DISPLAY='')
    with tempfile.TemporaryDirectory(prefix='notif-pointer-') as directory:
        (Path(directory) / 'NotificationActions.js').write_bytes((ROOT / 'integrations/NotificationActions.js').read_bytes())
        for variant, source in [('V1', ROOT / 'panels/NotificationPanel.qml'),
                                ('V2', ROOT / 'variants/V2/panels/NotificationPanel.qml')]:
            text = source.read_text()
            assert 'onClicked: notifPanel.openNotification(notificationRow.modelData)' in text
            functions = '\n'.join(extract(text, name) for name in
                                  ['openNotification', 'finishNotificationAction'])
            path = Path(directory) / ('tst_' + variant + '.qml')
            path.write_text(TEMPLATE.replace('HANDLERS', functions).replace('VARIANT', variant))
            result = subprocess.run([RUNNER, '-input', str(path), '-o', '-,txt', '-v1'],
                                    capture_output=True, text=True, env=env, timeout=20)
            print(result.stdout + result.stderr)
            if result.returncode or '7 passed, 0 failed' not in result.stdout or any(
                    error in result.stdout + result.stderr for error in
                    ['ReferenceError','TypeError','Binding loop','Unable to assign']):
                return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
