#!/usr/bin/env python3
"""Exercise the production Elsewhen popup-routing function offscreen."""
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
with tempfile.TemporaryDirectory(prefix="rise-elsewhen-theme-", dir=SCRATCH) as directory:
    runtime = Path(directory) / "runtime"
    runtime.mkdir(mode=0o700)
    env = dict(
        os.environ,
        XDG_RUNTIME_DIR=str(runtime),
        QT_QPA_PLATFORM="offscreen",
        QT_QUICK_BACKEND="software",
        QT_QPA_PLATFORMTHEME="",
    )
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(
        [RUNNER, "-input", str(ROOT / "tests/tst_elsewhen_theme_panels.qml")],
        env=env,
        capture_output=True,
        text=True,
        timeout=20,
    )
    output = result.stdout + result.stderr
    print(output, end="")
    assert result.returncode == 0, output
    assert "Totals: 4 passed, 0 failed" in output, output
    assert not re.search(r"ERROR|ReferenceError|TypeError|Binding loop|Unable to assign", output), output
