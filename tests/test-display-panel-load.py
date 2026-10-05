#!/usr/bin/env python3
"""Hidden production-panel regression; no monitor actions or live bar changes.

Copies exact production bytes below the fixture config root because Quickshell
blocks imports outside that root. V2 imports this same panel; variant wiring is
checked separately by qr-display-contract.mjs. This does not test live controls.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
SOURCE = REPO / "versions/V1/panels/DisplayManagerPanel.qml"
HARNESS = REPO / "versions/V1/tests/qr-display-panel-runtime.qml"
env = dict(os.environ, QT_QPA_PLATFORM="wayland")
env.pop("DISPLAY", None)
if not env.get("XDG_RUNTIME_DIR") or not env.get("WAYLAND_DISPLAY"):
    raise SystemExit("BLOCKED: real Wayland runtime is required for PanelWindow")
with tempfile.TemporaryDirectory(prefix="display-panel-load-", dir=os.environ["TMPDIR"]) as work:
    folder = Path(work)
    (folder / "panels").mkdir()
    (folder / "panels/DisplayManagerPanel.qml").write_bytes(SOURCE.read_bytes())
    fixture = HARNESS.read_text().replace('import "../panels"', 'import "panels"')
    fixture = fixture.replace('property color bg: "#202020"', 'property color bg: "#202020"\n property color paper: "#202020"\n property color fillHover: "#404040"')
    fixture = fixture.replace("fakeRoot.displayManagerVisible = true", "fakeRoot.displayManagerVisible = false")
    fixture = fixture.replace("if (fakeController.refreshCount !== 1)", "if (productionPanel.visible || fakeController.refreshCount !== 0)")
    fixture = fixture.replace("DISPLAY_PANEL_INSTANCE_PASS refresh=", "DISPLAY_PANEL_HIDDEN_LOAD_PASS refresh=")
    (folder / "shell.qml").write_text(fixture)
    result = subprocess.run(["qs", "-n", "-p", str(folder / "shell.qml")], env=env,
                            capture_output=True, text=True, timeout=15)
    output = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout + result.stderr)
    print(output)
    assert result.returncode == 0, f"runtime exit={result.returncode}"
    assert "DISPLAY_PANEL_INSTANCE_CREATED" in output, "production instance not created"
    assert "DISPLAY_PANEL_HIDDEN_LOAD_PASS refresh=0" in output, "hidden instance assertion missing"
    assert not any(marker in output for marker in ("ERROR:", "ReferenceError", "TypeError")), "QML runtime error"
print("DISPLAY_PANEL_LOAD_REGRESSION_PASS (shared V1/V2 panel; hidden only)")
