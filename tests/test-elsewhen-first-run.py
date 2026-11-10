#!/usr/bin/env python3
"""First-run regression: real Elsewhen service, missing temp preferences, no system actions."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRATCH = Path(os.environ.get("TMPDIR", "/tmp"))
RUNNER = shutil.which("qs") or "/usr/bin/qs"
if not os.environ.get("WAYLAND_DISPLAY") or not os.environ.get("XDG_RUNTIME_DIR"):
    raise SystemExit("This Quickshell fixture requires the current Wayland runtime")
SCRATCH.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="rise-ew-first-", dir=SCRATCH) as tmp:
    base = Path(tmp)
    (base / "shared/services").mkdir(parents=True)
    shutil.copy2(ROOT / "shared/services/ElsewhenService.qml", base / "shared/services/ElsewhenService.qml")
    shutil.copytree(ROOT / "shared/integrations/elsewhen", base / "shared/integrations/elsewhen")
    shell = base / "shell.qml"
    text = (ROOT / "tests/tst_elsewhen_first_run.qml").read_text(encoding="utf-8")
    shell.write_text(text.replace('"../shared/services"', '"./shared/services"'), encoding="utf-8")
    settings = base / "missing-parent" / "settings.json"
    settings.parent.mkdir()
    assert not settings.exists()
    env = dict(os.environ, RISE_ELSEWHEN_SETTINGS_PATH=str(settings), QT_QPA_PLATFORM="wayland",
               QT_QUICK_BACKEND="software", QT_QPA_PLATFORMTHEME="")
    env.pop("DISPLAY", None)
    result = subprocess.run([RUNNER, "-n", "-p", str(shell)], env=env,
                            capture_output=True, text=True, timeout=20)
    output = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout + result.stderr)
    print(output, end="")
    assert "ELSEWHEN_FIRST_RUN_PASS" in output and "ELSEWHEN_FIRST_RUN_FAIL" not in output, output
    assert settings.is_file(), "missing preferences were not initialized in the temporary directory"
    saved = json.loads(settings.read_text(encoding="utf-8"))
    assert any(city.get("zone") == "America/New_York" for city in saved.get("cities", [])), saved
