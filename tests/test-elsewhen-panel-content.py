#!/usr/bin/env python3
"""Run the shared Elsewhen panel-content fixture offscreen with inert state."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRATCH = Path(os.environ.get(
    "TMPDIR",
    Path.home() / ".hermes/profiles/desktop-dev/cache/scratch",
))
RUNNER = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"

SCRATCH.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="rise-elsewhen-panel-content-", dir=SCRATCH) as directory:
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
        [RUNNER, "-input", str(ROOT / "tests/tst_elsewhen_panel_content.qml")],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
    )
    output = result.stdout + result.stderr
    print(output, end="")
    assert result.returncode == 0, output
    totals = re.search(r"Totals: (\d+) passed, 0 failed, 0 skipped", output)
    assert totals, output
    assert int(totals.group(1)) == len(re.findall(r"^PASS\s*:", output, re.MULTILINE)), output
    assert not re.search(r"ERROR|ReferenceError|TypeError|Binding loop|Unable to assign|Incorrect argument radius", output), output
