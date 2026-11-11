#!/usr/bin/env python3
"""V2 visual tree/renderer in an offscreen normal Window; inert root/controller.
Only the layer-shell wrapper is adapted. This is not live-bar pixel acceptance.
"""
from qml_fixture_source import qml_fixture_source, qml_fixture_text
import os
from pathlib import Path
import re
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
FILES = ['shared/panels/DisplayManagerPanel.qml',
         'variants/V2/panels/DisplayManagerPanel.qml',
         'variants/V2/modules/ConnectedPanelSurface.qml',
         'variants/V2/modules/AiPanelSurface.qml',
         'variants/V2/modules/SidePanelPositioner.qml',
         'shared/components/UiText.qml']
env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='', QT_QUICK_BACKEND='software')
env.pop('DISPLAY', None)
env.pop('WAYLAND_DISPLAY', None)
with tempfile.TemporaryDirectory(prefix='display-v2-style-', dir=os.environ['TMPDIR']) as work:
    folder = Path(work)
    runtime = folder / "runtime"
    runtime.mkdir(mode=0o700)
    env["XDG_RUNTIME_DIR"] = str(runtime)
    for rel in FILES:
        dest = folder / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        data = (REPO / rel).read_text()
        if rel == FILES[0]:
            # Replace only the layer-shell wrapper: the production visual tree
            # and native ConnectedPanelSurface remain byte-identical below it.
            data = data.replace('import QtQuick\n', 'import QtQuick\nimport QtQuick.Window\n', 1).replace('PanelWindow {', 'Window {', 1)
            data = data.replace('    id: panel', '    id: panel\n    width: 1440\n    height: 900', 1)
            data = re.sub(r'    anchors \{[^}]*\}', '', data, count=1)
            data = re.sub(r'^    (?:WlrLayershell\..*|exclusionMode:.*|margins\..*|screen:.*)\n', '', data, flags=re.M)
        dest.write_text(data)
    fixture = qml_fixture_text(qml_fixture_source(REPO / 'tests/qml/qr-display-panel-runtime.qml'))
    fixture = fixture.replace('import "../../shared/panels"', 'import "variants/V2/panels"')
    fixture = fixture.replace('property bool displayManagerVisible: false', 'property bool displayManagerVisible: true')
    fixture = fixture.replace('property color bg: "#202020"', '''property color bg: "#202020"
        property color paper: "#202020"
        property color sumi: "#808080"
        property color fillHover: "#404040"
        property bool barVertical: false
        property real verticalBarWidth: 40
        function verticalAnchorY(name) { return 200 }
        property int v2BarHeight: 36
        property int panelRadius: 6
        property color panelOuterBorderColor: "#706050"
        property real panelOuterBorderW: 1
        property real panelInsetReveal: 1
        property real lastInset: -1
        function setPanelInsetX(x) { lastInset = x }''')
    fixture = fixture.replace('id: productionPanel', 'id: productionPanel\n        visible: true\n        width: 1440\n        height: 900')
    fixture = fixture.replace('Component.onCompleted: console.log("DISPLAY_PANEL_INSTANCE_CREATED")', 'Component.onCompleted: { contentItem.width = width; contentItem.height = height; console.log("DISPLAY_PANEL_INSTANCE_CREATED") }')
    start = fixture.index('    Timer {')
    fixture = fixture[:start] + '''    Timer {
        interval: 450; running: true
        onTriggered: {
            if (!productionPanel.connectedStyle || !productionPanel.visible || fakeController.refreshCount !== 1)
                throw new Error("native style offscreen fixture state")
            var card = productionPanel.surfaceHost
            function find(item, name) {
                if (item.objectName === name) return item
                for (var child of item.children || []) { var hit = find(child, name); if (hit) return hit }
                return null
            }
            var title = find(card, "display-v2-title")
            var close = find(card, "display-v2-close")
            var refresh = find(card, "display-refresh-v2")
            var column = find(card, "display-save").parent.parent
            var footer = column.children[column.children.length-1]
            if (footer.mapToItem(card,0,footer.height).y > card.height-16+1)
                throw new Error("V2 footer clipped: bottom="+footer.mapToItem(card,0,footer.height).y+" card="+card.height+" column="+column.implicitHeight+" footer="+footer.height+" width="+card.width)
            if (!title || !close || !refresh || !title.visible || title.font.pixelSize !== 13 || title.font.letterSpacing !== 2 || title.parent.height !== 24 || !refresh.visible)
                throw new Error("NordVPN-reference header/refresh contract")
            var apply = find(card, "display-position-apply")
            var spins = [apply.parent.children[1], apply.parent.children[2]]
            for (var spin of spins) {
                if (spin.background.radius !== 4) throw new Error("V2 Position corners must match compact V1: " + spin.background.radius)
                if (spin.implicitWidth !== 115 || spin.implicitHeight !== 30 || spin.up.indicator.width !== 24 || spin.down.indicator.width !== 24 || spin.font.pixelSize !== 11)
                    throw new Error("Position dimensions changed")
            }
            var surface = null
            for (var i = 0; i < card.children.length; ++i)
                if (card.children[i].resolvedTargetX !== undefined) surface = card.children[i]
            if (!surface || Math.abs(surface.resolvedTargetX - fakeRoot.displayManagerBarX) > 1 || Math.abs(fakeRoot.lastInset - surface.resolvedTargetX) > 1)
                throw new Error("native caret / bar inset not aligned")
            if (card.color.a !== 0 || card.border.width !== 0 || card.radius !== fakeRoot.panelRadius)
                throw new Error("generic border still drawn")
            fakeRoot.barPosition = "bottom"
            Qt.callLater(function() {
                if (surface.pointsUp || card.y < 0) throw new Error("bottom native geometry")
                fakeRoot.displayManagerBarX = 2
                Qt.callLater(function() {
                    if (Math.abs(surface.resolvedTargetX - (card.x + surface.centerX)) > 1 || Math.abs(fakeRoot.lastInset - surface.resolvedTargetX) > 1)
                        { console.error("EDGE_DIAG", surface.resolvedTargetX, card.x, surface.centerX, fakeRoot.lastInset, surface.hostWidth, surface.hostGeometryCoversTarget); Qt.quit(); return }
                    console.log("DISPLAY_V2_NATIVE_STYLE_PASS offscreen normal Window; native renderer; caret/inset/top/bottom/edge; no monitor actions")
                    Qt.quit()
                })
            })
        }
    }
}
'''
    (folder / 'shell.qml').write_text(fixture)
    try:
        result = subprocess.run(['qs', '-n', '-p', str(folder / 'shell.qml')], env=env, capture_output=True, text=True, timeout=12)
    except subprocess.TimeoutExpired as exc:
        print((exc.stdout or b'').decode(errors='replace') + (exc.stderr or b'').decode(errors='replace'))
        raise
    output = re.sub(r'\x1b\[[0-9;]*m', '', result.stdout + result.stderr)
    print(output)
    assert result.returncode == 0, 'runtime failed'
    assert 'DISPLAY_V2_NATIVE_STYLE_PASS' in output, 'native style sentinel missing'
    assert not any(x in output for x in ['ReferenceError', 'TypeError', 'Unable to assign']), 'runtime binding error'
    assert not re.search(r'(?m)^\s*ERROR\b', output), 'runtime error'
