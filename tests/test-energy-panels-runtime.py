#!/usr/bin/env python3
"""Production energy panels with inert commands; optional hidden Wayland load."""
from qml_fixture_source import qml_fixture_bytes, qml_fixture_source, qml_fixture_text
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
native = '--native' in sys.argv
with tempfile.TemporaryDirectory(prefix='rise-energy-panels-', dir='/tmp') as directory:
    temp = Path(directory)
    battery_panel = repo / 'shared/panels/BatteryPanel.qml'
    battery_match = re.search(
        r'command:\s*\["python3",\s*(?:decodeURIComponent\(String\()?Qt\.resolvedUrl\("([^"]+)"\)',
        battery_panel.read_text())
    assert battery_match, 'BatteryPanel must resolve its helper from Qt.resolvedUrl'
    battery_helper = (battery_panel.parent / battery_match.group(1)).resolve()
    expected_helper = repo / 'scripts/rise-battery-status.py'
    assert battery_helper == expected_helper and battery_helper.is_file(), (
        f'BatteryPanel helper must resolve to {expected_helper}, got {battery_helper}')

    fixture_helper = temp / 'scripts/rise-battery-status.py'
    fixture_helper.parent.mkdir()
    shutil.copy2(battery_helper, fixture_helper)
    fake_bin = temp / 'fake-battery-bin'
    fake_bin.mkdir()
    fake_upower = fake_bin / 'upower'
    fake_upower.write_text(f'''#!{sys.executable}
import sys
args=sys.argv[1:]
if args==["-i","/org/freedesktop/UPower/devices/DisplayDevice"]:
 print("""type: battery
percentage: 83.4%
state: discharging
time to empty: 2.5 hours
energy-rate: 12.5 W
energy-full: 80.0 Wh""")
elif args==["-e"]:
 print("/org/freedesktop/UPower/devices/battery_BAT0")
elif args==["-i","/org/freedesktop/UPower/devices/battery_BAT0"]:
 print("""type: battery
charge-cycles: 47
energy-full: 72.0 Wh
energy-full-design: 80.0 Wh""")
else:
 print("unexpected fixture call", file=sys.stderr); sys.exit(2)
''')
    fake_upower.chmod(0o700)
    helper_env = dict(os.environ, PATH=str(fake_bin) + os.pathsep + os.environ.get('PATH', ''))
    helper_run = subprocess.run([sys.executable, str(battery_helper)], env=helper_env,
                                capture_output=True, text=True, timeout=10)
    assert helper_run.returncode == 0, helper_run.stderr
    battery_data = json.loads(helper_run.stdout)
    assert battery_data == {
        'schema': 1, 'batteryId': 'BAT0', 'percentage': 83, 'status': 'discharging',
        'timeLabel': 'Time left', 'timeText': '2h 30m', 'powerRate': '12.5',
        'sizeText': '80 Wh', 'healthText': '90%', 'cycles': 47,
    }, battery_data
    fixture_helper_path = str(fixture_helper.resolve())
    runtime = temp / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant, path in [('V1', 'variants/V1'), ('V2', 'variants/V2')]:
        folder = temp / variant
        modules, panels = folder / 'modules', folder / 'panels'
        modules.mkdir(parents=True)
        panels.mkdir()
        common = folder / 'shared'
        common.mkdir()
        (folder / 'OmarchyPower.js').write_bytes(qml_fixture_bytes(qml_fixture_source(repo / 'shared/logic/OmarchyPower.js')))
        texts = []
        for name in ['BatteryPanel', 'BrightnessPanel', 'VolumePanel', 'PowerProfilePanel']:
            adapter = None
            if name in ['BatteryPanel', 'BrightnessPanel', 'VolumePanel']:
                adapter = qml_fixture_text(repo / path / 'panels' / f'{name}.qml')
                adapter = adapter.replace('../../../shared/panels', '../shared')
                text = qml_fixture_text(repo / 'shared/panels' / f'{name}.qml')
                text = text.replace('import QtQuick\n', 'import QtQuick\nimport "../modules"\n', 1)
                text = text.replace('../logic/OmarchyPower.js', '../OmarchyPower.js')
                text = text.replace('../services/MicrophonePeakMonitor.qml', 'MicrophonePeakMonitor.qml')
            else:
                text = qml_fixture_text(repo / path / 'panels' / f'{name}.qml')
            text = text.replace('../../../shared/logic/OmarchyPower.js', '../OmarchyPower.js')
            texts.append(text + ('\n' + adapter if adapter else ''))
            if not native:
                text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n', '', text, flags=re.M)
                text = text.replace('PanelWindow {', 'Rectangle {\n    width: 800; height: 700\n    property var screen', 1)
                text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n', '', text, flags=re.M)
            text = text.replace('id: card\n', 'id: card; objectName: "card"\n')
            text = text.replace('id: profileRow\n', 'id: profileRow; objectName: "profile-" + modelData.key\n')
            for identity in ['batData', 'briData', 'setRunner', 'setProfileProc', 'audio', 'outputVolumeRunner', 'micVolumeRunner']:
                text = re.sub(r'\bid: '+identity+r'(?=;|\n| \})', 'id: '+identity+'; objectName: "'+identity+'"', text)
            if adapter:
                (common / f'{name}.qml').write_text(text)
                (panels / f'{name}.qml').write_text(adapter)
            else:
                (panels / f'{name}.qml').write_text(text)
        for name in ['UiText', 'IconText', 'PillShadow', 'SidePanelPositioner']:
            (modules / f'{name}.qml').write_bytes(qml_fixture_bytes(qml_fixture_source(repo / path / 'modules' / f'{name}.qml')))
        (modules / 'ConnectedPanelSurface.qml').write_text('''import QtQuick
Item { objectName: "connected-surface"; property var root; property bool ownerActive; property real targetX; property real reveal }
''')
        (panels / 'Process.qml').write_text('''import QtQuick
QtObject { property var command: []; property bool running: false; property var stdout; property var stderr; signal exited(int code) }
''')
        (panels / 'StdioCollector.qml').write_text('''import QtQuick
QtObject { property string text: ""; property bool waitForEnd:false; signal streamFinished() }
''')
        for name in ['Process.qml', 'StdioCollector.qml']:
            (common / name).write_bytes((panels / name).read_bytes())
        (modules / 'AudioData.qml').write_text('import QtQuick\nQtObject { property int volume:73; property bool muted:false; function refresh(){} }')
        (common / 'MicrophonePeakMonitor.qml').write_text('import QtQuick\nQtObject { property bool panelOpen:false; property bool muted:false; property real peak:0.42 }')
        fields = set(re.findall(r'\broot\.(\w+)', '\n'.join(texts)))
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
            elif field == 'volReveal':
                theme.append('property real volReveal: volVisible ? 1 : 0')
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
    VolumePanel { id: volume; root: theme }
    PowerProfilePanel { id: profile; root: theme }'''
        if native:
            qml = '''import QtQuick
