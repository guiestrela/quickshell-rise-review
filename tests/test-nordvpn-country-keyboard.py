#!/usr/bin/env python3
"""Real QtTest events against shared NordVPN controls and composed V1/V2 panels.

Only the layer-shell window and decorative adapter surfaces are replaced. No
production controller, process, settings file or VPN service is instantiated.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile
from qml_fixture_source import qml_fixture_text

ROOT = Path(__file__).resolve().parents[1]


def inert_panel(variant):
    text = qml_fixture_text(ROOT / f'variants/{variant}/panels/NordVPNPanel.qml')
    text = re.sub(r'^import (?:Quickshell[^\n]*|"../modules")\n', '', text, flags=re.M)
    text = text.replace('PanelWindow {', 'Item {', 1)
    text = re.sub(r'^    (?:screen:|color:|anchors \{|exclusionMode:|WlrLayershell\.)[^\n]*\n', '', text, flags=re.M)
    marker = '    property Component surfaceComponent: Component {'
    if marker in text:
        start = text.index(marker)
        opening = text.index('{', start)
        depth = 1
        end = opening + 1
        while depth:
            depth += (text[end] == '{') - (text[end] == '}')
            end += 1
        text = text[:start] + '    property Component surfaceComponent\n' + text[end:]
    return text


with tempfile.TemporaryDirectory(prefix='vpn-keyboard-', dir=os.environ.get('TMPDIR')) as directory:
    temp = Path(directory)
    (temp / 'UiText.qml').write_text(qml_fixture_text(ROOT / 'shared/components/UiText.qml'))
    component = ROOT / 'shared/components/CountrySelector.qml'
    if component.exists():
        (temp / component.name).write_text(qml_fixture_text(component))
    for variant in ['V1', 'V2']:
        (temp / f'Panel{variant}.qml').write_text(inert_panel(variant))
    fixture = (ROOT / 'tests/qml/tst_NordVpnCountryKeyboard.qml').read_text()
    (temp / 'tst_keyboard.qml').write_text(fixture)
    env = os.environ.copy()
    env.pop('DISPLAY', None)
    env.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='')
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(temp)],
                            capture_output=True, text=True, env=env, timeout=45)
    output = result.stdout + result.stderr
    print(output, end='')
    assert result.returncode == 0, 'NordVPN country keyboard QtTest failed'
    assert not any(word in output for word in ['ReferenceError', 'TypeError', 'Cannot assign']), output
