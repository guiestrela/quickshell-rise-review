#!/usr/bin/env python3
"""Shared services can read the bar contract while variants load and swap."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'Bar.qml').read_text()
contract = source[source.index('    readonly property string fontFamily:'):source.index('    width: 0')]
qml = '''import QtQuick
import QtTest
Item {
    id: root
    QtObject {
        id: variantHost
        property var activeItem: null
        property bool ready: false
    }
''' + contract + '''
    TestCase {
        name: "ShellBarContract"
        function test_loading_and_variant_swaps() {
            compare(root.fontFamily, "JetBrainsMono Nerd Font")
            compare(root.barSize, 35)
            compare(root.position, "top")
            verify(root.barHidden)
            for (var variant of [
                {fontFamily: "JetBrainsMono Nerd Font", barSize: 35, position: "top"},
                {fontFamily: "JetBrainsMono Nerd Font", barSize: 33, position: "bottom"}
            ]) {
                variantHost.activeItem = variant
                variantHost.ready = true
                compare(root.fontFamily, variant.fontFamily)
                compare(root.barSize, variant.barSize)
                compare(root.position, variant.position)
                verify(!root.barHidden)
                variantHost.ready = false
                variantHost.activeItem = null
                compare(typeof root.fontFamily, "string")
                verify(Number.isFinite(root.barSize))
                verify(root.barHidden)
            }
        }
    }
}
'''
with tempfile.TemporaryDirectory(prefix='rise-bar-contract-') as temp:
    probe = Path(temp) / 'tst_contract.qml'
    probe.write_text(qml)
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(probe)],
        env=dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='',
                 QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=temp),
        capture_output=True, text=True, timeout=10)
    output = result.stdout + result.stderr
    assert result.returncode == 0, output
    assert not any(error in output for error in ['TypeError', 'ReferenceError', 'Unable to assign']), output
print('PASS: shared bar font/size/position/visibility during loading and V1/V2 swaps')
