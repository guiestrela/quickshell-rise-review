#!/usr/bin/env python3
"""Render real V1/V2 Elsewhen panel adapters offscreen with inert services."""
from pathlib import Path
import json
import math
import os
import re
import shutil
import struct
import subprocess
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
SCRATCH = Path(os.environ.get("TMPDIR", Path.home() / ".cache/qsr"))
RUNNER = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"


def read_rgba_png(path):
    data = Path(path).read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise AssertionError(f"not a PNG: {path}")
    pos = 8
    width = height = bit_depth = color_type = None
    compressed = []
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, compression, filt, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if (bit_depth, color_type, compression, filt, interlace) != (8, 6, 0, 0, 0):
                raise AssertionError(f"unsupported PNG format: {path}")
        elif kind == b"IDAT":
            compressed.append(payload)
        elif kind == b"IEND":
            break
    if width is None or height is None:
        raise AssertionError(f"missing PNG dimensions: {path}")

    stride = width * 4
    raw = zlib.decompress(b"".join(compressed))
    rows = []
    previous = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        row = bytearray(raw[offset + 1:offset + 1 + stride])
        offset += stride + 1
        for i in range(stride):
            left = row[i - 4] if i >= 4 else 0
            above = previous[i]
            upper_left = previous[i - 4] if i >= 4 else 0
            if filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left + above) // 2
            elif filter_type == 4:
                base = left + above - upper_left
                distances = (abs(base - left), abs(base - above), abs(base - upper_left))
                predictor = (left, above, upper_left)[distances.index(min(distances))]
            elif filter_type == 0:
                predictor = 0
            else:
                raise AssertionError(f"unsupported PNG filter {filter_type}: {path}")
            row[i] = (row[i] + predictor) & 0xFF
        rows.append(row)
        previous = row
    return width, height, rows


def label_pixel_counts(path, baseline_path, probe):
    width, height, rows = read_rgba_png(path)
    base_width, base_height, baseline = read_rgba_png(baseline_path)
    if (width, height) != (base_width, base_height):
        raise AssertionError(f"label and no-label render sizes differ: {path}")
    x0 = max(0, math.floor(probe["x"]) - 1)
    y0 = max(0, math.floor(probe["y"]) - 1)
    x1 = min(width, math.ceil(probe["x"] + probe["w"]) + 1)
    y1 = min(height, math.ceil(probe["y"] + probe["h"]) + 1)
    if x1 <= x0 or y1 <= y0:
        raise AssertionError(f"empty label pixel box: {probe}")
    dark = light = changed_dark = changed_light = opaque = 0
    for y in range(y0, y1):
        row = rows[y]
        base_row = baseline[y]
        for x in range(x0, x1):
            r, g, b, a = row[x * 4:x * 4 + 4]
            br, bg, bb, ba = base_row[x * 4:x * 4 + 4]
            if a > 220:
                opaque += 1
                if r < 75 and g < 80 and b < 105:
                    dark += 1
                if r > 125 and g > 130 and b > 155:
                    light += 1
                baseline_land = br > 125 and bg > 130 and bb > 155
                baseline_sea = br < 75 and bg < 80 and bb < 105
                if ba > 220 and abs(r - br) + abs(g - bg) + abs(b - bb) >= 90:
                    if baseline_land and r < 75 and g < 80 and b < 105:
                        changed_dark += 1
                    if baseline_sea and r > 125 and g > 130 and b > 155:
                        changed_light += 1
    return {"dark": dark, "light": light, "changed_dark": changed_dark,
            "changed_light": changed_light, "opaque": opaque,
            "box": [x0, y0, x1 - x0, y1 - y0], "size": [width, height]}

