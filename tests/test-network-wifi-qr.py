#!/usr/bin/env python3
"""Actual Qt pointer/keyboard on new production QR controls; native command is inert."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

REPO=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='wifi-qr-',dir=os.environ['TMPDIR']) as directory:
    tmp=Path(directory)
    (tmp/'qmldir').write_text('singleton Backend 1.0 Backend.qml\n')
    (tmp/'Backend.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var calls: []; property int exitCode: 0; property string reply: "ok" }')
    (tmp/'StdioCollector.qml').write_text('import QtQuick\nQtObject { property bool waitForEnd: false; property string text: "" }')
    (tmp/'Process.qml').write_text('''import QtQuick
import "." as Fixture
QtObject {
 id: p
 property var command: []
 property bool running: false
 property var stdout
 property var stderr
 signal exited(int exitCode)
 property Timer done: Timer {
  interval: 80
  onTriggered: {
   Fixture.Backend.calls=Fixture.Backend.calls.concat([p.command])
   p.stdout.text=Fixture.Backend.reply; p.running=false;p.exited(Fixture.Backend.exitCode)
  }
 }
 onRunningChanged: if(running) done.start()
}
''')
    (tmp/'UiText.qml').write_bytes((REPO/'versions/V1/modules/UiText.qml').read_bytes())
    for variant,rel in enumerate(['versions/V1/panels/NetworkPanel.qml','versions/V1/variants/V2/panels/NetworkPanel.qml'],1):
        source=(REPO/rel).read_text()
        assert source.index('objectName: "wifi-qr-button"')>source.index('id: speedFooter')
        assert source.index('objectName: "wifi-qr-button"')<source.index('// ── wifi radio toggle ──')
        logic=source[source.index('    property bool wifiQrOpening:'):source.index('    function resetWifiAction()',source.index('    property bool wifiQrOpening:'))] if '    function resetWifiAction()' in source else ''
        start=source.index('    property bool wifiQrOpening:')
        end=source.index('\n    property ',source.index('    Process {\n        id: wifiQrRunner',start)+10)
        logic=source[start:end]
        # Stop at the end of the Process block, before pre-existing panel declarations.
        logic=logic[:logic.index('\n    }',logic.index('    Process {'))+6]
        start=source.index('            // QR of the connected Wi-Fi')
        end=source.index('            Rectangle { width: parent.width; height: 1; color: root.sep; visible: netPanel.hasWifi }',start)
        button=source[start:end]
        qml='''import QtQuick
Item {
 id: netPanel
 property var root
 property bool nmAdapterReady: true
 property bool wifiBlocked: false
 property var networks: []
 property string mode: "ethernet"
'''+logic+'''
 Column { width: parent.width; spacing: 8
  Item { objectName: "speed-test-block"; width: parent.width; height: 24 }
'''+button+'\n }\n}\n'
        (tmp/f'QrV{variant}.qml').write_text(qml)
    qml='''import QtQuick
import QtTest
import "." as Fixture
Item {
 width: 300; height: 180
 QtObject {
  id: theme
  property bool useNM: true; property bool networkVisible: true
  property color seal: "#70a0c0"; property color sumi: "#888888"; property color sep: "#444444"
  property color fillHover: "#334455"; property color fillIdle: "#222222"
  property string mono: "monospace"; property int tileRadius: 4; property int panelButtonRadius: 6
 }
 Loader { id: load; width: 276; height: 160 }
 TestCase {
  name: "WifiQR"; when: windowShown
  function test_click_keyboard() {
   for(var variant=1;variant<=2;variant++) {
    load.setSource("QrV"+variant+".qml",{root:theme});tryCompare(load,"status",Loader.Ready)
    var panel=load.item;wait(30)
    var button=findChild(panel,"wifi-qr-button"),hit=findChild(panel,"wifi-qr-hit")
    verify(button!==null&&hit!==null)
    var speed=findChild(panel,"speed-test-block");verify(button.y>=speed.y+speed.height)
    Fixture.Backend.calls=[];theme.networkVisible=true;Fixture.Backend.exitCode=0
    verify(!button.enabled);mouseClick(hit);wait(120);compare(Fixture.Backend.calls.length,0)
    panel.networks=[{conn:true,sec:"enterprise"}];wait(20);verify(!button.enabled)
    panel.networks=[{conn:true,sec:"psk"}];wait(20);verify(button.enabled)
    compare(panel.mode,"ethernet") // VPN default route does not disable physical Wi-Fi sharing.
    mouseClick(hit);verify(panel.wifiQrOpening);verify(!panel.openWifiQr())
    tryCompare(panel,"wifiQrOpening",false,1000)
    compare(Fixture.Backend.calls.length,1)
    compare(Fixture.Backend.calls[0].join("|"),"/usr/bin/omarchy-shell|shell|summon|omarchy.wifiqr|{}")
    verify(!theme.networkVisible);compare(panel.wifiQrError,"")
    theme.networkVisible=true;Fixture.Backend.exitCode=1;button.forceActiveFocus();keyClick(Qt.Key_Space)
    wait(20);verify(panel.wifiQrOpening,"keyboard must dispatch");tryCompare(panel,"wifiQrOpening",false,1000);verify(theme.networkVisible);verify(panel.wifiQrError!=="")
    Fixture.Backend.exitCode=0;Fixture.Backend.reply="unknown";mouseClick(hit);tryCompare(panel,"wifiQrOpening",false,1000);verify(theme.networkVisible);verify(panel.wifiQrError!=="")
    Fixture.Backend.reply="ok"
    panel.wifiBlocked=true;wait(20);verify(!button.enabled)
    panel.wifiBlocked=false;theme.useNM=false;wait(20);verify(!button.enabled)
    theme.useNM=true
    console.log("WIFI_QR_POINTER_PASS V"+variant)
   }
  }
 }
}
'''
    test=tmp/'test.qml';test.write_text(qml)
    env=os.environ.copy();env.pop('DISPLAY',None);env['QT_QPA_PLATFORM']='wayland'
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(test)],env=env,capture_output=True,text=True,timeout=8)
    output=result.stdout+result.stderr
    assert result.returncode==0 and output.count('WIFI_QR_POINTER_PASS')==2,output
    assert not any(s in output for s in ['ReferenceError','TypeError','Cannot assign']),output
    print('PASS V1/V2: button below Speed Test; click/keyboard, disabled without connected supported Wi-Fi, VPN route, fixed native command, duplicate guard and failure; backend inert; no credentials accessed')
