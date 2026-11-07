#!/usr/bin/env python3
"""Render every vertical module in both variants and enforce its Control Center width."""
from pathlib import Path
import json
import os
import re
import subprocess
import tempfile

from qml_fixture_source import write_hyprland_stub

ROOT = Path(__file__).resolve().parents[1]
SCRATCH = Path(os.environ.get("TMPDIR", Path.home() / ".hermes/profiles/desktop-dev/cache/scratch"))
ARTIFACTS = Path(os.environ.get(
    "VERTICAL_WIDTH_ARTIFACT_DIR",
    SCRATCH / "rise-vertical-width-artifacts",
))
ARTIFACTS.mkdir(parents=True, exist_ok=True)
REFERENCE_WIDTHS = {"V1": 32, "V2": 24}
SPECIAL_IDS = {"G2", "G3", "G8", "G10"}


def registry_ids(variant):
    source = (ROOT / f"variants/{variant}/BarSlot.qml").read_text()
    match = re.search(r"readonly property var registry:\s*\(\{(.*?)\}\)", source, re.S)
    assert match, f"{variant}: registry declaration not found"
    ids = re.findall(r'"(G\d+)"\s*:', match.group(1))
    assert len(ids) == len(set(ids)), f"{variant}: duplicate registry IDs"
    return sorted(ids, key=lambda gid: int(gid[1:]))


def qml_list_model(name, ids):
    elements = " ".join(f'ListElement {{ gid: "{gid}" }}' for gid in ids)
    return f"ListModel {{ id: {name}; {elements} }}"