import Quickshell
import "VARIANT/panels"
Scope {
    QtObject { id: theme; THEME }
    BODIES
    Timer { interval: 100; running: true; onTriggered: {
        if(battery.visible || brightness.visible || volume.visible || profile.visible) { Qt.exit(1); return }
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
        function test_style_and_position_contract() {
            var modern = "VARIANT" === "V2"
            compare(volume.animateReveal, !modern)
            compare(volume.micVolumeAnimationDuration, modern ? 100 : 0)
            for(var entry of [[battery,"batteryVisible",300],[brightness,"brightnessVisible",280],[volume,"volVisible",280]]) {
                var panel = entry[0]
                theme[entry[1]] = true
                tryCompare(panel, "reveal", 1)
                var card = panel.surfaceHost
                compare(card.width, entry[2])
                compare(card.radius, modern ? theme.panelRadius : theme.pillRadius)
                compare(card.border.width, modern ? 0 : theme.pillBorderW)
                compare(card.color.a, modern ? 0 : 1)
                compare(panel.gap, modern ? 6 : 8)
                var shadow = null
                for(var child of card.children) if("theme" in child && child.theme === theme) shadow = child
                verify(shadow !== null, "shadow must remain parented directly to the card")
                compare(shadow.parent, card)
                if(!modern) compare(shadow.pillSurface, card)
                var surface = findChild(card, "connected-surface")
                compare(surface !== null, modern)
                if(modern) { compare(surface.parent, card); compare(surface.ownerActive, true) }
                theme.barPosition = "bottom"
                tryCompare(card, "y", panel.height - panel.barBottom - panel.gap - card.height)
                theme.barPosition = "left"
                theme.barVertical = true
                tryCompare(card, "x", theme.verticalBarWidth + panel.gap)
                theme.barVertical = false
                theme.barPosition = "top"
                tryCompare(card, "y", panel.barBottom + panel.gap)
                theme[entry[1]] = false
            }
        }
        function test_data_queue_profile_and_close() {
            var audio = findChild(volume,"audio")
            compare(volume.volume,73);audio.volume=42;compare(volume.volume,42)
            tryCompare(volume,"micMeterAvailable",true)
            compare(volume.micPeakValue,0.42)
            volume.setOutputVolume(0.7);volume.flushOutputVolume()
            var outputRunner=findChild(volume,"outputVolumeRunner")
            compare(outputRunner.running,true)
            volume.setOutputVolume(0.2);volume.flushOutputVolume()
            compare(volume.pendingOutputVolume,0.2)
            outputRunner.running=false;outputRunner.exited(0)
            compare(volume.pendingOutputVolume,-1)
            compare(outputRunner.command,["timeout","4","wpctl","set-volume","@DEFAULT_AUDIO_SINK@","0.200"])
            var batteryReader = findChild(battery, "batData")
            compare(batteryReader.command[0], "python3")
            compare(batteryReader.command[1], EXPECTED_BATTERY_HELPER)
            batteryReader.stdout.text = JSON.stringify({schema:1,batteryId:"BAT0",percentage:73,status:"charging",timeLabel:"Time to full",timeText:"1h",powerRate:"20",sizeText:"50 Wh",healthText:"95%",cycles:100})
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
            for(var entry of [[battery,"batteryVisible"],[brightness,"brightnessVisible"],[volume,"volVisible"],[profile,"powerProfileVisible"]]) {
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
        qml = qml.replace('EXPECTED_BATTERY_HELPER', json.dumps(fixture_helper_path))
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
