#!/usr/bin/env python3
"""Production CPU/GPU/memory content; inert fan controls, processes and surfaces.

Offscreen mode checks bindings and keyboard behavior. --native additionally
loads hidden PanelWindows on Wayland; neither mode invokes hardware helpers.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
native = '--native' in sys.argv
with tempfile.TemporaryDirectory(prefix='rise-system-panels-', dir='/tmp') as directory:
    temp = Path(directory)
    runtime = temp / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant, path in [('V1', 'versions/V1'), ('V2', 'versions/V1/variants/V2')]:
        folder = temp / variant
        modules = folder / 'modules'
        panels = folder / 'panels'
        modules.mkdir(parents=True)
        panels.mkdir()
        texts = []
        for name in ['CpuPanel', 'GpuPanel', 'MemoryPanel']:
            text = (repo / path / 'panels' / f'{name}.qml').read_text()
            texts.append(text)
            if not native:
                text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', text, flags=re.M)
                text = text.replace('PanelWindow {', 'Rectangle {\n    width: 800; height: 700\n    property var screen', 1)
                text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n', '', text, flags=re.M)
            text = text.replace('id: processRow\n', 'id: processRow; objectName: \"process-row-\" + index\n')
            text = text.replace('id: card\n', 'id: card; objectName: "card"\n')
            (panels / f'{name}.qml').write_text(text)
        for name in ['UiText', 'IconText', 'PillShadow', 'SidePanelPositioner']:
            (modules / f'{name}.qml').write_bytes((repo / path / 'modules' / f'{name}.qml').read_bytes())
        (modules / 'FanControl.qml').write_text('''import QtQuick
Item { objectName: "fanControl"; property var theme; property bool active; implicitHeight: 42; height: 42 }
''')
        (modules / 'FanRpmHistory.qml').write_text('''import QtQuick
Item { objectName: "fanHistory"; property var theme; property bool active; property bool externalSource; property int externalRpm: -1; property string sensorLabel; height: 42 }
''')
        (modules / 'ConnectedPanelSurface.qml').write_text('''import QtQuick
Item { property var root; property bool ownerActive; property real targetX; property real reveal }
''')
        (panels / 'Process.qml').write_text('''import QtQuick
QtObject { property var command: []; property bool running: false }
''')
        fields = set(re.findall(r'\b(?:cpuPanel|gpuPanel|memPanel)\.root\.(\w+)', '\n'.join(texts)))
        colors = {'bg', 'ink', 'paper', 'pillBorder', 'seal', 'sealRaw', 'sep', 'sumi', 'sumiHi',
                  'panelBorder', 'fillActive', 'fillPrimaryHover'}
        strings = {'barPosition': 'top', 'mono': 'monospace', 'cpuEnergyPreference': 'balanced',
                   'cpuScalingGovernor': 'performance', 'cpuModelName': 'Fixture CPU',
                   'kernelRelease': 'fixture', 'gpuBackend': 'fixture', 'gpuName': 'Fixture GPU',
                   'gpuPerformanceState': 'P0', 'gpuDriverVersion': 'fixture', 'memoryType': 'DDR5'}
        values = {'systemCpuPercent': 43, 'cpuCoreCount': 4, 'cpuThreadCount': 8,
                  'cpuClockMHz': 3200, 'cpuMaxClockMHz': 4000, 'gpuPercent': 56,
                  'gpuMemoryUsedMiB': 512, 'gpuMemoryTotalMiB': 1024, 'gpuFanRpm': 1000,
                  'systemMemUsedMiB': 4096, 'systemMemTotalMiB': 8192, 'systemMemPercent': 50}
        theme = []
        for field in sorted(fields):
            if field == 'activePopupScreen':
                value = 'Quickshell.screens[0]' if native else '({width:800,height:700})'
                theme.append(f'property var {field}: {value}')
            elif field == 'cpuTopProcesses':
                theme.append('property var cpuTopProcesses: [{name:"Fixture process",percent:12.5}]')
            elif field in colors:
                theme.append(f'property color {field}: "#999999"')
            elif field in strings:
                theme.append(f'property string {field}: {json.dumps(strings[field])}')
            elif field.endswith('Visible') or field == 'gpuAvailable':
                theme.append(f'property bool {field}: '+('true' if field == 'gpuAvailable' else 'false'))
            else:
                theme.append(f'property real {field}: {values.get(field, 6)}')
        theme += ['property bool barVertical: false', 'property real verticalBarWidth: 40',
                  'property bool styleShadow: false', 'property color pillShadow: "black"',
                  'function verticalAnchorY(name) { return 200 }']
        bodies = '''CpuPanel { id: cpu; root: theme }
    GpuPanel { id: gpu; root: theme }
    MemoryPanel { id: memory; root: theme }'''
        if native:
            qml = '''import QtQuick
import Quickshell
import "VARIANT/panels"
Scope {
    QtObject { id: theme; THEME }
    BODIES
    Timer { interval: 100; running: true; onTriggered: {
        if(cpu.visible || gpu.visible || memory.visible) { Qt.exit(1); return }
        console.log("SYSTEM_PANELS_HIDDEN_PASS VARIANT"); Qt.exit(0)
    } }
}
'''
        else:
            qml = '''import QtQuick
import QtTest
import "VARIANT/panels"
Item {
    width: 800; height: 700
    QtObject { id: theme; THEME }
    BODIES
    TestCase {
        name: "SystemPanelsVARIANT"; when: windowShown
        function test_metrics_and_close() {
            compare(cpu.cpuPct, 43)
            var processItem = findChild(cpu, "process-row-0")
            verify(processItem !== null)
            compare(processItem.process.name, "Fixture process")
            theme.cpuTopProcesses = []
            compare(processItem.process, null)
            theme.cpuTopProcesses = [{name:"New fixture process",percent:25}]
            compare(processItem.process.name, "New fixture process")
            compare(gpu.gpuUtil, 56)
            compare(memory.usedGiB, 4)
            theme.systemCpuPercent = 65; compare(cpu.cpuPct, 65)
            theme.gpuFanRpm = 1500
            compare(findChild(gpu, "fanHistory").externalRpm, 1500)
            theme.systemMemUsedMiB = 6144; compare(memory.usedGiB, 6)
            for (var entry of [[cpu,"cpuVisible"],[gpu,"gpuVisible"],[memory,"memVisible"]]) {
                theme[entry[1]] = true
                tryCompare(entry[0], "visible", true)
                var card = findChild(entry[0], "card")
                verify(card !== null); card.forceActiveFocus()
                keyClick(Qt.Key_Escape)
                compare(theme[entry[1]], false)
            }
        }
    }
}
'''
        qml = qml.replace('VARIANT', variant).replace('THEME', '\n'.join(theme)).replace('BODIES', bodies)
        probe = temp / f'{"native" if native else "tst"}_{variant}.qml'
        probe.write_text(qml)
        env = dict(os.environ, QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='')
        if native:
            env['QT_QPA_PLATFORM'] = 'wayland'
            command = ['qs', '-p', str(probe)]
        else:
            env.update(QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=str(runtime))
            command = ['/usr/lib/qt6/bin/qmltestrunner', '-input', str(probe)]
        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        print(output, end='')
        if result.returncode:
            raise SystemExit(result.returncode)
        if native:
            assert 'SYSTEM_PANELS_HIDDEN_PASS' in output, output
        assert not any(error in output for error in (
            'ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign', ' ERROR')), output