SCRATCH.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="rise-elsewhen-adapters-", dir=SCRATCH) as directory:
    base = Path(directory)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)

    # Keep translation/notification calls in the composed adapters, but replace
    # only host I/O. qmltestrunner cannot register Quickshell's native services.
    commons = base / "qs/Commons"
    commons.mkdir(parents=True)
    (commons / "qmldir").write_text("module qs.Commons\nsingleton I18n 1.0 I18n.qml\nsingleton Style 1.0 Style.qml\nsingleton Color 1.0 Color.qml\n")
    (commons / "I18n.qml").write_text(
        'pragma Singleton\nimport QtQuick\nQtObject {\n'
        '  property string formatLocale: "en_US"\n'
        '  property var strings: ({})\n'
        '  function t(key, fallback) { return strings[key] || fallback || key + " %1 %2" }\n'
        '  function tn(key, count, fallback) { return t(key, fallback) }\n'
        '  function formatNumber(value, decimals) { return Number(value).toLocaleString(Qt.locale(formatLocale), "f", decimals === undefined ? 0 : decimals) }\n}\n'
    )
    (commons / "Style.qml").write_text(
        'pragma Singleton\nimport QtQuick\nQtObject {\n'
        '  property real testScale: 1\n'
        '  property int cornerRadius: 6\n'
        '  property string fontFamily: "monospace"\n'
        '  property var font: ({title:14 * testScale,caption:10 * testScale,body:12 * testScale,bodySmall:11 * testScale,display:24 * testScale,family:fontFamily})\n'
        '  property var spacing: ({inputPaddingY:7 * testScale})\n'
        '  function space(px) { return Math.round(px * testScale) }\n'
        '  property int normalBorderWidth: 1\n'
        '  function normalBorderFor(foreground, accent, urgent) { return Qt.rgba(foreground.r, foreground.g, foreground.b, 0.4) }\n'
        '  function duration(ms) { return ms }\n}\n'
    )
    (commons / "Color.qml").write_text(
        'pragma Singleton\nimport QtQuick\nQtObject {\n'
        '  readonly property color accent: "#7aa2f7"\n'
        '  readonly property color muted: "#565f89"\n'
        '  readonly property color urgent: "#f7768e"\n'
        '  readonly property color background: "#1a1b26"\n'
        '  readonly property QtObject popups: QtObject {\n'
        '    readonly property color background: "#1a1b26"\n'
        '    readonly property color text: "#a9b1d6"\n'
        '    readonly property color border: "#7aa2f7"\n'
        '  }\n'
        '  readonly property QtObject menu: QtObject {\n'
        '    readonly property color selectedBackground: "#24283b"\n'
        '  }\n'
        '}\n'
    )

    for subdir in ("components", "panels", "integrations/elsewhen"):
        source = ROOT / "shared" / subdir
        target = base / "shared" / subdir
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, target)

    for variant, modules in {
        "V1": ("PillShadow.qml", "SidePanelPositioner.qml"),
        "V2": ("PillShadow.qml", "SidePanelPositioner.qml", "ConnectedPanelSurface.qml", "AiPanelSurface.qml"),
    }.items():
        target_modules = base / "variants" / variant / "modules"
        target_panels = base / "variants" / variant / "panels"
        target_modules.mkdir(parents=True)
        target_panels.mkdir(parents=True)
        for name in modules:
            shutil.copy2(ROOT / "variants" / variant / "modules" / name, target_modules / name)
        shutil.copy2(ROOT / "variants" / variant / "panels/ElsewhenPanel.qml", target_panels / "ElsewhenPanel.qml")

    host = base / "shared/panels/ElsewhenPanel.qml"
    text = host.read_text()
    text = re.sub(r"^import Quickshell(?:\.[A-Za-z.]+)?\n", "", text, flags=re.M)
    notification_call = 'Quickshell.execDetached(["omarchy-notification-send", String(message)])'
    assert notification_call in text, "notification boundary changed; review fixture"
    text = text.replace(notification_call, 'panel.root.notify(String(message))')
    # The offscreen QtTest harness lacks Quickshell.Io; IPC is exercised separately.
    service_import = 'import "../services" as Services' + chr(10)
    text = text.replace(service_import, "")
    ipc_start = text.find("    Services.ElsewhenIpcHandler {")
    if ipc_start < 0:
        raise SystemExit("Elsewhen IPC child removal point is missing")
    ipc_end = text.index("    }", ipc_start) + len("    }")
    text = text[:ipc_start] + text[ipc_end:]
    text = text.replace(
        "PanelWindow {",
        "Rectangle {\n    width: parent ? parent.width : 800\n    height: parent ? parent.height : 800\n    property var screen\n",
        1,
    )
    text = re.sub(r"^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n", "", text, flags=re.M)
    host.write_text(text)
    test_source = (ROOT / "tests/tst_elsewhen_panel_adapters.qml").read_text()
    capture_dir = os.environ.get("RISE_ELSEWHEN_CAPTURE_DIR", "")
    if capture_dir:
        capture_dir = Path(capture_dir).expanduser().resolve()
        capture_dir.mkdir(parents=True, exist_ok=True)
        marker = '    property string captureDir: ""\n'
        if marker not in test_source:
            raise SystemExit("QML captureDir injection point is missing")
        test_source = test_source.replace(
            marker,
            "    property string captureDir: " + json.dumps(str(capture_dir)) + "\n",
            1,
        )
        city_marker = '        property var cityData: [["Paris", "Europe/Paris", 48.85, 2.35, 1], ["Tokyo", "Asia/Tokyo", 35.68, 139.69, 1]]\n'
        if city_marker not in test_source:
            raise SystemExit("QML fake city-data injection point is missing")
        city_data = json.loads((ROOT / "shared/integrations/elsewhen/cities.json").read_text())
        test_source = test_source.replace(
            city_marker,
            "        property var cityData: " + json.dumps(city_data, separators=(",", ":")) + "\n",
            1,
        )
        world_marker = "        property var worldData: [[-180, -80, 0, -80, 180, -80, 180, 80, 0, 80, -180, 80]]\n"
        if world_marker not in test_source:
            raise SystemExit("QML fake world-data injection point is missing")
        world_data = json.loads((ROOT / "shared/integrations/elsewhen/world.json").read_text())
        test_source = test_source.replace(
            world_marker,
            "        property var worldData: " + json.dumps(world_data, separators=(",", ":")) + "\n",
            1,
        )
    label_fault = os.environ.get("RISE_ELSEWHEN_TEST_LABEL_FAULT", "")
    if label_fault:
        if label_fault != "single-ink" or not capture_dir:
            raise SystemExit("label fault injection requires single-ink and a capture directory")
        content_qml = base / "shared/panels/ElsewhenPanelContent.qml"
        content_text = content_qml.read_text()
        land_paint = "paintLabels(panel.globeLandInk)"
        if land_paint not in content_text:
            raise SystemExit("isolated label fault injection point is missing")
        content_qml.write_text(content_text.replace(land_paint, "paintLabels(panel.globeSeaInk)", 1))
        print("TEST FAULT INJECTION: land labels forced to sea ink in the temporary harness")
    test_file = base / "tst_elsewhen_panel_adapters.qml"
    test_file.write_text(test_source)

    env = dict(
        os.environ,
        XDG_RUNTIME_DIR=str(runtime),
        QT_QPA_PLATFORM="offscreen",
        QT_QUICK_BACKEND="software",
        QT_QPA_PLATFORMTHEME="",
    )
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(
        [RUNNER, "-import", str(base), "-input", str(base / "tst_elsewhen_panel_adapters.qml")],
        env=env,
        capture_output=True,
        text=True,
        timeout=90,
    )
    output = result.stdout + result.stderr
    print(output, end="")
    assert result.returncode == 0, output
    totals = re.search(r"Totals: (\d+) passed, 0 failed, 0 skipped", output)
    assert totals, output
    assert int(totals.group(1)) == len(re.findall(r"^PASS\s*:", output, re.MULTILINE)), output
    assert not re.search(r"ERROR|ReferenceError|TypeError|Binding loop|Unable to assign", output), output
    if capture_dir:
        for name in (
            "v1-horizontal", "v1-vertical", "v2-horizontal", "v2-vertical",
            "v1-narrow-add-city-action", "v1-narrow-jump-city-action",
            "v1-vertical-add-city-action", "v1-vertical-jump-city-action",
            "v2-narrow-add-city-action", "v2-narrow-jump-city-action",
            "v2-vertical-add-city-action", "v2-vertical-jump-city-action",
            "v1-here-search", "v1-hover-greeting",
            "v1-six-city-add-visible", "v2-six-city-add-visible",
            "v1-six-city-add-search", "v2-six-city-add-search",
            "v1-full-list-add-city-visible", "v2-full-list-add-city-visible",
            "v1-full-list-add-city-search", "v2-full-list-add-city-search",
            "v2-elsewhen-connected-surface-open",
            "v2-expanded-globe", "v2-globe-jump-search", "v2-opening-spin", "v2-moon-show", "v2-moon-show-row",
            "v2-globe-label-land", "v2-globe-label-sea", "v2-globe-label-coast",
            "v2-globe-label-land-no-labels", "v2-globe-label-sea-no-labels", "v2-globe-label-coast-no-labels",
        ):
            image = capture_dir / f"{name}.png"
            assert image.is_file(), f"missing rendered capture: {image}"
            data = image.read_bytes()
            assert data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) > 128, image
            print(f"CAPTURED {image} ({len(data)} bytes)")
        probes = [json.loads(match) for match in re.findall(
            r"ELSEWHEN_LABEL_PROBE=(\{[^\r\n]*\})", output
        )]
        assert len(probes) == 3, f"expected three rendered label probes, got {probes}"
        counts = {}
        for probe in probes:
            image = capture_dir / f"{probe['image']}.png"
            baseline = capture_dir / f"{probe['baseline']}.png"
            counts[probe["kind"]] = label_pixel_counts(image, baseline, probe)
            print(f"LABEL PIXELS {probe['kind']} {probe['label']}: {counts[probe['kind']]}")
        assert counts["land"]["changed_dark"] >= 5, (
            "known land label has no dark glyph pixels over the light continent: "
            f"{counts['land']}"
        )
        assert counts["sea"]["changed_light"] >= 5, (
            "known sea label has no light glyph pixels over the dark ocean: "
            f"{counts['sea']}"
        )
        (capture_dir / "label-pixel-report.json").write_text(
            json.dumps({"probes": probes, "pixels": counts}, indent=2) + "\n"
        )