def write_variant_fixture(variant, base, expected_width, ids, screenshot):
    source = ROOT / f"variants/{variant}/modules/VerticalBarContent.qml"
    qml = source.read_text()
    qml = qml.replace('import "../../../shared/components" as CommonComponents\n', "")
    qml = qml.replace(
        'import "../../../shared/logic/VerticalBarContentValuesLogic.js" as VerticalBarContentValuesLogic',
        'import "VerticalBarContentValuesLogic.js" as VerticalBarContentValuesLogic',
    )
    qml = qml.replace(
        'import "../../../shared/logic/VerticalBarContentLogic.js" as VerticalBarContentLogic',
        'import "VerticalBarContentLogic.js" as VerticalBarContentLogic',
    )
    qml = qml.replace("import Quickshell.Hyprland", 'import "."')
    if variant == "V2" and 'objectName: "vertical-module-surface"' not in qml:
        marker = chr(10).join([
            "                        Rectangle {",
            "                            anchors.horizontalCenter: parent.horizontalCenter",
            "                            width: Math.min(parent.width, loader.implicitWidth + 2 * rail.root.widgetSurfacePadding(cell.gid))",
        ])
        instrumented = marker.replace("                        Rectangle {", "                        Rectangle {" + chr(10) + '                            objectName: "vertical-module-surface"')
        assert marker in qml, "V2 module surface marker not found"
        qml = qml.replace(marker, instrumented, 1)
    (base / "VerticalBarContent.qml").write_text(qml)
    for logic in ["VerticalBarContentLogic.js", "VerticalBarContentValuesLogic.js"]:
        (base / logic).write_bytes((ROOT / "shared/logic" / logic).read_bytes())

    module_surface = '''
    Rectangle {
        objectName: "module-native-surface"
        x: 0
        y: 0
        width: stub.implicitWidth
        height: stub.implicitHeight
        radius: 5
        color: "#5a6372"
        border.width: 1
        border.color: "#94a3b8"
    }
''' if variant == "V1" else ""
    (base / "ModuleStub.qml").write_text('''import QtQuick
Item {
    id: stub
    property var root
    property var screen
    property real naturalWidth: 24
    implicitWidth: naturalWidth
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight
''' + module_surface + '''
}
''')
    workspace_surface = '''
    Rectangle { objectName: "module-native-surface"; width: parent.width; height: parent.height; radius: 5; color: "#5a6372"; border.width: 1 }
''' if variant == "V1" else ""
    (base / "WorkspaceWidget.qml").write_text('''import QtQuick
Item {
    property var root
    property var monitor
    implicitWidth: 32
    implicitHeight: 48
    width: implicitWidth
    height: implicitHeight
''' + workspace_surface + '''
}
''')
    stub_names = [
        "ArchUpdaterWidget", "TrayWidget", "NotificationWidget",
        "MediaBrowserWidget", "ThemeDisplayWidget", "WeatherWidget",
        "PillShadow", "ParticleStream",
    ]
    for name in stub_names:
        if name == "WeatherWidget":
            body = '''import QtQuick
Item { property var root; property bool weatherLoaded: true; property string weatherTempStr: "22°C"; implicitWidth: 32; implicitHeight: 20; width: implicitWidth; height: implicitHeight }
'''
        elif name == "PillShadow":
            body = 'import QtQuick\nItem { property var theme }\n'
        elif name == "ParticleStream":
            body = 'import QtQuick\nItem { property var theme; property var layout; property int mode; property bool active; property string monitor }\n'
        else:
            body = 'import QtQuick\nItem { property var root; property var screen; implicitWidth: 24; implicitHeight: 24; width: implicitWidth; height: implicitHeight }\n'
        (base / f"{name}.qml").write_text(body)

    (base / "VerticalBarContentLogic.js").write_bytes((ROOT / "shared/logic/VerticalBarContentLogic.js").read_bytes())
    (base / "VerticalBarContentValuesLogic.js").write_bytes((ROOT / "shared/logic/VerticalBarContentValuesLogic.js").read_bytes())
    write_hyprland_stub(base)

    groups = [ids[0::3], ids[1::3], ids[2::3]]
    module_components = []
    registry_entries = []
    for index, gid in enumerate(ids):
        component_id = f"module{gid}"
        natural_width = 24 if gid == "G1" else [16, 20, 30, 38, 44][index % 5]
        module_components.append(
            f'''Component {{ id: {component_id}; ModuleStub {{ root: harness.state; screen: owner.screen; naturalWidth: {natural_width} }} }}'''
        )
        registry_entries.append(f"{gid}: {component_id}")
    all_components = "\n ".join(module_components)
    registry = ", ".join(registry_entries)
    list_models = "\n ".join(
        qml_list_model(name, group) for name, group in zip(["top", "middle", "bottom"], groups)
    )
    style_cases = [{"style": "full", "padding": 0}] if variant == "V1" else [
        {"style": style, "padding": padding}
        for style in ["full", "fit", "dock", "notch"]
        for padding in [0, 3, 6]
    ]
    style_literal = json.dumps(style_cases)
    update_runs = "rail.updateRuns();" if variant == "V1" else ""
    width_expression = str(expected_width) if variant == "V1" else 'Math.min(34, 24 + 2 * widgetSurfacePadding("G1"))'
    shell = f'''import QtQuick
import QtQuick.Window
import Quickshell
import "."
ShellRoot {{
    id: harness
    property QtObject state: QtObject {{
        property string barPosition: "left"
        property string barShellStyle: "full"
        property bool barVertical: true
        property bool barUnlocked: false
        property bool layoutProtected: false
        property int controlCenterPadding: 0
        property int verticalModuleSurfaceWidth: {width_expression}
        property int verticalBarWidth: {"40" if variant == "V1" else 'barShellStyle === "fit" ? 40 : 36'}
        property int barAnim: 0
        property bool styleBorder: true
        property bool modStatus: true
        property bool modQuick: true
        property bool modWeather: true
        property bool modIndicators: true
        property bool clock12h: false
        property bool calendarVisible: false
        property bool weatherVisible: false
        property bool controlVisible: false
        property bool workspaceVisible: false
        property bool cpuVisible: false
        property bool memoryVisible: false
        property string activePopupScreenName: "fixture"
        property real panelInsetReveal: 0
        property var verticalAnchorsByScreen: ({{}})
        property int pillH: 24
        property int pillRadius: 8
        property int pillBorderW: 1
        property color pill: "#3a4150"
        property color pillBorder: "#94a3b8"
        property color pillShadow: "#000000"
        property color barBg: "#202630"
        property color islandBorder: "#94a3b8"
        property color v2BarBorder: "#94a3b8"
        property color ink: "#f0f0f0"
        property color seal: "#ff8800"
        property color sep: "#94a3b8"
        property color fillIdle: "#303744"
        property color sumi: "#c0c6d0"
        property int tileRadius: 6
        property string mono: "monospace"
        property string workspaceMode: "10"
        property string workspaceStyle: "numbers"
        property int panelButtonRadius: 6
        property int panelRadius: 6
        property int panelOuterBorderW: 1
        property color panelOuterBorderColor: "#94a3b8"
        property color bg: "#202630"
        property bool barBorderEnabled: true
        function sepAfter(gid) {{ return false }}
        function widgetSurfacePadding(gid) {{
            if (gid === "G1") return controlCenterPadding
            return [0, 3, 6][Number(String(gid).slice(1)) % 3]
        }}
        function widgetSurfaceRadius(gid) {{ return 6 }}
        function widgetFillColor(gid) {{ return "#5a6372" }}
        function widgetSurfaceStyle(gid) {{ return {{ opacity: 1, borderWidth: 1 }} }}
        function widgetHasBorder(gid) {{ return false }}
        function widgetBorderColor(gid) {{ return "#94a3b8" }}
        function widgetContentColor(gid, fallback) {{ return fallback }}
        function gotoWorkspace(id) {{}}
        function activatePopupScreen(screen) {{}}
        function publishVerticalAnchors(name, values) {{}}
        function publishBarAnchors(name, values) {{}}
        function verticalAnchorY(name) {{ return 700 }}
        function showTooltip(text, x, y, bottom, owner) {{}}
        function hideTooltip(owner) {{}}
    }}
    {list_models}
    QtObject {{
        id: owner
        property string screenName: "fixture"
        property var screen: ({{ width: 800, height: 1400 }})
        function swapVerticalSlots(sr, si, tr, ti) {{}}
    }}
    {all_components}
    Window {{
        id: window
        visible: true
        width: 96
        height: 1400
        color: "#11151b"
        VerticalBarContent {{
            id: rail
            x: 24
            width: harness.state.verticalBarWidth
            height: 1400
            root: harness.state
            barWindow: owner
            models: [top, middle, bottom]
            registry: ({{ {registry} }})
        }}
    }}
    property int phase: 0
    readonly property var checkedStyles: {style_literal}
    Timer {{
        interval: 500
        repeat: true
        running: true
        onTriggered: {{
            function check(ok, label) {{ if (!ok) {{ console.error("WIDTH_ASSERT_FAIL:" + label); Qt.exit(1) }} }}
            {update_runs}
            var cells = rail.layoutSnapshot()
            check(cells.length === {len(ids)}, "{variant}_all_registry_modules_visible_" + cells.length)
            var expected = harness.state.verticalModuleSurfaceWidth
            var surfaces = []
            var nativeSurfaces = []
            function visit(item) {{
                if (item.objectName === "vertical-run-surface" || item.objectName === "vertical-module-surface") surfaces.push(item)
                if (item.objectName === "module-native-surface") nativeSurfaces.push(item)
                for (var i = 0; i < item.children.length; i++) visit(item.children[i])
            }}
            visit(rail)
            if ("{variant}" === "V1") {{
                check(surfaces.length === {len(ids)}, "V1_run_count_" + surfaces.length)
                for (var i = 0; i < surfaces.length; i++) {{
                    check(Math.abs(surfaces[i].width - expected) < 0.01, "V1_run_width_" + surfaces[i].width)
                    check(Math.abs(surfaces[i].x + surfaces[i].width / 2 - rail.width / 2) < 0.51, "V1_run_center")
                }}
                check(nativeSurfaces.length >= {len(ids) - len(SPECIAL_IDS)}, "V1_native_surface_coverage_" + nativeSurfaces.length)
                for (var j = 0; j < nativeSurfaces.length; j++) {{
                    check(Math.abs(nativeSurfaces[j].width - expected) < 0.01, "V1_widget_surface_width_" + nativeSurfaces[j].width)
                    check(Math.abs(nativeSurfaces[j].x + nativeSurfaces[j].width / 2 - nativeSurfaces[j].parent.width / 2) < 0.51, "V1_widget_surface_center")
                }}
            }} else {{
                check(surfaces.length === {len(ids)}, "V2_surface_count_" + surfaces.length)
                for (var k = 0; k < surfaces.length; k++) {{
                    check(Math.abs(surfaces[k].width - expected) < 0.01, "V2_surface_width_" + surfaces[k].width + "_expected_" + expected + "_gid_" + surfaces[k].parent.gid)
                    check(Math.abs(surfaces[k].x + surfaces[k].width / 2 - surfaces[k].parent.width / 2) < 0.51, "V2_surface_center")
                }}
            }}
            harness.phase++
            if (harness.phase < harness.checkedStyles.length) {{
                var nextCase = harness.checkedStyles[harness.phase]
                harness.state.barShellStyle = nextCase.style
                harness.state.controlCenterPadding = nextCase.padding
                return
            }}
            window.contentItem.grabToImage(function(result) {{
                result.saveToFile({json.dumps(str(screenshot))})
                console.log("VERTICAL_WIDTH_PASS:{variant}:modules={len(ids)}:width=" + expected + ":cases=" + harness.checkedStyles.length)
                Qt.quit()
            }})
        }}
    }}
}}
'''
    (base / "shell.qml").write_text(shell)
    return style_cases


