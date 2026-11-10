#!/usr/bin/env python3
"""Render real V1/V2 Elsewhen panel adapters offscreen with inert services."""
from pathlib import Path
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
    shutil.copy2(ROOT / "tests/tst_elsewhen_panel_adapters.qml", base / "tst_elsewhen_panel_adapters.qml")

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
    assert "Totals: 6 passed, 0 failed" in output, output
    assert not re.search(r"ERROR|ReferenceError|TypeError|Binding loop|Unable to assign", output), output
