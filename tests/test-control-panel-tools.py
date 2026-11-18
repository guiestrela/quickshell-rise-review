#!/usr/bin/env python3
"""Run isolated QtTest coverage and verify V1/V2 ControlPanel wiring."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
RUNNER = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"

for variant in ("V1", "V2"):
    source = (ROOT / f"variants/{variant}/panels/ControlPanel.qml").read_text(encoding="utf-8")
    assert f"variantName: \"{variant}\"" in source, f"{variant} ControlPanel is not wired to shared tools"
    assert "ControlPanelCapabilities" in source, f"{variant} has no host-capability facade"
    assert "hostRoot: ctrlPanel.root" in source, f"{variant} does not provide its local host root"
    assert "healthRows: healthCapabilities.healthRows" in source, f"{variant} does not render facade output"
    assert "onDestinationRequested: function(target)" in source, f"{variant} has no search destination route"
    assert "onCloseRequested:" in source, f"{variant} has no tools dismissal route"
    assert "focusReturnRoot: ctrlPanel.root" in source, f"{variant} tools cannot confirm parent visibility"
    assert "focusReturnTarget: ctrlPanel.toolsStartInHealth ? healthToolsTile : searchToolsTile" in source, f"{variant} does not restore focus to its opener"
    assert "healthSnapshot:" not in source, f"{variant} bypasses normalized host capabilities"

assert Path(RUNNER).is_file(), f"QtTest runner is required: {RUNNER}"
env = os.environ.copy()
env.pop("DISPLAY", None)
env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", QT_QPA_PLATFORMTHEME="")
command = [RUNNER, "-input", str(ROOT / "tests/qml/tst_ControlPanelTools.qml")]
result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
output = result.stdout + result.stderr
print(output, end="")
assert result.returncode == 0, f"ControlPanelTools component QtTest exited {result.returncode}"
for diagnostic in ("ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign"):
    assert diagnostic not in output, f"unexpected QML diagnostic {diagnostic!r}"

reactive_root = subprocess.run(
    [RUNNER, "-input", str(ROOT / "tests/qml/tst_ControlPanelNativeRoot.qml")],
    cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
reactive_root_output = reactive_root.stdout + reactive_root.stderr
print(reactive_root_output, end="")
assert reactive_root.returncode == 0, f"native harness root-notification QtTest exited {reactive_root.returncode}"
for diagnostic in ("ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign"):
    assert diagnostic not in reactive_root_output, f"unexpected QML diagnostic {diagnostic!r}"

native_fixture = subprocess.run(
    [sys.executable, str(ROOT / "tests/test-control-panel-native-composition.py"), "--lint-generated"],
    cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
native_fixture_output = native_fixture.stdout + native_fixture.stderr
print(native_fixture_output, end="")
assert native_fixture.returncode == 0, f"generated native fixture check exited {native_fixture.returncode}"

independent = subprocess.run(
    [sys.executable, str(ROOT / "tests/test-control-panel-tools-independent.py")],
    cwd=ROOT, env=env, capture_output=True, text=True, timeout=120)
independent_output = independent.stdout + independent.stderr
print(independent_output, end="")
assert independent.returncode == 0, f"independent ControlPanelTools QtTest exited {independent.returncode}"
print("Shared Search/Health component tests PASS; native V1/V2 ControlPanel composition remains a separate gate")
