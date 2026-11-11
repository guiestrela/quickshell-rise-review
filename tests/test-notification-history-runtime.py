#!/usr/bin/env python3
"""Render notification history with inert cache and notification commands."""
from qml_fixture_source import qml_fixture_bytes, qml_fixture_source, qml_fixture_text
import os
from pathlib import Path
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-notifications-', dir='/tmp') as directory:
    base = Path(directory)
    runtime = base / 'runtime'
    runtime.mkdir(mode=0o700)
    panels, modules = base / 'panels', base / 'modules'
    panels.mkdir()
    common = base / "common"
    common.mkdir()
    modules.mkdir()
    source = repo / os.environ.get('RISE_NOTIFICATION_SOURCE', 'variants/V1')
    adapter = qml_fixture_text(source / 'panels/NotificationPanel.qml').replace('../../../shared/panels','../common')
    text = qml_fixture_text(repo / 'shared/panels/NotificationPanel.qml')
    text = text.replace('import QtQuick\n','import QtQuick\nimport "../modules"\n',1)
    text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', text, flags=re.M)
    text = text.replace('PanelWindow {', 'Rectangle {\n    width: 800; height: 700\n    property var screen', 1)
    text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n', '', text, flags=re.M)
    text = text.replace('id: card\n', 'id: card; objectName: "card"\n')
    text = text.replace('id: notificationRow\n', 'id: notificationRow; objectName: "notification-" + modelData.key\n')
    text = text.replace('Process {','InertProcess {').replace('FileView {','InertFileView {').replace('StdioCollector {','InertCollector {')
    text = text.replace('Quickshell.env("HOME")','"/fixture"')
    text = re.sub(r'^import ".*NotificationActions.js" as NotificationActions$', 'import "NotificationActions.js" as NotificationActions',text,flags=re.M)
    (panels/'NotificationActions.js').write_bytes(qml_fixture_bytes(qml_fixture_source(repo/'shared/integrations/NotificationActions.js')))
    (panels/'InertProcess.qml').write_text('import QtQuick\nQtObject { property var command: []; property bool running: false; property var stdout; signal exited(int exitCode) }')
    (panels/'InertCollector.qml').write_text('import QtQuick\nQtObject { property string text: ""; signal streamFinished() }')
    (panels/'InertFileView.qml').write_text('import QtQuick\nQtObject { property string path; property string contents: ""; signal loaded(); signal loadFailed(); function reload() { loadFailed() } function text() { return contents } function setText(value) { contents=value } }')
    (common / 'NotificationPanel.qml').write_text(text)
    (panels / 'NotificationPanel.qml').write_text(adapter)
    for name in ['NotificationActions.js','InertProcess.qml','InertCollector.qml','InertFileView.qml']:
        (common / name).write_bytes((panels / name).read_bytes())
    for name in ['UiText', 'PillShadow', 'SidePanelPositioner']:
        (modules / f'{name}.qml').write_bytes(qml_fixture_bytes(qml_fixture_source(source / 'modules' / f'{name}.qml')))
    (modules / 'ConnectedPanelSurface.qml').write_text('''import QtQuick
Item { property var root; property bool ownerActive; property real targetX; property real reveal }
''')
    theme = []
    colors = {'bg','pillBorder','fillHover','fillIdle','ink','panelBorder','seal','sep','sumi','sumiHi'}
    for field in sorted(set(re.findall(r'(?:notifPanel|panel)\.root\.(\w+)', text+'\n'+adapter))):
        if field in colors:
            theme.append(f'property color {field}: "#999999"')
        elif field == 'activePopupScreen':
            theme.append('property var activePopupScreen: ({width:800,height:700})')
        elif field == 'mono':
            theme.append('property string mono: "monospace"')
        elif field == 'barPosition':
            theme.append('property string barPosition: "top"')
        elif field in {'notifVisible','_notifOmarchyShellBackend'}:
            theme.append(f'property bool {field}: false')
        else:
            theme.append(f'property real {field}: 6')
    theme += ['property int notifCount: 0','property bool barVertical: false', 'property real verticalBarWidth: 40',
              'property bool styleShadow: false', 'property color pillShadow: "black"',
              'function verticalAnchorY(name) { return 200 }']
    qml = '''import QtQuick
import QtTest
import "panels"
Item {
 width:800; height:700
 QtObject { id: theme; THEME }
 NotificationPanel { id: panel; root: theme }
 TestCase {
  name: "NotificationPanel"; when: windowShown
  function test_history_count_and_dismiss() {
   verify(panel.cacheLoaded)
   panel.merge("fixture-session",[{id:1,summary:"Fixture one",body:"Body",appName:"Fixture"},
     {id:2,summary:"Fixture two",body:"Body",appName:"Fixture"}],[])
   compare(panel.pending.length,2)
   compare(theme.notifCount,2)
   theme.notifVisible=true
   tryCompare(panel,"visible",true)
   var entry=panel.pending[0]
   verify(findChild(panel,"notification-"+entry.key) !== null)
   panel.dismissOne(entry)
   compare(theme.notifCount,1)
   compare(panel.pending.length,1)
   panel.merge("fixture-session",[{id:1,summary:"Fixture one"},{id:2,summary:"Fixture two"}],[])
   compare(panel.pending.length,1)
   panel.dismissAll()
   compare(theme.notifCount,0)
   compare(panel.pending.length,0)
   panel.merge("next-session",[{id:1,summary:"New session"}],[])
   compare(panel.pending.length,1)
   compare(panel.generation,1)
   var card=panel.surfaceHost
   compare(card.width,320)
   compare(card.radius,MODERN ? theme.panelRadius : theme.pillRadius)
   compare(card.color.a,MODERN ? 0 : 1)
   compare(card.border.width,MODERN ? 0 : theme.pillBorderW)
   compare(panel.gap,MODERN ? 6 : 8)
   theme.barPosition="bottom"
   tryVerify(function(){ return Math.abs(card.y-(panel.height-panel.barBottom-panel.gap-card.height))<0.01 })
   theme.barVertical=true;theme.barPosition="left"
   tryCompare(card,"x",theme.verticalBarWidth+panel.gap)
   theme.barVertical=false;theme.barPosition="top"
   card.forceActiveFocus()
   keyClick(Qt.Key_Escape)
   compare(theme.notifVisible,false)
  }
 }
}
'''.replace('THEME', '\n'.join(theme)).replace('MODERN','true' if source.name=='V2' else 'false')
    probe = base / 'tst_notifications.qml'
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
