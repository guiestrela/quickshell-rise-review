#!/usr/bin/env python3
"""Shared connectivity content + real variant adapters; every backend is inert."""
from pathlib import Path
import os
import re
import subprocess
import tempfile
from qml_fixture_source import qml_fixture_text, qml_fixture_bytes

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-connectivity-', dir='/tmp') as directory:
    temp = Path(directory)
    runtime = temp / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant in ['V1', 'V2']:
        folder = temp / variant
        for sub in ['panels', 'common', 'modules', 'logic']:
            (folder / sub).mkdir(parents=True)
        for name, identity in [('NetworkPanel', 'netPanel'), ('BluetoothPanel', 'btPanel')]:
            text = qml_fixture_text(repo / 'shared/panels' / (name + '.qml'))
            text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', text, flags=re.M)
            text = text.replace('import QtQuick\n', 'import QtQuick\nimport "../modules"\nimport "." as Fixture\n', 1)
            text = text.replace('PanelWindow {', 'Rectangle {\n width:800; height:900; property var screen', 1)
            text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n', '', text, flags=re.M)
            text = text.replace('Bluetooth.', 'Fixture.Bluetooth.')
            text = text.replace('../services/NetworkManagerAdapter.qml', 'NetworkManagerAdapter.qml')
            for identity in ['netData', 'btData']:
                text = text.replace('id: ' + identity + '\n', 'id: ' + identity + '; objectName: "' + identity + '"\n')
            (folder / 'common' / (name + '.qml')).write_text(text)
            adapter = qml_fixture_text(repo / 'variants' / variant / 'panels' / (name + '.qml'))
            (folder / 'panels' / (name + '.qml')).write_text(adapter.replace('../../../shared/panels', '../common'))
        for name in ['UiText', 'IconText', 'PillShadow', 'SidePanelPositioner']:
            source = repo / 'shared/components' / (name + '.qml') if name in ['UiText', 'IconText'] else repo / 'variants' / variant / 'modules' / (name + '.qml')
            (folder / 'modules' / (name + '.qml')).write_bytes(qml_fixture_bytes(source))
        (folder / 'logic/IconMap.js').write_bytes((repo / 'shared/logic/IconMap.js').read_bytes())
        mocks = {
            'ConnectedPanelSurface.qml': 'Item { objectName:"connected-surface"; property var root; property bool ownerActive; property real targetX; property real reveal }',
            'NetworkDnsSection.qml': 'Item { property var theme; property bool panelOpen; implicitHeight:20 }',
            'CloudflareSpeedTest.qml': 'QtObject { property bool online:false; property string phase:"idle"; property bool running:false; property string edgeCode:""; property string countryCode:""; property real pingMs:0; property real downloadMbps:0; property real uploadMbps:0; function start(){} function cancel(){} }',
        }
        for name, text in mocks.items():
            (folder / 'modules' / name).write_text('import QtQuick\n' + text)
        (folder / 'common/qmldir').write_text('singleton Bluetooth 1.0 Bluetooth.qml\n')
        (folder / 'common/Bluetooth.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var devices: ({values:[]}); property var adapters: ({values:[]}); property var defaultAdapter:null }')
        (folder / 'common/Process.qml').write_text('''import QtQuick
QtObject { property var command:[]; property bool running:false; property var stdout; property var stderr; signal exited(int code); signal started() }
''')
        (folder / 'common/StdioCollector.qml').write_text('import QtQuick\nQtObject { property string text:""; property bool waitForEnd:false; signal streamFinished() }')
        (folder / 'common/NetworkManagerAdapter.qml').write_text('''import QtQuick
Item { objectName:"nm-adapter"; property var panel; property bool panelOpen:false; property bool available:true; property int refreshCalls:0; function refresh(){refreshCalls++} function syncNetworks(){} }
''')
        qml = '''import QtQuick
import QtTest
import "VARIANT/panels"
Item {
 width:800; height:900
 QtObject {
  id:theme
  property var activePopupScreen: ({width:800,height:900})
  property bool networkVisible:false
  property bool bluetoothVisible:false
  property bool useNM:false
  property bool barVertical:false
  property string networkMode:"none"
  property string launchWifiCmd:"fixture-only"
  property string launchBtCmd:"fixture-only"
  property string barPosition:"top"
  property string mono:"monospace"
  property real networkBarX:400
  property real bluetoothBarX:400
  property real verticalBarWidth:40
  property int v2BarHeight:33
  property int pillRadius:6
  property int panelRadius:12
  property int tileRadius:4
  property int panelButtonRadius:8
  property int pillBorderW:1
  property bool styleShadow:false
  property color pillShadow:"black"
  property color bg:"#202020"
  property color pillBorder:"#404040"
  property color panelBorder:"#505050"
  property color ink:"white"
  property color paper:"#181818"
  property color seal:"orange"
  property color sealRaw:"red"
  property color sep:"gray"
  property color sumi:"gray"
  property color sumiHi:"silver"
  property color fillActive:"#303030"
  property color fillIdle:"#282828"
  property color fillHover:"#404040"
  property color fillPrimaryHover:"#505050"
  property color green:"green"
  property color indigo:"blue"
  function verticalAnchorY(name){return 300}
 }
 NetworkPanel { id:network; root:theme }
 BluetoothPanel { id:bluetooth; root:theme }
 TestCase {
  name:"ConnectivityVARIANT"; when:windowShown
  function test_content_style_and_lazy_backend() {
   var reader=findChild(network,"netData")
   reader.stdout.text="WIFI\\tFixture WiFi\\t75\\twlan-fixture\\t192.0.2.1\\t5000 MHz"
   reader.stdout.streamFinished()
   compare(network.ssid,"Fixture WiFi");compare(network.signal,75)
   var btReader=findChild(bluetooth,"btData")
   btReader.stdout.text="ON\\n1|1|AA:BB:CC:DD:EE:FF|Fixture Headset"
   btReader.stdout.streamFinished()
   compare(bluetooth.btOn,true);compare(bluetooth.connectedDevices.length,1)
   compare(network.nmAdapterReady,false)
   theme.useNM=true
   tryCompare(network,"nmAdapterReady",true)
   var adapter=findChild(network,"nm-adapter")
   verify(adapter!==null);compare(adapter.panel,network);compare(adapter.refreshCalls,1)
   theme.useNM=false
   tryCompare(network,"nmAdapterReady",false)
   var modern="VARIANT"==="V2"
   for(var entry of [[network,"networkVisible"],[bluetooth,"bluetoothVisible"]]) {
    var panel=entry[0];theme[entry[1]]=true;tryCompare(panel,"reveal",1)
    var card=panel.surfaceHost
    compare(card.width,300);compare(card.radius,modern?12:6)
    compare(card.border.width,modern?0:1);compare(card.color.a,modern?0:1)
    compare(panel.buttonRadius,modern?8:4)
    var shadow=null
    for(var child of card.children) if("theme" in child && child.theme===theme)shadow=child
    verify(shadow!==null);compare(shadow.parent,card)
    if(!modern)compare(shadow.pillSurface,card)
    compare(findChild(card,"connected-surface")!==null,modern)
    theme.barPosition="bottom"
    tryCompare(card,"y",panel.height-panel.barBottom-panel.gap-card.height)
    theme.barVertical=true;theme.barPosition="left"
    tryCompare(card,"x",theme.verticalBarWidth+panel.gap)
    theme.barVertical=false;theme.barPosition="top"
    tryCompare(card,"y",panel.barBottom+panel.gap)
    card.forceActiveFocus();keyClick(Qt.Key_Escape);compare(theme[entry[1]],false)
   }
  }
 }
}
'''.replace('VARIANT', variant)
        probe = temp / ('tst_' + variant + '.qml')
        probe.write_text(qml)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='', QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=str(runtime))
        result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(probe)], env=env, text=True, capture_output=True, timeout=15)
        output = result.stdout + result.stderr
        print(output, end='')
        assert result.returncode == 0, output
        assert not re.search(r'ReferenceError|TypeError|Binding loop|Unable to assign', output), output
