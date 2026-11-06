#!/usr/bin/env python3
"""Indicators are a configurable G23 module, independent of the clock, in V1/V2."""
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
for variant in ('V1', 'V2'):
    base = repo / 'variants' / variant
    bar = (base / 'BarSlot.qml').read_text()
    theme = (base / 'Theme.qml').read_text()
    control = (base / 'panels/ControlPanel.qml').read_text()
    module = (base / 'modules/IndicatorsWidget.qml').read_text()

    center_start = bar.index('id: compCenter')
    center_end = bar.index('id: compMpris', center_start)
    center = bar[center_start:center_end]
    assert 'CommonComponents.IndicatorsWidget' not in center
    assert 'nativeIndicators' not in center
    assert 'modIndicators' not in center
    assert 'width: g8.showIcons ? iconsRow.implicitWidth : 0' in center

    assert '"G23": compIndicators' in bar
    assert 'Component { id: compIndicators; IndicatorsWidget { root: barSlot.root } }' in bar
    assert 'Shared.IndicatorsWidget {' in module
    assert 'root.modIndicators' in module
    assert 'coordinator: module.root.omarchyIndicators' in module
    assert 'revealInactive: reveal.hovered' in module
    assert 'vertical: module.vertical' in module
    assert 'objectName: "indicators-empty-marker"' in module
    assert 'text: ">"' in module
    assert 'anchors.centerIn: parent' in module
    assert 'visible: module.root.modIndicators && !indicators.hasActive && !indicators.revealed' in module

    assert 'label: "Indicators"' in control
    assert 'modIndicators = !ctrlPanel.root.modIndicators' in control
    if variant == 'V2':
        assert 'gid: "G23"' in control
    else:
        assert 'objectName: "indicators-widget-toggle"' in control
    assert 'onModIndicatorsChanged: if (_widgetsLoaded) saveWidgets()' in theme

v1_defaults = (repo / 'variants/V1/modules/V1Defaults.js').read_text()
v1_order = (repo / 'variants/V1/BarSlot.qml').read_text()
v2_order = (repo / 'variants/V2/BarSlot.qml').read_text()
assert 'center: ["G8", "G23", ""]' in v1_defaults
assert 'id: centerModel; ListElement { gid: "G8" } ListElement { gid: "G23" }' in v1_order
assert 'ListElement { gid: "G8"; extra: false } ListElement { gid: "G23"; extra: true }' in v2_order
assert 'if (l.concat(c, r, tray).indexOf("G23") < 0)' in v1_order, 'Migrate old V1 layouts without moving existing widgets'
print('INDEPENDENT_INDICATORS_PASS: V1/V2 G23 registry, clock separation, persisted visibility, hover, and vertical module')
