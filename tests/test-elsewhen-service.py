#!/usr/bin/env python3
"""Run the real Elsewhen QML service with isolated settings and inert commands."""
from pathlib import Path
import json
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
RUNNER = shutil.which("qs") or "/usr/bin/qs"
INITIAL_SETTINGS = {
    "schemaVersion": 1,
    "cities": [{"name": "Tokyo", "zone": "Asia/Tokyo"}],
    "hour24": False,
    "offsetMode": "home",
    "globeEnabled": True,
    "smoothMotion": True,
}

if not os.environ.get("WAYLAND_DISPLAY") or not os.environ.get("XDG_RUNTIME_DIR"):
    raise SystemExit("This Quickshell service fixture requires the current Wayland runtime")
SCRATCH.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="rise-elsewhen-service-", dir=SCRATCH) as directory:
    base = Path(directory)
    (base / "shared/services").mkdir(parents=True)
    service_source = ROOT / "shared/services/ElsewhenService.qml"
    if service_source.exists():
        shutil.copy2(service_source, base / "shared/services/ElsewhenService.qml")
    shutil.copytree(ROOT / "shared/integrations/elsewhen", base / "shared/integrations/elsewhen")
    shell = base / "shell.qml"
    shell_text = (ROOT / "tests/tst_elsewhen_service.qml").read_text(encoding="utf-8")
    shell.write_text(shell_text.replace('"../shared/services"', '"./shared/services"'), encoding="utf-8")
    settings = base / "settings.json"
    settings.write_text(json.dumps(INITIAL_SETTINGS), encoding="utf-8")
    env = dict(
        os.environ,
        RISE_ELSEWHEN_SETTINGS_PATH=str(settings),
        QT_QPA_PLATFORM="wayland",
        QT_QUICK_BACKEND="software",
        QT_QPA_PLATFORMTHEME="",
    )
    env.pop("DISPLAY", None)
    result = subprocess.run(
        [RUNNER, "-n", "-p", str(shell)],
        env=env,
        capture_output=True,
        text=True,
        timeout=20,
    )
    output = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout + result.stderr)
    print(output, end="")
    assert result.returncode == 0 and "ELSEWHEN_SERVICE_PASS" in output, output
    assert "ELSEWHEN_SERVICE_FAIL" not in output, output
    assert not re.search(r"(ReferenceError|TypeError|Cannot assign|is not a type)", output), output
    saved = json.loads(settings.read_text(encoding="utf-8"))
    assert saved["hour24"] is True, saved
    assert saved["cities"] == [{"name": "Paris", "zone": "Europe/Paris", "lat": 48.8566, "lon": 2.3522}], saved
    assert saved["schemaVersion"] == INITIAL_SETTINGS["schemaVersion"], saved

    reopen_shell = base / "reopen.qml"
    reopen_text = (ROOT / "tests/tst_elsewhen_reopen.qml").read_text(encoding="utf-8")
    reopen_shell.write_text(reopen_text.replace('"../shared/services"', '"./shared/services"'), encoding="utf-8")
    reopened = subprocess.run(
        [RUNNER, "-n", "-p", str(reopen_shell)],
        env=env,
        capture_output=True,
        text=True,
        timeout=20,
    )
    reopen_output = re.sub(r"\x1b\[[0-9;]*m", "", reopened.stdout + reopened.stderr)
    print(reopen_output, end="")
    assert reopened.returncode == 0 and "ELSEWHEN_REOPEN_PASS" in reopen_output, reopen_output
    assert "ELSEWHEN_REOPEN_FAIL" not in reopen_output, reopen_output
    assert not re.search(r"(ReferenceError|TypeError|Cannot assign|is not a type)", reopen_output), reopen_output

