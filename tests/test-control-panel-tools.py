#!/usr/bin/env python3
"""Verify complete Health removal and the surviving native root contract."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
RUNNER = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"

health_symbols = (
    "control-panel-health-opener",
    "healthToolsTile",
    "healthCapabilities",
    "healthRows",
    "toolsOpen",
    "panelTools",
    "control-panel-tools-overlay",
    "ControlPanelTools",
    "ControlPanelCapabilities",
    'label: "Health"',
    "Read-only Control Panel health",
    'import "../../../shared/services" as CommonServices',
)
removed_files = (
    "shared/components/ControlPanelTools.qml",
    "shared/logic/ControlPanelCapabilities.js",
    "shared/services/ControlPanelCapabilities.qml",
    "tests/qml/tst_ControlPanelTools.qml",
    "tests/qml/tst_IndependentControlTools.qml",
    "tests/test-control-panel-tools-independent.py",
    "tests/control-panel-capabilities.test.mjs",
)

for variant in ("V1", "V2"):
    source = (ROOT / f"variants/{variant}/panels/ControlPanel.qml").read_text(encoding="utf-8")
    for symbol in health_symbols:
        assert symbol not in source, f"{variant} still exposes Health symbol {symbol!r}"
    assert "id: card" in source, f"{variant} ControlPanel card was removed"
    assert "SidePanelPositioner" in source, f"{variant} lost its panel positioner"

for path in removed_files:
    assert not (ROOT / path).exists(), f"{path} must be removed"

assert Path(RUNNER).is_file(), f"QtTest runner is required: {RUNNER}"
env = os.environ.copy()
env.pop("DISPLAY", None)
env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", QT_QPA_PLATFORMTHEME="")
native_root = subprocess.run(
    [RUNNER, "-input", str(ROOT / "tests/qml/tst_ControlPanelNativeRoot.qml")],
    cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
native_root_output = native_root.stdout + native_root.stderr
print(native_root_output, end="")
assert native_root.returncode == 0, f"native root notification QtTest exited {native_root.returncode}"
for diagnostic in ("ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign"):
    assert diagnostic not in native_root_output, f"unexpected QML diagnostic {diagnostic!r}"

native_composition = subprocess.run(
    [sys.executable, str(ROOT / "tests/test-control-panel-native-composition.py"), "--lint-generated"],
    cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
native_composition_output = native_composition.stdout + native_composition.stderr
print(native_composition_output, end="")
assert native_composition.returncode == 0, f"generated native fixture check exited {native_composition.returncode}"
print("ControlPanel Health removal and native root contract PASS")
