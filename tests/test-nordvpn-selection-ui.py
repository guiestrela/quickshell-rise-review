#!/usr/bin/env python3
"""Render the real selection delegates with QtTest; never run a VPN command."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def rectangle(source, marker):
    pos = source.index(marker)
    start = source.rfind('Rectangle {', 0, pos)
    opening = source.index('{', start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == '{': depth += 1
        elif source[index] == '}':
            depth -= 1
            if depth == 0: return source[start:index + 1]
    raise AssertionError('Unterminated production button')

with tempfile.TemporaryDirectory(prefix='vpn-selection-ui-', dir=os.environ['TMPDIR']) as directory:
    temp = Path(directory)
    for variant, relative in [('V1', 'versions/V1/panels/NordVPNPanel.qml'), ('V2', 'versions/V1/variants/V2/panels/NordVPNPanel.qml')]:
        source = (ROOT / relative).read_text()
        tech = rectangle(source, 'id: technologyMouse;')
        udp = rectangle(source, 'id: protocolMouse;')
        tcp = rectangle(source, 'id: tcpProtocolMouse;')
        peer = rectangle(source, 'id: autoConnectMouse;')
        test = '''import QtQuick
import QtTest
Item {
 id: vpnPanel; width: 300; height: 100
 property var testTargets: ({})
 property bool autoConnectEnabled: true
 property var root: QtObject {
  property int tileRadius: 4; property int panelButtonRadius: 4
  property color seal: "#ff5b35"; property color paper: "#141414"; property color ink: "#eeeeee"
  property color fillActive: "#40251e"; property color fillIdle: "#242424"; property color fillHover: "#383838"; property color sep: "#454545"
  property string mono: "monospace"
 }
 property var controller: QtObject { property bool canMutate: true; property var vpnSettings: ({}) }
 function changeTechnology(value) {} function changeProtocol(value) {}
 component UiText: Text {}
 component Tech: TECH
 component Udp: UDP_BUTTON
 component Tcp: TCP_BUTTON
 component Peer: PEER_BUTTON
 Row {width:300; Tech {modelData:"OPENVPN"} Tech {modelData:"NORDLYNX"} Tech {modelData:"NORDWHISPER"} }
 Row {y:35;width:300; Udp {} Tcp {} }
 Row {y:70;width:300; Peer {id:peer} }
 TestCase {name:"NordVpnSelectionVARIANT";when:windowShown
  function label(button){
   for(var child of button.children)if(typeof child.text==="string")return child
   fail("Button label not found")
  }
  function test_highlight_and_readback(){
   for (var technology of ["OPENVPN","NORDLYNX","NORDWHISPER"]){
    controller.vpnSettings={technology:technology,protocol:"UDP"};wait(1)
    for (var name of ["OPENVPN","NORDLYNX","NORDWHISPER"]){
     var button=vpnPanel.testTargets["vpn-technology-"+name.toLowerCase()].parent
     compare(button.selected,name===technology)
     compare(button.color,name===technology?peer.color:root.fillIdle)
     compare(label(button).color,name===technology?label(peer).color:root.ink)
     compare(button.border.width,peer.border.width)
     compare(button.border.color,name===technology?peer.border.color:root.sep)
     compare(button.radius,peer.radius)
    }
   }
   controller.vpnSettings={technology:"",protocol:""};wait(1)
   for(var name of ["OPENVPN","NORDLYNX","NORDWHISPER"]){
    var button=vpnPanel.testTargets["vpn-technology-"+name.toLowerCase()].parent
    compare(button.selected,false);compare(button.color,root.fillIdle);compare(label(button).color,root.ink)
   }
   for(var protocol of ["UDP","TCP",""]){
    controller.vpnSettings={technology:"OPENVPN",protocol:protocol};wait(1)
    var udp=vpnPanel.testTargets["vpn-protocol"]||findChild(vpnPanel,"vpn-protocol")
    var tcp=vpnPanel.testTargets["vpn-protocol-tcp"]||findChild(vpnPanel,"vpn-protocol-tcp")
    compare(udp.parent.selected,protocol==="UDP");compare(tcp.parent.selected,protocol==="TCP")
    compare(udp.parent.color,protocol==="UDP"?peer.color:root.fillIdle)
    compare(tcp.parent.color,protocol==="TCP"?peer.color:root.fillIdle)
    compare(label(udp.parent).color,protocol==="UDP"?label(peer).color:root.ink)
    compare(label(tcp.parent).color,protocol==="TCP"?label(peer).color:root.ink)
    compare(udp.parent.border.width,peer.border.width);compare(tcp.parent.border.width,peer.border.width)
    compare(udp.parent.border.color,protocol==="UDP"?peer.border.color:root.sep)
    compare(tcp.parent.border.color,protocol==="TCP"?peer.border.color:root.sep)
    compare(udp.parent.radius,peer.radius);compare(tcp.parent.radius,peer.radius)
   }
  }
 }
}
'''.replace('TECH', tech).replace('UDP_BUTTON', udp).replace('TCP_BUTTON', tcp).replace('PEER_BUTTON', peer).replace('VARIANT', variant)
        qml = temp / f'tst_{variant}.qml'
        qml.write_text(test)
    env = os.environ.copy()
    env.pop('DISPLAY', None)
    env['QT_QPA_PLATFORM'] = 'offscreen'
    env['QT_QUICK_BACKEND'] = 'software'
    env['QT_QPA_PLATFORMTHEME'] = ''
    run = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(temp)], env=env, capture_output=True, text=True, timeout=15)
    output = run.stdout + run.stderr
    assert run.returncode == 0, output
    assert not any(error in output for error in ['ReferenceError', 'TypeError', 'Cannot assign']), output
    print('PASS V1/V2: technology/transport selection matches the actual Auto-connect ON button fill, text, border and radius; exclusive readback preserved; isolated QtTest, zero VPN actions')
