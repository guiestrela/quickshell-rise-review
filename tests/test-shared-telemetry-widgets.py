#!/usr/bin/env python3
"""Real telemetry/widget implementations with inert processes and files."""
import os
import json
from pathlib import Path
import re
import subprocess
import tempfile
from qml_fixture_source import qml_fixture_text
repo=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-telemetry-',dir='/tmp') as directory:
 base=Path(directory); runtime=base/'runtime';runtime.mkdir(mode=0o700)
 common=base/'common'; common.mkdir()
 text=(repo/'shared/services/SystemTelemetry.qml').read_text()
 text=re.sub(r'^import Quickshell(?:\.\w+)?\n','',text,flags=re.M)
 (common/'SystemTelemetry.qml').write_text(text)
 (common/'Process.qml').write_text('import QtQuick\nQtObject { property var command; property bool running: false; property QtObject stdout }\n')
 (common/'StdioCollector.qml').write_text('import QtQuick\nQtObject { property string text; signal streamFinished() }\n')
 (common/'FileView.qml').write_text('import QtQuick\nQtObject { property string path; signal loaded(); function reload() {} function text() { return "" } }\n')
 for name in ['CpuTemperatureWidget','StorageWidget','UiText','TooltipMixin']:
  (common/(name+'.qml')).write_text(qml_fixture_text(repo/'shared/components'/(name+'.qml')))
 for v in ['V1','V2']:
  folder=base/v;folder.mkdir()
  for name in ['CpuTemperatureWidget','StorageWidget']:
   t=(repo/f'variants/{v}/modules/{name}.qml').read_text().replace('../../../shared/components','../common')
   (folder/(name+'.qml')).write_text(t)
  (folder/'PillShadow.qml').write_text((repo/f'variants/{v}/modules/PillShadow.qml').read_text())
 probe=base/'tst_telemetry.qml'
 probe.write_text('''import QtQuick
import QtTest
import "common" as Shared
import "V1" as V1
import "V2" as V2
Item {
 width:520; height:110
 property string captureDirectory: CAPTURE_DIRECTORY
 Rectangle { anchors.fill:parent; color:"#151515"; z:-1 }
 Text { text:"V1"; color:"white"; x:8; y:0 }
 Text { text:"V2"; color:"white"; x:258; y:0 }
 QtObject { id: theme
  property bool cpuVisible:false; property bool gpuVisible:false; property bool memVisible:false
  property bool modCpu:false; property bool modMemory:false; property bool modGpu:false
  property bool modCpuTemperature:true; property bool modStorage:true
  property bool thermalVisible:false; property bool storageVisible:false
  property alias barTemperatureC:data.barTemperatureC
  property alias barTemperatureAvailable:data.barTemperatureAvailable
  property alias barTemperatureSource:data.barTemperatureSource
  property alias storagePercent:data.storagePercent
  property alias storageAvailable:data.storageAvailable
  property alias storageUsedGiB:data.storageUsedGiB
  property alias storageTotalGiB:data.storageTotalGiB
  property bool barVertical:false; property bool compactTemperature:false; property bool compactStorage:false
  property string mono:"monospace"; property color seal:"#ff5500"; property color widgetIconColor:"#eeeeee"
  property color pill:"#222222"; property color pillBorder:"#555555"; property real pillBorderW:1
  property real pillH:28; property real pillRadius:8; property bool styleShadow:false
  property color pillShadow:"black"; property string barPosition:"top"
  property var tooltipOwner:null; property string tooltipText:""
  function barTemperatureSourceLabel(s) { return data.barTemperatureSourceLabel(s) }
  function iconOnly(gid) { return false }
  function widgetContentColor(gid, color) { return color }
  function hideTooltip(owner) {}
  function showTooltip(text,x,y,bottom,owner) {}
 }
 Shared.SystemTelemetry { id:data; owner:theme }
 V1.CpuTemperatureWidget { id:t1; root:theme; width:implicitWidth; height:28; y:20 }
 V1.StorageWidget { id:s1; root:theme; width:implicitWidth; height:28; y:60 }
 V2.CpuTemperatureWidget { id:t2; root:theme; width:implicitWidth; height:28; x:250; y:20 }
 V2.StorageWidget { id:s2; root:theme; width:implicitWidth; height:28; x:250; y:60 }
 TestCase { name:"SharedTelemetryWidgets"; when:windowShown
  function test_data_style_visibility_and_actions() {
   compare(t1.implicitWidth,0); compare(t2.implicitWidth,0)
   data.parseThermalTelemetry("52|57|90|100|41|75|90|38")
   verify(t1.implicitWidth>0); compare(t1.temperature,52); compare(t2.temperature,52)
   compare(t1.contentColor,theme.seal); compare(t2.contentColor,theme.widgetIconColor)
   data.parseStorageTelemetry("25|1073741824|4294967296")
   verify(s1.implicitWidth>0); compare(s1.percent,25); compare(s2.percent,25)
   wait(180)
   if(captureDirectory) grabImage(parent).save(captureDirectory+"/telemetry-widgets.png")
   var full=t1.implicitWidth; theme.compactTemperature=true; wait(20); verify(t1.implicitWidth<full)
   theme.barVertical=true; verify(t1.compact); verify(s1.compact)
   mouseClick(t1,t1.width/2,14); compare(theme.thermalVisible,true)
   mouseClick(s1,s1.width/2,14); compare(theme.storageVisible,true)
   theme.modCpuTemperature=false; compare(t1.implicitWidth,0); compare(t2.implicitWidth,0)
   theme.modStorage=false; compare(s1.implicitWidth,0); compare(s2.implicitWidth,0)
   data.parseThermalTelemetry(""); compare(data.barTemperatureAvailable,false)
   data.parseStorageTelemetry(""); compare(data.storageAvailable,false)
   data.parseGpuTelemetry("sysfs|Fixture||23|41|0|0|0|0|0||0|0")
   compare(data.gpuHistory.length,1); compare(data.gpuHistory[0],0.23)
   data.parseGpuTelemetry("none|||||||||||"); compare(data.gpuHistory.length,0)
  }
 }
}'''.replace('CAPTURE_DIRECTORY',json.dumps(os.environ.get('RISE_CAPTURE_DIR',''))))
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',QT_QPA_PLATFORMTHEME='',XDG_RUNTIME_DIR=str(runtime))
 result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(probe)],env=env,text=True,capture_output=True,timeout=20)
 output=result.stdout+result.stderr;print(output,end='')
 assert result.returncode==0,output
 assert not any(e in output for e in ['ReferenceError','TypeError','Unable to assign','Binding loop'])
