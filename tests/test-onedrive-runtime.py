#!/usr/bin/env python3
"""Render the real OneDrive panel with inert per-account state and controls."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-onedrive-', dir='/tmp') as directory:
    base = Path(directory)
    runtime = base / 'runtime'
    runtime.mkdir(mode=0o700)
    shutil.copytree(repo / 'shared', base / 'shared')
    host = base / 'shared/panels/OneDrivePanel.qml'
    text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', host.read_text(), flags=re.M)
    text = text.replace('PanelWindow {', 'Rectangle {\n width:800; height:800; property var screen', 1)
    text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n', '', text, flags=re.M)
    host.write_text(text)
    backend = (repo / 'shared/integrations/onedrive/Service.qml').read_text()
    fields = re.findall(r'^  readonly property (bool|string|int|double|var) (\w+):',backend, re.M)
    values = {'installed':'true','serviceAvailable':'true','authenticated':'true','running':'true','active':'true','enabled':'true','quotaKnown':'true',
        'statusText':'"Monitoring"','syncDir':'"/tmp/OneDrive"','syncMode':'"Two-way"','clientVersion':'"2.5.11"','usedBytes':'1073741824','quotaBytes':'5368709120',
        'accountCount':'2','activeState':'"active"','accounts':'[{service:"onedrive.service",displayName:"Personal",instance:"personal",initialized:true,authenticated:true,installed:true,active:true,statusText:"Monitoring"},{service:"onedrive@work.service",displayName:"Work",instance:"work",initialized:true,authenticated:true,installed:true,active:true,statusText:"Monitoring"}]',
        'aggregate':'({kind:"healthy",count:2,anyActive:true,initialized:true})',
        'files':'[{name:"Report.docx",path:"/tmp/OneDrive/Report.docx",modified:1770000000}]',
        'activity':'[]','allAttempted':'true','selectedAccount':'null'}
    props=[]
    for kind,name in fields:
        default = {'bool':'false','string':'""','int':'0','double':'0','var':'[]'}[kind]
        props.append(f'property {kind} {name}: {values.get(name,default)}')
    methods = set(re.findall(r'root\.oneDrive\.(\w+)\(', (repo/'shared/integrations/onedrive/Panel.qml').read_text()))
    props += ['property var settings: ({panelStyle:"Full"})','property string selectedService: "onedrive.service"','property string lastAction: ""']
    for name in sorted(methods):
        body = f'lastAction="{name}"'
        if name=='selectAccount':body += '; selectedService=arg'
        if name=='updateSetting':
            props.append('function updateSetting(name,value) { var next=Object.assign({},settings); next[name]=value;settings=next }')
            continue
        props.append(f'function {name}(arg) {{ {body} }}')
    # A fixture setter is needed for the actual preferences controls.
    if 'updateSetting' not in methods: props.append('function updateSetting(name,value) { var next=Object.assign({},settings); next[name]=value;settings=next }')
    # Production service/IPC, with Quickshell process and preference boundaries mocked.
    stubs=base/'stubs'
    shutil.copytree(repo/'shared/integrations/onedrive/tests/qmlstubs',stubs)
    q=(stubs/'Quickshell/Quickshell.qml').read_text().replace('QtObject {','QtObject {\n  function env(name) { return "/tmp/onedrive-fixture" }',1)
    (stubs/'Quickshell/Quickshell.qml').write_text(q)
    io=stubs/'Quickshell/Io'
    (io/'IpcHandler.qml').write_text('import QtQuick\nQtObject { property string target }\n')
    (io/'FileView.qml').write_text('import QtQuick\nQtObject { property string path; property bool blockWrites; property bool atomicWrites; property bool printErrors; signal loaded(); function text() {return "{}"} function setText(value) {} }\n')
    with (io/'qmldir').open('a') as f:f.write('\nIpcHandler 1.0 IpcHandler.qml\nFileView 1.0 FileView.qml\n')
    wrapper=base/'shared/services/OneDriveService.qml'
    wrapper.write_text(wrapper.read_text().replace('    IpcHandler {','    IpcHandler {\n        objectName: "fixture-ipc"',1))
    content=(base/'shared/integrations/onedrive/Panel.qml').read_text().replace('id: root\n','id: root\n  objectName: "onedrive-content"\n',1)
    (base/'shared/integrations/onedrive/Panel.qml').write_text(content)
    qml='''import QtQuick
import QtTest
import "shared/panels"
import "shared/services"
import "shared/integrations/onedrive/ui" as OneDriveUi
import Quickshell
Item {
 width:800; height:800
 QtObject { id: service; PROPERTIES }
 QtObject {
  id: theme
  property var oneDriveService: service
  property bool oneDriveVisible: false
  property string oneDriveOpenTarget: ""
  property real oneDriveBarX:400
  property var activePopupScreen:null
  property string barPosition:"top"
  property color ink:"#dedede"
  property color seal:"#89b4fa"
  property color sealRaw:"#e06c75"
  property color bg:"#202020"
  property color sumi:"#999999"
  property color fillIdle:"#252525"
  property color fillHover:"#334455"
  property color fillActive:"#445566"
  property color sep:"#555555"
  property real panelButtonRadius:9
  property real panelRadius:12
  property real panelOuterBorderW:1
  property color panelOuterBorderColor:"#667788"
  property string mono:"JetBrainsMono Nerd Font"
  function activateFocusedPopupScreen() {}
 }
 OneDriveService { id: backend; owner:theme; pollingEnabled:false }
 OneDrivePanel { id: panel;root:theme;barBottom:35;gap:8;frameRadius:12;frameColor:"#202020";frameBorderColor:"#555555";frameBorderWidth:1;buttonRadius:6 }
 TestCase {
  name:"OneDrivePanel"; when:windowShown
  function test_backend_ipc() {
   wait(10)
   var ipc=findChild(backend,"fixture-ipc")
   verify(ipc!==null)
   compare(ipc.target,"io.github.salemsayed.omaonedrive")
   compare(Quickshell.spawnCount,0)
   compare(JSON.parse(ipc.accounts()).length,1)
   compare(ipc.selectAccount("unknown"),"unknown account: unknown")
   backend.updateSetting("panelStyle","Compact")
   compare(backend.settings.panelStyle,"Compact")
   ipc.open()
   compare(theme.oneDriveVisible,true)
   backend.externalActionRequested()
   compare(theme.oneDriveVisible,false)
   ipc.openAccount("onedrive.service")
   compare(theme.oneDriveOpenTarget,"")
   compare(theme.oneDriveVisible,true)
   ipc.close()
   compare(theme.oneDriveVisible,false)
  }
  function test_panel() {
   theme.oneDriveVisible=true
   wait(40)
   var body=findChild(panel,"onedrive-content")
   verify(body!==null)
   compare(body.panelStyle,"full")
   var title=findChild(panel,"onedrive-title")
   verify(title!==null)
   compare(title.renderType,Text.NativeRendering)
   compare(title.font.family,theme.mono)
   compare(title.font.pixelSize,13)
   compare(OneDriveUi.Style.font.title,13)
   compare(OneDriveUi.Style.font.family,theme.mono)
   compare(OneDriveUi.Style.usageBarRadius,3)
   compare(OneDriveUi.Style.cornerRadius,9)
   compare(OneDriveUi.Color.foreground,theme.ink)
   compare(OneDriveUi.Color.tooltip.border,theme.panelOuterBorderColor)
   theme.panelButtonRadius=15
   compare(OneDriveUi.Style.cornerRadius,15)
   theme.panelOuterBorderW=0
   compare(OneDriveUi.Style.tooltipBorderWidth,0)
   theme.seal="#aabbcc"
   compare(OneDriveUi.Color.accent,theme.seal)
   theme.panelOuterBorderW=1
   verify(body.navigationItems().length > 3)
   body.selectAccount("onedrive@work.service")
   compare(service.selectedService,"onedrive@work.service")
   body.moveCursor(0,1)
   verify(body.cursorItem!==null)
   body.activateCursor()
   service.settings={panelStyle:"Compact"}
   tryCompare(body,"panelStyle","compact")
   verify(panel.surfaceHost.height < 664)
   body.preferencesVisible=true
   wait(20)
   var refresh=findChild(panel,"onedrive-refresh-setting")
   verify(refresh!==null)
   refresh.adjust(1)
   compare(service.settings.refreshIntervalSec,40)
   refresh.adjust(-1)
   compare(service.settings.refreshIntervalSec,30)
   service.updateSetting("refreshIntervalSec",10)
   refresh.adjust(-1)
   compare(service.settings.refreshIntervalSec,10)
   var files=findChild(panel,"onedrive-files-setting")
   service.updateSetting("recentFileLimit",50)
   files.adjust(1)
   compare(service.settings.recentFileLimit,50)
   files.adjust(-1)
   compare(service.settings.recentFileLimit,45)
   var notifications=findChild(panel,"onedrive-notifications-setting")
   notifications.keyboardActivate()
   compare(service.settings.notifications,false)
   notifications.keyboardActivate()
   compare(service.settings.notifications,true)
   findChild(panel,"onedrive-layout-full").keyboardActivate()
   compare(body.panelStyle,"full")
   findChild(panel,"onedrive-layout-compact").keyboardActivate()
   compare(body.panelStyle,"compact")
   body.preferencesVisible=false
   service.reauthRequired=true
   service.running=false
   service.active=false
   wait(30)
   verify(body.navigationItems().length > 0)
   service.authenticated=false
   wait(20)
   verify(panel.surfaceHost.height > 0)
   service.authenticated=true
   service.settings={panelStyle:"Full"}
   service.reauthRequired=false
   service.running=true
   service.active=true
   wait(40)
   body.preferencesVisible=true
   wait(50)
   compare(panel.surfaceHost.height, Math.min(body.contentHeight + 24, 800 - 35 - 8 - 16))
   PREVIEW
   body.close()
   compare(theme.oneDriveVisible,false)
  }
 }
}
'''.replace('PROPERTIES','\n'.join(props))
    preview=os.environ.get('RISE_ONEDRIVE_PREVIEW')
    qml=qml.replace('PREVIEW',f'grabImage(panel).save({__import__("json").dumps(preview)})' if preview else '')
    probe=base/'tst_onedrive.qml';probe.write_text(qml)
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-import',str(stubs),'-input',str(probe)],
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime)),
        text=True,capture_output=True,timeout=25)
    output=result.stdout+result.stderr;print(output,end='')
    assert result.returncode==0,result.returncode
    assert not any(x in output for x in ['ReferenceError','TypeError','Binding loop','Unable to assign',' ERROR'])
