#!/usr/bin/env python3
"""Run isolated QtTest coverage and verify V1/V2 ControlPanel wiring."""
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
RUNNER = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"

for variant in ("V1", "V2"):
    source = (ROOT / f"variants/{variant}/panels/ControlPanel.qml").read_text(encoding="utf-8")
    assert f"variantName: \"{variant}\"" in source, f"{variant} ControlPanel is not wired to shared tools"
    assert "onDestinationRequested: function(target)" in source, f"{variant} has no search destination route"
    assert "onCloseRequested:" in source, f"{variant} has no tools dismissal route"
    assert "healthSnapshot:" in source, f"{variant} has no read-only health snapshot"

assert Path(RUNNER).is_file(), f"QtTest runner is required: {RUNNER}"
env = os.environ.copy()
env.pop("DISPLAY", None)
env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", QT_QPA_PLATFORMTHEME="")
command = [RUNNER, "-input", str(ROOT / "tests/qml/tst_ControlPanelTools.qml")]
result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
output = result.stdout + result.stderr
print(output, end="")
assert result.returncode == 0, f"ControlPanelTools QtTest exited {result.returncode}"
for diagnostic in ("ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign"):
    assert diagnostic not in output, f"unexpected QML diagnostic {diagnostic!r}"
print("ControlPanel Search/Health V1/V2 integration PASS")
