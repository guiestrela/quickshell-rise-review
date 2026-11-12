#!/usr/bin/env python3
"""Render real V1/V2 Elsewhen panel adapters offscreen with inert services."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRATCH = Path(os.environ.get("TMPDIR", Path.home() / ".cache/qsr"))
RUNNER = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"

SCRATCH.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="rise-elsewhen-adapters-", dir=SCRATCH) as directory:
    base = Path(directory)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)

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
        world_marker = "        property var worldData: [[-180, -80, 0, -80, 180, -80, 180, 80, 0, 80, -180, 80]]\n"
        if world_marker not in test_source:
            raise SystemExit("QML fake world-data injection point is missing")
        world_data = json.loads((ROOT / "shared/integrations/elsewhen/world.json").read_text())
        test_source = test_source.replace(
            world_marker,
            "        property var worldData: " + json.dumps(world_data, separators=(",", ":")) + "\n",
            1,
        )
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
        [RUNNER, "-input", str(base / "tst_elsewhen_panel_adapters.qml")],
        env=env,
        capture_output=True,
        text=True,
        timeout=45,
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
            "v1-here-search", "v2-expanded-globe", "v2-globe-jump-search", "v2-moon-show",
        ):
            image = capture_dir / f"{name}.png"
            assert image.is_file(), f"missing rendered capture: {image}"
            data = image.read_bytes()
            assert data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) > 128, image
            print(f"CAPTURED {image} ({len(data)} bytes)")
