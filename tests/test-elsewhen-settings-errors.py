#!/usr/bin/env python3
"""Read/async-write errors of the real service, isolated to temporary files."""
from pathlib import Path
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

def run(shell, settings, invalid=False, missing_parent=False):
    env = dict(os.environ, RISE_ELSEWHEN_SETTINGS_PATH=str(settings), QT_QPA_PLATFORM="wayland",
               QT_QUICK_BACKEND="software", QT_QPA_PLATFORMTHEME="")
    if invalid:
        env["RISE_EXPECT_INVALID"] = "1"
    if missing_parent:
        env["RISE_EXPECT_MISSING_PARENT"] = "1"
    env.pop("DISPLAY", None)
    result = subprocess.run([RUNNER, "-n", "-p", str(shell)], env=env,
                            capture_output=True, text=True, timeout=20)
    output = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout + result.stderr)
    print(output, end="")
    assert result.returncode == 0, output
    assert "ELSEWHEN_SETTINGS_ERROR_FAIL" not in output, output
    return output

SCRATCH.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="rise-ew-errors-", dir=SCRATCH) as tmp:
    base = Path(tmp)
    (base / "shared/services").mkdir(parents=True)
    shutil.copy2(ROOT / "shared/services/ElsewhenService.qml", base / "shared/services/ElsewhenService.qml")
    shutil.copytree(ROOT / "shared/integrations/elsewhen", base / "shared/integrations/elsewhen")
    shell = base / "shell.qml"
    text = (ROOT / "tests/tst_elsewhen_settings_errors.qml").read_text(encoding="utf-8")
    shell.write_text(text.replace('"../shared/services"', '"./shared/services"'), encoding="utf-8")

    invalid_parent = base / "invalid"
    invalid_parent.mkdir()
    invalid = invalid_parent / "settings.json"
    original = b'{not valid json, user bytes kept exactly'
    invalid.write_bytes(original)
    assert "ELSEWHEN_INVALID_JSON_PASS" in run(shell, invalid, invalid=True)
    assert invalid.read_bytes() == original, "invalid file was overwritten during load"

    missing = base / "absent-parent" / "settings.json"
    assert not missing.parent.exists()
    assert "ELSEWHEN_MISSING_PARENT_PASS" in run(shell, missing, missing_parent=True)
    assert missing.is_file(), "first-run recovery did not create the missing parent/file in scratch"

    denied_parent = base / "denied"
    denied_parent.mkdir()
    denied_parent.chmod(0o555)
    denied = denied_parent / "settings.json"
    try:
        assert "ELSEWHEN_WRITE_FAILURE_PASS" in run(shell, denied)
        assert not denied.exists(), "write into read-only temp directory unexpectedly succeeded"
    finally:
        denied_parent.chmod(0o700)
