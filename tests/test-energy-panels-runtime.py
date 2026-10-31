#!/usr/bin/env python3
"""Production energy panels with inert commands; optional hidden Wayland load."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
native = '--native' in sys.argv
with tempfile.TemporaryDirectory(prefix='rise-energy-panels-', dir='/tmp') as directory:
    temp = Path(directory)
    runtime = temp / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant, path in [('V1', 'versions/V1'), ('V2', 'versions/V1/variants/V2')]:
        folder = temp / variant
        modules, panels = folder / 'modules', folder / 'panels'
        modules.mkdir(parents=True)
        panels.mkdir()
        (folder / 'OmarchyPower.js').write_bytes((repo / path / 'OmarchyPower.js').read_bytes())
        texts = []
        for name in ['BatteryPanel', 'BrightnessPanel', 'PowerProfilePanel']:
            text = (repo / path / 'panels' / f'{name}.qml').read_text()
            texts.append(text)
            if not native:
                text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', text, flags=re.M)
                text = text.replace('PanelWindow {', 'Rectangle {\n    width: 800; height: 700\n    property var screen', 1)
                text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n', '', text, flags=re.M)
            text = text.replace('id: card\n', 'id: card; objectName: "card"\n')
            text = text.replace('id: profileRow\n', 'id: profileRow; objectName: "profile-" + modelData.key\n')
            for identity in ['batData', 'briData', 'setRunner', 'setProfileProc']:
                text = re.sub(r'\bid: '+identity+r'(?=;|\n)', 'id: '+identity+'; objectName: "'+identity+'"', text)
            (panels / f'{name}.qml').write_text(text)
        for name in ['UiText', 'IconText', 'PillShadow', 'SidePanelPositioner']:
            (modules / f'{name}.qml').write_bytes((repo / path / 'modules' / f'{name}.qml').read_bytes())
        (modules / 'ConnectedPanelSurface.qml').write_text('''import QtQuick
Item { property var root; property bool ownerActive; property real targetX; property real reveal }
''')
        (panels / 'Process.qml').write_text('''import QtQuick
QtObject { property var command: []; property bool running: false; property var stdout; signal exited(int code) }
''')
        (panels / 'StdioCollector.qml').write_text('''import QtQuick
QtObject { property string text: ""; signal streamFinished() }
''')
        fields = set(re.findall(r'\b(?:batPanel|briPanel|profilePanel)\.root\.(\w+)', '\n'.join(texts)))
        colors = {'bg','fillActive','fillPrimaryHover','fillHover','fillIdle','indigo','ink','paper',
                  'pillBorder','seal','sep','sumi','sumiHi','panelBorder'}
        strings = {'barPosition':'top','mono':'monospace','powerProfileCurrent':'balanced'}
        theme = []
        for field in sorted(fields):
            if field == 'evenW':
                continue
            if field == 'activePopupScreen':
                value = 'Quickshell.screens[0]' if native else '({width:800,height:700})'
                theme.append(f'property var {field}: {value}')
            elif field in colors:
                theme.append(f'property color {field}: "#999999"')
            elif field in strings:
                theme.append(f'property string {field}: {json.dumps(strings[field])}')
            elif field.endswith('Visible'):
                theme.append(f'property bool {field}: false')
            else:
                theme.append(f'property real {field}: 6')
        theme += ['property bool barVertical: false', 'property real verticalBarWidth: 40',
                  'property bool styleShadow: false', 'property color pillShadow: "black"',
                  'function verticalAnchorY(name) { return 200 }',
                  'function evenW(value) { return Math.round(value / 2) * 2 }']
        bodies = '''BatteryPanel { id: battery; root: theme }
    BrightnessPanel { id: brightness; root: theme }
    PowerProfilePanel { id: profile; root: theme }'''
        if native:
            qml = '''import QtQuick
import Quickshell
import "VARIANT/panels"
Scope {
    QtObject { id: theme; THEME }
    BODIES
    Timer { interval: 100; running: true; onTriggered: {
        if(battery.visible || brightness.visible || profile.visible) { Qt.exit(1); return }
        console.log("ENERGY_PANELS_HIDDEN_PASS VARIANT"); Qt.exit(0)
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
    function mouse(item) {
        for(var child of item.children) if(typeof child.clicked === "function") return child
        return null
    }
    TestCase {
        name: "EnergyPanelsVARIANT"; when: windowShown
        function test_data_queue_profile_and_close() {
            var batteryReader = findChild(battery, "batData")
            batteryReader.stdout.text = "BAT0|73|charging|Time to full|1h|20 W|50 Wh|95%|100"
            batteryReader.stdout.streamFinished()
            compare(battery.percent, 73); verify(battery.charging)
            compare(battery.cycles, 100); compare(battery.healthLabel, "Health (BAT0)")
            brightness.requestSetPercent(200); compare(brightness.percent, 100)
            brightness.drainSetQueue()
            var setter = findChild(brightness, "setRunner")
            compare(setter.running, true); verify(setter.command[2].includes("100%"))
            brightness.requestSetPercent(20); brightness.drainSetQueue()
            compare(brightness.queuedSetPercent, 20)
            setter.running = false; setter.exited(0)
            compare(brightness.queuedSetPercent, -1)
            verify(setter.command[2].includes("20%"))
            theme.powerProfileVisible = true
            tryCompare(profile, "visible", true)
            var performance = findChild(profile, "profile-performance")
            verify(performance !== null)
            mouseClick(mouse(performance), 5, 5)
            compare(theme.powerProfileCurrent, "performance")
            compare(theme.powerProfileVisible, false)
            compare(findChild(profile, "setProfileProc").command,
                ["bash","-c","powerprofilesctl set performance"])
            for(var entry of [[battery,"batteryVisible"],[brightness,"brightnessVisible"],[profile,"powerProfileVisible"]]) {
                theme[entry[1]] = true
                tryCompare(entry[0], "visible", true)
                findChild(entry[0], "card").forceActiveFocus()
                keyClick(Qt.Key_Escape)
                compare(theme[entry[1]], false)
            }
        }
    }
}
'''
        qml = qml.replace('VARIANT',variant).replace('THEME','\n'.join(theme)).replace('BODIES',bodies)
        probe = temp / f'{"native" if native else "tst"}_{variant}.qml'
        probe.write_text(qml)
        env = dict(os.environ, QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='')
        if native:
            env['QT_QPA_PLATFORM'] = 'wayland'
            command = ['qs','-p',str(probe)]
        else:
            env.update(QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=str(runtime))
            command = ['/usr/lib/qt6/bin/qmltestrunner','-input',str(probe)]
        result = subprocess.run(command,env=env,capture_output=True,text=True,timeout=15)
        output = result.stdout + result.stderr
        print(output,end='')
        if result.returncode:
            raise SystemExit(result.returncode)
        if native:
            assert 'ENERGY_PANELS_HIDDEN_PASS' in output,output
        assert not any(error in output for error in (
            'ReferenceError','TypeError','Binding loop','Unable to assign',' ERROR')),output
