#!/usr/bin/env python3
"""Exercise production bindings with inert roots and a bundled quote fixture."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
panel = (ROOT / 'shared/panels/AiUsagePanel.qml').read_text()
reveal = panel[panel.index('    readonly property real reveal:'):panel.index('\n    visible: reveal')]
particle = (ROOT / 'variants/V1/modules/ParticleStream.qml').read_text()
quotes = re.search(r'^    readonly property (?:string|url) quotesPath8:.*$', particle, re.M)[0]

with tempfile.TemporaryDirectory(prefix='rise-variant-contracts-') as directory:
    folder = Path(directory)
    (folder / 'modules').mkdir()
    (folder / 'runtime').mkdir(mode=0o700)
    (folder / 'quotes.txt').write_bytes((ROOT / 'variants/V1/quotes.txt').read_bytes())
    (folder / 'shell.qml').write_text('import Quickshell\nimport "modules"\nShellRoot { Contract {} }\n')
    (folder / 'modules/Contract.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
Item {
    id: fixture
    QUOTES
    FileView { id: quotesFile; path: fixture.quotesPath8; blockLoading: true; blockAllReads: true }
    QtObject { id: v1; property bool aiUsageVisible: false }
    QtObject { id: v2; property bool aiUsageVisible: false; property real aiUsageReveal: 0 }
    Component {
        id: panelBinding
        Item {
            id: aiPanel
            property var root
            REVEAL
        }
    }
    function compare(actual, expected) { if (actual !== expected) throw new Error(actual + " != " + expected) }
    function verify(value) { if (!value) throw new Error("verification failed") }
    Component.onCompleted: Qt.callLater(function() {
        try {
            test_v1_panel_reveals_without_v2_property()
            test_v2_panel_preserves_animation_progress()
            test_quotes_resolve_from_module_directory()
            console.log("AI_PANEL_VARIANTS_AND_QUOTES_PASS")
            Qt.exit(0)
        } catch (error) { console.error(error); Qt.exit(1) }
    })
        function test_v1_panel_reveals_without_v2_property() {
            var panel = panelBinding.createObject(fixture, {root: v1})
            compare(panel.reveal, 0)
            v1.aiUsageVisible = true
            compare(panel.reveal, 1)
            v1.aiUsageVisible = false
            compare(panel.reveal, 0)
            panel.destroy()
        }
        function test_v2_panel_preserves_animation_progress() {
            var panel = panelBinding.createObject(fixture, {root: v2})
            v2.aiUsageReveal = 0.35
            compare(panel.reveal, 0.35)
            v2.aiUsageReveal = 1
            compare(panel.reveal, 1)
            panel.destroy()
        }
        function test_quotes_resolve_from_module_directory() {
            verify(quotesFile.text().indexOf("Steve Jobs") >= 0)
            verify(quotesFile.text().split("\\n").length > 10)
        }
}
'''.replace('    QUOTES\n', quotes + '\n').replace('            REVEAL\n', reveal + '\n'))
    result = subprocess.run(['qs', '-n', '-p', str(folder / 'shell.qml')],
                            env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen',
                                 'QT_QUICK_BACKEND': 'software', 'QT_QPA_PLATFORMTHEME': '',
                                 'XDG_RUNTIME_DIR': str(folder / 'runtime')},
                            capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    print(output, end='')
    assert result.returncode == 0 and 'AI_PANEL_VARIANTS_AND_QUOTES_PASS' in output, result.returncode
    assert not re.search(r'ERROR|ReferenceError|TypeError|Unable to assign|Binding loop', output)
