#!/usr/bin/env python3
"""Exercise production quiet/legacy FileViews with temporary state only."""
from pathlib import Path
import os
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
for variant in ('V1', 'V2'):
    with tempfile.TemporaryDirectory(prefix='rise-notification-dnd-', dir='/tmp') as directory:
        folder = Path(directory)
        runtime = folder/'runtime'
        runtime.mkdir(mode=0o700)
        state = folder/'.local/state/omarchy'
        (state/'notifications').mkdir(parents=True)
        (state/'notifications.json').write_text('{"dnd":true}')
        source = (repo/f'variants/{variant}/Theme.qml').read_text()
        start = source.index('    FileView {\n        id: notificationsStateFile')
        end = source.index('\n    Timer {', start)
        views = source[start:end]
        (folder/'ThemeIntegrations.js').write_text((repo/'shared/logic/ThemeIntegrations.js').read_text())
        (folder/'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "ThemeIntegrations.js" as ThemeIntegrations
Item {
 id: theme
 property bool _notifOmarchyShellSystem: true
 property bool _notifQuietStateAvailable: false
 property bool notifSilenced: false
 property string notificationsStatePath: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/quiet.json"
 function parseNotificationsState(text) { return ThemeIntegrations.parseNotificationsState(theme, {}, text) }
 VIEWS
 FileView { id: writer; path: theme.notificationsStatePath; printErrors: false }
 Timer {
  interval: 30; running: true; repeat: true
  property int phase: 0
  property int ticks: 0
  property int malformedTicks: 0
  onTriggered: {
   ticks++
   if (ticks > 200) { console.error("DND timeout phase=" + phase); Qt.exit(1); return }
   if (phase === 0 && theme.notifSilenced) {
    writer.setText('{"dnd":false}'); phase=1
   } else if (phase === 1 && theme._notifQuietStateAvailable && !theme.notifSilenced) {
    writer.setText('{"dnd":true}'); phase=2
   } else if (phase === 2 && theme.notifSilenced) {
    writer.setText('{'); phase=3
   } else if (phase === 3 && ++malformedTicks > 5) {
    if (!theme.notifSilenced) { console.error("Invalid quiet state cleared DND"); Qt.exit(1); return }
    writer.setText('{"dnd":false}'); phase=4
   } else if (phase === 4 && !theme.notifSilenced) {
    console.log("NOTIFICATION_DND_RUNTIME_PASS"); Qt.quit()
   }
  }
 }
}
'''.replace(' VIEWS', views))
        result = subprocess.run(['timeout','10','qs','-n','-p',str(folder/'shell.qml')],
                                capture_output=True,text=True,timeout=15,
                                env={**os.environ,'HOME':str(folder),'XDG_RUNTIME_DIR':str(runtime),
                                     'QT_QPA_PLATFORM':'offscreen','QT_QUICK_BACKEND':'software',
                                     'QT_QPA_PLATFORMTHEME':''})
        output = result.stdout + result.stderr
        assert result.returncode == 0 and 'NOTIFICATION_DND_RUNTIME_PASS' in output, output
        assert not re.search(r'ERROR|ReferenceError|TypeError|Unable to assign|Binding loop', output), output
        print(f'PASS: {variant} legacy fallback, quiet creation, DND on/off and malformed state')
