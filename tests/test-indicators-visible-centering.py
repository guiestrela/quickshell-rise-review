#!/usr/bin/env python3
"""Render the real Indicators adapters and check visible glyph ink bounds."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from qml_fixture_source import copy_qml_fixture

REPO = Path(__file__).resolve().parents[1]
SCENARIOS = [(variant, vertical, count, reveal)
             for variant in ('V1', 'V2')
             for vertical in (False, True)
             for count in (1, 3)
             for reveal in (False, True)]


def make_qml(base, variant, vertical, count, reveal, image_path):
    widget = base / 'components/IndicatorsWidget.qml'
    source_path = Path(os.environ.get('INDICATORS_WIDGET_SOURCE',
                                     REPO / 'shared/components/IndicatorsWidget.qml'))
    source = source_path.read_text()
    source = source.replace('    Grid {\n        id: grid\n',
                            '    Grid {\n        id: grid\n        objectName: "indicator-grid"\n', 1)
    source = source.replace('                id: indicator\n                required property var modelData\n',
                            '                id: indicator\n                objectName: "indicator-cell-" + modelData.id\n                required property var modelData\n', 1)
    source = source.replace('                UiText {\n                    anchors.centerIn: parent\n',
                            '                UiText {\n                    objectName: "indicator-glyph-" + indicator.modelData.id\n                    anchors.centerIn: parent\n', 1)
    source = source.replace('                MouseArea {\n                    anchors.fill: parent\n',
                            '                MouseArea {\n                    objectName: "indicator-mouse-" + indicator.modelData.id\n                    anchors.fill: parent\n', 1)
    widget.write_text(source)

    adapter = base / variant.lower() / 'IndicatorsWidget.qml'
    adapter_text = (REPO / f'variants/{variant}/modules/IndicatorsWidget.qml').read_text()
    adapter_text = adapter_text.replace('import "../../../shared/components" as Shared',
                                        'import "../components" as Shared')
    if '    HoverHandler { id: reveal }' not in adapter_text or 'revealInactive: reveal.hovered' not in adapter_text:
        raise AssertionError(f'{variant} adapter hover contract changed')
    adapter_text = adapter_text.replace('    HoverHandler { id: reveal }',
                                        '    property bool fixtureHover: false\n    HoverHandler { id: reveal }', 1)
    adapter_text = adapter_text.replace('revealInactive: reveal.hovered',
                                        'revealInactive: reveal.hovered || module.fixtureHover', 1)
    if variant == 'V1':
        adapter_text = adapter_text.replace(
            '    Rectangle {\n        visible: !module.vertical',
            '    Rectangle {\n        objectName: "indicator-capsule"\n        visible: !module.vertical', 1)
    adapter.write_text(adapter_text)

    is_v1 = variant == 'V1'
    coordinator = f'''QtObject {{
        id: coordinator
        property bool available: true
        property bool passwordless: false
        property bool recording: {str(count == 3).lower()}
        property bool remote: false
        property var remoteSession: null
        property int reminderCount: 0
        property string reminderTooltip: "Reminder"
        property bool night: false
        property bool silenced: true
        property bool awake: {str(count == 3).lower()}
        property var notifications: ({{}})
        property var idle: ({{}})
        property var nightlight: ({{}})
        property int activationCount: 0
        property string lastActivated: ""
        function activate(id) {{ activationCount++; lastActivated = id }}
    }}'''
    indicator_type = f'{variant}.IndicatorsWidget'
    surface = '''Rectangle {
        id: indicatorCapsule
        objectName: "indicator-capsule"
        visible: !vertical
        width: parent.width
        height: 24
        anchors.centerIn: parent
        radius: 6
        color: "#17354f"
        border.width: 0
    }''' if not is_v1 else ''
    qml = f'''import QtQuick
import QtQuick.Window
import "{variant.lower()}" as {variant}
Window {{
    id: win
    visible: true
    width: 200
    height: 220
    color: "#ffffff"
    QtObject {{
        id: theme
        property bool barVertical: {str(vertical).lower()}
        property bool modIndicators: true
        property int pillH: 24
        property int pillRadius: 6
        property int pillBorderW: 0
        property color pill: "#17354f"
        property color pillBorder: "#17354f"
        property color pillShadow: "#000000"
        property bool styleShadow: false
        property string barPosition: "top"
        readonly property string mono: "JetBrainsMono Nerd Font"
        property color seal: "#ff0000"
        property color widgetIconColor: "#ff0000"
        property bool barUnlocked: false
        property var tooltipOwner: null
        property string tooltipText: ""
        property var omarchyIndicators: coordinator
        function widgetContentColor(gid, fallback) {{ return fallback }}
        function showTooltip(text, x, y, bottom, owner) {{}}
        function hideTooltip(owner) {{}}
    }}
    {coordinator}
    Item {{
        id: host
        objectName: "indicator-host"
        width: module.implicitWidth
        height: module.implicitHeight
        anchors.centerIn: parent
        {surface}
        {indicator_type} {{
            id: module
            objectName: "indicator-module"
            fixtureHover: {str(reveal).lower()}
            root: theme
            width: module.implicitWidth
            height: module.implicitHeight
        }}
    }}
    function bounds(item) {{
        var p = item.mapToItem(win.contentItem, 0, 0)
        return {{x:p.x, y:p.y, width:item.width, height:item.height}}
    }}
    function findNamed(item, name) {{
        if (item.objectName === name) return item
        for (var i=0; i<item.children.length; i++) {{
            var found = findNamed(item.children[i], name)
            if (found) return found
        }}
        return null
    }}
    function collectCells(item, out) {{
        if (String(item.objectName).indexOf("indicator-cell-") === 0)
            out.push({{id:item.objectName.substring("indicator-cell-".length), box:bounds(item),
            active:item.active, opacity:findNamed(item,"indicator-glyph-" + item.modelData.id).opacity}})
        for (var i=0; i<item.children.length; i++) collectCells(item.children[i], out)
    }}
    function collectGlyphs(item, out) {{
        if (String(item.objectName).indexOf("indicator-glyph-") === 0)
            out.push({{id:item.objectName.substring("indicator-glyph-".length), box:bounds(item),
                text:item.text, implicitWidth:item.implicitWidth, implicitHeight:item.implicitHeight,
                contentWidth:item.contentWidth, contentHeight:item.contentHeight, baseline:item.baselineOffset}})
        for (var i=0; i<item.children.length; i++) collectGlyphs(item.children[i], out)
    }}
    Timer {{
        interval: 350
        running: true
        onTriggered: {{
            var ref = findNamed(host, "indicator-capsule")
            if (!ref || !ref.visible) ref = host
            var cells=[]; collectCells(host, cells)
            var glyphs=[]; collectGlyphs(host, glyphs)
            var clickTarget = findNamed(host, "indicator-mouse-Dnd")
            if (!clickTarget) {{ console.error("ACTIVE_CLICK_TARGET_MISSING"); Qt.exit(1); return }}
            clickTarget.clicked(null)
            if (coordinator.activationCount !== 1 || coordinator.lastActivated !== "Dnd") {{
                console.error("ACTIVE_CLICK_MOCK_FAILED"); Qt.exit(1); return
            }}
            console.log("INK_CASE " + JSON.stringify({{
                variant:{json.dumps(variant)}, vertical:{str(vertical).lower()}, requested:{count}, reveal:{str(reveal).lower()},
                capsule:bounds(ref), host:bounds(host), module:bounds(module),
                core:bounds(findNamed(host,"indicators-active-group")),
                grid:bounds(findNamed(host,"indicator-grid")), cells:cells, glyphs:glyphs,
                contentWidth:module.implicitWidth, contentHeight:module.implicitHeight
            }}))
            win.contentItem.grabToImage(function(result) {{
                if (!result.saveToFile({json.dumps(str(image_path))})) {{
                    console.error("INK_CAPTURE_SAVE_FAILED"); Qt.exit(1); return
                }}
                console.log("INK_CAPTURED")
                Qt.quit()
            }})
        }}
    }}
}}
'''
    (base / 'shell.qml').write_text(qml)


def ink_bounds(image, width, height, region=None):
    raw = subprocess.check_output(['magick', str(image), '-depth', '8', 'RGB:-'])
    if len(raw) != width * height * 3:
        raise AssertionError(f'Unexpected capture bytes: {len(raw)} for {width}x{height}')
    if region is None:
        x0, y0, x1, y1 = 0, 0, width, height
    else:
        x0 = max(0, int(region['x']))
        y0 = max(0, int(region['y']))
        x1 = min(width, int(region['x'] + region['width'] + 0.999))
        y1 = min(height, int(region['y'] + region['height'] + 0.999))
    points = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            off = (y * width + x) * 3
            r, g, b = raw[off:off+3]
            if r > 110 and r > g + 55 and r > b + 55:
                points.append((x, y))
    if not points:
        return None
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return {'left':min(xs), 'top':min(ys), 'right':max(xs)+1, 'bottom':max(ys)+1,
            'width':max(xs)-min(xs)+1, 'height':max(ys)-min(ys)+1,
            'centerX':(min(xs)+max(xs)+1)/2, 'centerY':(min(ys)+max(ys)+1)/2}


with tempfile.TemporaryDirectory(prefix='rise-indicators-ink-', dir=os.environ.get('TMPDIR')) as directory:
    base = Path(directory)
    (base / 'runtime').mkdir(mode=0o700)
    (base / 'components').mkdir()
    (base / 'v1').mkdir()
    (base / 'v2').mkdir()
    for name in ('IndicatorsWidget.qml', 'UiText.qml', 'TooltipMixin.qml'):
        copy_qml_fixture(REPO / 'shared/components' / name, base / 'components' / name)
    copy_qml_fixture(REPO / 'variants/V1/modules/PillShadow.qml', base / 'v1/PillShadow.qml')
    artifact_dir = os.environ.get('INDICATORS_ARTIFACT_DIR')
    if artifact_dir:
        Path(artifact_dir).mkdir(parents=True, exist_ok=True)

    failures = []
    for variant, vertical, active_count, reveal in SCENARIOS:
        image = base / f'{variant}-{"vertical" if vertical else "horizontal"}-{active_count}-reveal{int(reveal)}.png'
        make_qml(base, variant, vertical, active_count, reveal, image)
        env = dict(os.environ, XDG_RUNTIME_DIR=str(base / 'runtime'), QT_QPA_PLATFORM='offscreen',
                   QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='', QT_SCALE_FACTOR='1')
        env.pop('WAYLAND_DISPLAY', None)
        env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
        result = subprocess.run(['qs', '-n', '-p', str(base / 'shell.qml')], env=env,
                                capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        match = re.search(r'^.*INK_CASE (\{.*\})$', output, re.M)
        if result.returncode or 'INK_CAPTURED' not in output or not match:
            raise SystemExit(f'FIXTURE_FAILED {variant} vertical={vertical} n={active_count}\n{output}')
        data = json.loads(match.group(1))
        expected_count = 6 if reveal else active_count
        cells = data['cells']
        if len(cells) != expected_count:
            raise AssertionError(f'{variant} vertical={vertical} active={active_count} reveal={reveal}: '
                                 f'expected {expected_count} visible cells, got {len(cells)}')
        active_ids = {'Dnd'} if active_count == 1 else {'ScreenRecording', 'Dnd', 'StayAwake'}
        expected_ids = (['PasswordlessSudo', 'ScreenRecording', 'Reminder', 'NightLight', 'Dnd', 'StayAwake']
                        if reveal else [name for name in ('ScreenRecording', 'Dnd', 'StayAwake') if name in active_ids])
        actual_ids = [cell['id'] for cell in cells]
        if actual_ids != expected_ids or 'RemoteSession' in actual_ids:
            raise AssertionError(f'{variant} vertical={vertical} active={active_count} reveal={reveal}: '
                                 f'unexpected filtered model {actual_ids}, expected {expected_ids}')
        for cell in cells:
            expected_active = cell['id'] in active_ids
            expected_opacity = 1.0 if expected_active else 0.45
            if cell['active'] != expected_active or abs(cell['opacity'] - expected_opacity) > 0.01:
                raise AssertionError(f'{variant} disabled/revealed icon state changed: {cell}')
        capsule, core, grid = data['capsule'], data['core'], data['grid']
        ink = ink_bounds(image, 200, 220)
        if not ink:
            raise AssertionError(f'No active glyph pixels in {variant} vertical={vertical} n={active_count}')
        dx = ink['centerX'] - (capsule['x'] + capsule['width'] / 2)
        dy = ink['centerY'] - (capsule['y'] + capsule['height'] / 2)
        label = f'{variant} vertical={vertical} active={active_count} reveal={reveal}'
        if abs(dx) > 1.5 or abs(dy) > 1.5:
            failures.append(f'{label}: aggregate ink offset ({dx:.2f},{dy:.2f})px')

        if vertical:
            expected_grid_width = 20
            expected_grid_height = 24 * expected_count + 4 * (expected_count - 1)
            expected_grid_x = core['x'] + (core['width'] - expected_grid_width) / 2
            expected_grid_y = core['y'] + (core['height'] - expected_grid_height) / 2
        else:
            expected_grid_width = 20 * expected_count + 4 * (expected_count - 1)
            expected_grid_height = 24
            expected_grid_x = core['x']
            expected_grid_y = core['y'] + (core['height'] - expected_grid_height) / 2
        for key, expected in (('x', expected_grid_x), ('y', expected_grid_y),
                              ('width', expected_grid_width), ('height', expected_grid_height)):
            if abs(grid[key] - expected) > 0.25:
                failures.append(f'{label}: grid {key}={grid[key]:.2f}, expected {expected:.2f}')

        glyph_offsets = []
        for index, cell in enumerate(cells):
            if vertical:
                expected_x = core['x'] + (core['width'] - 20) / 2
                expected_y = expected_grid_y + index * 28
            else:
                expected_x = expected_grid_x + index * 24
                expected_y = expected_grid_y
            cell_box = cell['box']
            if abs(cell_box['x'] - expected_x) > 0.25 or abs(cell_box['y'] - expected_y) > 0.25:
                failures.append(f'{label} {cell["id"]}: cell position ({cell_box["x"]:.2f},{cell_box["y"]:.2f}) '
                                f'expected ({expected_x:.2f},{expected_y:.2f})')
            glyph_ink = ink_bounds(image, 200, 220, cell_box)
            if not glyph_ink:
                raise AssertionError(f'{label} {cell["id"]}: no glyph pixels inside its rendered cell')
            gx = glyph_ink['centerX'] - (cell_box['x'] + cell_box['width'] / 2)
            gy = glyph_ink['centerY'] - (cell_box['y'] + cell_box['height'] / 2)
            glyph_offsets.append((cell['id'], gx, gy))
            if abs(gx) > 1.5 or abs(gy) > 1.5:
                failures.append(f'{label} {cell["id"]}: glyph ink offset inside cell ({gx:.2f},{gy:.2f})px')
        print(f'{label}: capsule={capsule} grid={grid} ink={ink} delta=({dx:.2f},{dy:.2f}) '
              f'glyph-deltas={glyph_offsets}')
        if artifact_dir:
            shutil.copy2(image, Path(artifact_dir) / image.name)
    if failures:
        raise SystemExit('INDICATORS_INK_CENTER_FAIL\n' + '\n'.join(failures))
    print('INDICATORS_INK_CENTER_PASS: rendered glyph bounds centered in V1/V2, horizontal/vertical, 1 and 3 active icons')
