#!/usr/bin/env python3
"""V2 Omarchy indicators live in the clock group and keep their visibility toggle."""
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
bar = (repo / 'variants/V2/BarSlot.qml').read_text()
theme = (repo / 'variants/V2/Theme.qml').read_text()
control = (repo / 'variants/V2/panels/ControlPanel.qml').read_text()

center_start = bar.index('id: compCenter')
center_end = bar.index('    Component {\n        id: compIndicators', center_start)
center = bar[center_start:center_end]
assert center.index('ClockWidget') < center.index('CommonComponents.IndicatorsWidget')
assert 'coordinator: barSlot.root.omarchyIndicators' in center
assert 'HoverHandler { id: indicatorHover }' in center[:center.index('id: nativeIndicatorsContainer')]
assert 'revealInactive: indicatorHover.hovered' in center
assert '(barSlot.root.modIndicators && nativeIndicators.hasActive)' in center
assert 'visible: barSlot.root.modIndicators && nativeIndicators.implicitWidth > 0' in center
assert 'width: barSlot.root.modIndicators ? nativeIndicators.implicitWidth : 0' in center
assert 'width: g8.showIcons ? iconsRow.implicitWidth : 0' in center
assert 'contentColor: g8.contentColor' in center
assert 'contentColor: barSlot.root.seal' not in center
date_start = center.index('id: dateLabel')
date_end = center.index('MouseArea {', date_start)
assert 'color: Qt.rgba(g8.contentColor.r, g8.contentColor.g, g8.contentColor.b, 0.5)' in center[date_start:date_end], 'Date text must keep its prior half-opacity color'

legacy_start = center_end
legacy_end = bar.index('    Component {\n        id: compMpris', legacy_start)
legacy = bar[legacy_start:legacy_end]
assert 'visible: false' in legacy and 'implicitWidth: 0' in legacy and 'implicitHeight: 0' in legacy
assert 'G23 remains registered' in legacy, 'Keep existing saved V2 layouts loadable'

assert 'gid: "G23"' in control and 'label: "Indicators"' in control
assert 'onVisibilityToggled: ctrlPanel.root.modIndicators = !ctrlPanel.root.modIndicators' in control
assert 'onModIndicatorsChanged: if (_widgetsLoaded) saveWidgets()' in theme
print('V2_INLINE_INDICATORS_PASS clock grouping, hover reveal, legacy layout loading and disable toggle')
