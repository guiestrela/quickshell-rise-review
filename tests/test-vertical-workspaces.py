#!/usr/bin/env python3
"""Load the production workspace widget with inert actions and no compositor connection."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-workspaces-', dir='/tmp') as directory:
    base = Path(directory)
    (base / 'runtime').mkdir(mode=0o700)
    shutil.copy2(repo / 'versions/V1/variants/V2/modules/WorkspaceWidget.qml', base)
    (base / 'shell.qml').write_text('''import QtQuick
import QtQuick.Window
import Quickshell
ShellRoot {
 id: harness
 property QtObject state: QtObject {
  property bool barVertical: true
  property string workspaceMode: "10"
  property string workspaceStyle: "default"
  property bool workspaceVisible: false
  property string mono: "monospace"
  property color seal: "#ff8800"
  property int panelButtonRadius: 6
  function widgetHasBorder(gid) { return false }
  function widgetContentColor(gid, fallback) { return fallback }
  function gotoWorkspace(id) {}
 }
 Window {
  visible: true; width:600; height:400
  WorkspaceWidget { id: widget; root:harness.state }
 }
 property int step:0
 property var styles: ["default","numbers","magic","kanji","rings","aurora"]
 Timer { interval:80; repeat:true; running:true; onTriggered: {
  function check(ok, message) { if (!ok) { console.error(message); Qt.exit(1) } }
  if (harness.step < harness.styles.length) {
   check(widget.implicitWidth <= 36 && widget.implicitHeight === 258, "VERTICAL_GEOMETRY_" + harness.state.workspaceStyle)
   harness.state.workspaceStyle = harness.styles[harness.step]
  } else if (harness.step === 6) {
   harness.state.workspaceMode = "5"
  } else if (harness.step === 7) {
   check(widget.implicitHeight === 128, "FIVE_WORKSPACES_HEIGHT")
   harness.state.barVertical = false
  } else if (harness.step === 8) {
   check(widget.implicitHeight === 28 && widget.implicitWidth > 36, "HORIZONTAL_RESTORE")
   console.log("VERTICAL_WORKSPACES_PASS")
   Qt.quit()
  }
  harness.step++
 }}
}
''')
    env = dict(os.environ, XDG_RUNTIME_DIR=str(base / 'runtime'), QT_QPA_PLATFORM='offscreen',
               QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='')
    env.pop('WAYLAND_DISPLAY', None)
    env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
    result = subprocess.run(['qs', '-n', '-p', str(base / 'shell.qml')], env=env,
                            capture_output=True, text=True, timeout=10)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode or 'VERTICAL_WORKSPACES_PASS' not in output or 'WARN scene:' in output or 'ERROR qml:' in output:
        raise SystemExit(result.returncode or 1)
