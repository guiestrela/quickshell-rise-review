#!/usr/bin/env python3
"""Render the production storage panel using a fictitious disk inventory."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-storage-', dir='/tmp') as directory:
    base = Path(directory)
    runtime = base / 'runtime'
    runtime.mkdir(mode=0o700)
    panels, modules = base / 'panels', base / 'modules'
    panels.mkdir()
    modules.mkdir()
    source = repo / 'versions/V1/variants/V2'
    text = (source / 'panels/StoragePanel.qml').read_text()
    text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', text, flags=re.M)
    text = text.replace('PanelWindow {', 'Rectangle {\n    width: 800; height: 700\n    property var screen', 1)
    text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n', '', text, flags=re.M)
    text = text.replace('id: card\n', 'id: card; objectName: "card"\n')
    text = text.replace('id: driveRow\n', 'id: driveRow; objectName: "drive-" + drive.model\n')
    (panels / 'StoragePanel.qml').write_text(text)
    for name in ['UiText', 'PillShadow', 'SidePanelPositioner']:
        (modules / f'{name}.qml').write_bytes((source / 'modules' / f'{name}.qml').read_bytes())
    (modules / 'ConnectedPanelSurface.qml').write_text('''import QtQuick
Item { property var root; property bool ownerActive; property real targetX; property real reveal }
''')
    theme = []
    colors = {'fillActive', 'ink', 'panelBorder', 'seal', 'sep', 'sumi', 'sumiHi'}
    for field in sorted(set(re.findall(r'storagePanel\.root\.(\w+)', text))):
        if field in colors:
            theme.append(f'property color {field}: "#999999"')
        elif field == 'activePopupScreen':
            theme.append('property var activePopupScreen: ({width:800,height:700})')
        elif field == 'mono':
            theme.append('property string mono: "monospace"')
        elif field == 'barPosition':
            theme.append('property string barPosition: "top"')
        elif field == 'storageDrives':
            theme.append('property var storageDrives: []')
        elif field in {'storageVisible', 'storageInventoryAvailable'}:
            theme.append(f'property bool {field}: false')
        else:
            theme.append(f'property real {field}: 6')
    theme += ['property bool barVertical: false', 'property real verticalBarWidth: 40',
              'property bool styleShadow: false', 'property color pillShadow: "black"',
              'function verticalAnchorY(name) { return 200 }']
    qml = '''import QtQuick
import QtTest
import "panels"
Item {
 width:800; height:700
 QtObject { id: theme; THEME }
 StoragePanel { id: panel; root: theme }
 TestCase {
  name: "StoragePanel"; when: windowShown
  function test_inventory_updates_and_close() {
   compare(panel.formatCapacity(1000000000000), "1.0 TB")
   compare(panel.formatGiB(1073741824), "1.0 GiB")
   theme.storageVisible = true
   tryCompare(panel,"visible",true)
   theme.storageInventoryAvailable = true
   theme.storageDrives = [{model:"Fixture",driveType:"nvme",size:1000000000000,
     media:"SSD",fileSystems:"ext4",state:"/",percent:50,usedBytes:1073741824,
     freeBytes:1073741824,totalBytes:2147483648}]
   wait(30)
   var row = findChild(panel,"drive-Fixture")
   verify(row !== null)
   compare(row.showUsageDetails,true)
   verify(row.height > 34)
   theme.storageDrives = [{model:"Boot",driveType:"ssd",size:2147483648,
     media:"SSD",fileSystems:"vfat",state:"/boot",percent:25,usedBytes:536870912,
     freeBytes:1610612736,totalBytes:2147483648}]
   wait(30)
   row = findChild(panel,"drive-Boot")
   verify(row !== null)
   compare(row.showUsageDetails,false)
   theme.storageDrives = []
   wait(30)
   compare(findChild(panel,"drive-Boot"),null)
   var card = findChild(panel,"card")
   card.forceActiveFocus()
   keyClick(Qt.Key_Escape)
   compare(theme.storageVisible,false)
  }
 }
}
'''.replace('THEME', '\n'.join(theme))
    probe = base / 'tst_storage.qml'
    probe.write_text(qml)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               QT_QPA_PLATFORMTHEME='', XDG_RUNTIME_DIR=str(runtime))
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(probe)],
                            env=env, text=True, capture_output=True, timeout=15)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode:
        raise SystemExit(result.returncode)
    assert not any(error in output for error in ['ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign', ' ERROR'])