def main():
    # Measure the V2 Control Center's real compact vertical pill dimensions.
    launcher = (ROOT / "shared/components/LauncherWidget.qml").read_text()
    assert "readonly property real logoIconSlotWidth: 16" in launcher
    assert "readonly property real logoPadding: logoIconMode ? 8" in launcher
    assert "implicitWidth: logoContentWidth + logoPadding" in launcher
    assert "readonly property real logoContentWidth: logoIconMode ? logoIconSlotWidth" in launcher
    launcher_reference = 16 + 8
    assert REFERENCE_WIDTHS["V2"] == launcher_reference, "V2 Control Center reference changed; remeasure"

    scratch = Path(os.environ.get("TMPDIR", SCRATCH))
    assert scratch.is_dir(), f"TMPDIR must point to the profile scratch directory: {scratch}"
    short_alias = Path.home() / f".rise-vw-{os.getpid()}"
    assert not short_alias.exists() and not short_alias.is_symlink(), f"Refusing to replace existing path: {short_alias}"
    short_alias.symlink_to(scratch, target_is_directory=True)
    try:
        for variant, expected_width in REFERENCE_WIDTHS.items():
            ids = registry_ids(variant)
            assert len(ids) == 23, f"{variant}: registry count changed: {len(ids)}"
            with tempfile.TemporaryDirectory(prefix="r", dir=scratch) as directory:
                base = Path(directory)
                runtime = short_alias / base.name / "r"
                runtime.mkdir(mode=0o700)
                screenshot = ARTIFACTS / f"{variant}-vertical-module-widths.png"
                style_cases = write_variant_fixture(variant, base, expected_width, ids, screenshot)
                env = dict(
                    os.environ,
                    XDG_RUNTIME_DIR=str(runtime),
                    QT_QPA_PLATFORM="offscreen",
                    QT_QUICK_BACKEND="software",
                    QT_QPA_PLATFORMTHEME="",
                )
                env.pop("WAYLAND_DISPLAY", None)
                try:
                    result = subprocess.run(
                        ["qs", "-n", "-p", str(base / "shell.qml")],
                        env=env,
                        capture_output=True,
                        text=True,
                        timeout=30,
                    )
                except subprocess.TimeoutExpired as error:
                    stdout = error.stdout.decode(errors="replace") if isinstance(error.stdout, bytes) else error.stdout or ""
                    stderr = error.stderr.decode(errors="replace") if isinstance(error.stderr, bytes) else error.stderr or ""
                    raise AssertionError(f"{variant} QML fixture timed out\\n{stdout}\\n{stderr}") from error
                output = result.stdout + result.stderr
                print(output)
                assert result.returncode == 0 and f"VERTICAL_WIDTH_PASS:{variant}" in output, f"{variant} rendered width fixture failed"
                assert screenshot.is_file() and screenshot.stat().st_size > 0, f"{variant} render missing: {screenshot}"
                assert not re.search(r"ERROR qml:|ReferenceError|TypeError|WIDTH_ASSERT_FAIL", output), output
                surface_widths = sorted({min(34, 24 + 2 * case["padding"]) for case in style_cases}) if variant == "V2" else [expected_width]
                print(f"{variant}: rendered {len(ids)} modules; effective surface widths={', '.join(str(width) for width in surface_widths)}px across {len(style_cases)} style/padding cases; final screenshot width={surface_widths[-1]}px; screenshot={screenshot}")

        for variant, expected_width in REFERENCE_WIDTHS.items():
            theme_source = (ROOT / f"variants/{variant}/Theme.qml").read_text()
            layout_source = (ROOT / f"variants/{variant}/modules/VerticalBarContent.qml").read_text()
            assert "rail.root.verticalModuleSurfaceWidth" in layout_source, f"{variant}: layout does not consume shared width contract"
            if variant == "V1":
                assert "readonly property int verticalModuleSurfaceWidth: 32" in theme_source
                assert "readonly property int pillWidth: rail.root.verticalModuleSurfaceWidth" in layout_source
            else:
                expected_formula = 'readonly property int verticalModuleSurfaceWidth: Math.min(34, 24 + 2 * widgetSurfacePadding("G1"))'
                assert expected_formula in theme_source, "V2 width must follow the Control Center's persisted padding and available rail width"
                assert "width: Math.min(parent.width, rail.root.verticalModuleSurfaceWidth)" in layout_source
                assert 'objectName: "vertical-module-surface"' in layout_source
    finally:
        short_alias.unlink()

    print("VERTICAL_MODULE_WIDTH_RENDER_PASS")


if __name__ == "__main__":
    main()
