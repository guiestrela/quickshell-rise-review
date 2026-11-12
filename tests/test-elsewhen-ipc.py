#!/usr/bin/env python3
"""Exercise the Elsewhen IPC target against an isolated Rise service fixture."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SCRATCH = Path(os.environ.get(
    "TMPDIR",
    Path.home() / ".hermes/profiles/desktop-dev/cache/scratch",
))
RUNNER = shutil.which("qs") or "/usr/bin/qs"
TARGET = "quickshell-rise.elsewhen"
PRODUCTION_PANEL = (ROOT / "shared/panels/ElsewhenPanel.qml").read_text(encoding="utf-8")
for integration in (
    'import "../services" as Services',
    "Services.ElsewhenIpcHandler {",
    "service: panel.service",
    "owner: panel.root",
    "content: body",
):
    assert integration in PRODUCTION_PANEL, f"production panel IPC wiring missing: {integration}"
INITIAL_SETTINGS = {
    "schemaVersion": 1,
    "cities": [
        {"name": "Paris", "zone": "Europe/Paris"},
        {"name": "Tokyo", "zone": "Asia/Tokyo"},
    ],
    "hour24": False,
    "offsetMode": "home",
    "globeEnabled": True,
    "smoothMotion": True,
}

if not os.environ.get("WAYLAND_DISPLAY") or not os.environ.get("XDG_RUNTIME_DIR"):
    raise SystemExit("This Quickshell IPC fixture requires the current Wayland runtime")

SCRATCH.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="rise-elsewhen-ipc-", dir=SCRATCH) as directory:
    base = Path(directory)
    services = base / "shared/services"
    services.mkdir(parents=True)
    for name in ("ElsewhenService.qml", "ElsewhenIpcHandler.qml"):
        source = ROOT / "shared/services" / name
        if source.exists():
            shutil.copy2(source, services / name)
    shutil.copytree(
        ROOT / "shared/integrations/elsewhen",
        base / "shared/integrations/elsewhen",
    )
    shell = base / "shell.qml"
    source = ROOT / "tests/tst_elsewhen_ipc.qml"
    shell_text = source.read_text(encoding="utf-8")
    shell_text = shell_text.replace('"../shared/services"', '"./shared/services"')
    shell.write_text(shell_text, encoding="utf-8")

    settings = base / "settings.json"
    settings.write_text(json.dumps(INITIAL_SETTINGS), encoding="utf-8")
    state_path = base / "ipc-state.json"
    state_path.write_text("{}", encoding="utf-8")
    env = dict(
        os.environ,
        RISE_ELSEWHEN_SETTINGS_PATH=str(settings),
        RISE_ELSEWHEN_IPC_STATE_PATH=str(state_path),
        QT_QPA_PLATFORM="wayland",
        QT_QUICK_BACKEND="software",
        QT_QPA_PLATFORMTHEME="",
    )
    env.pop("DISPLAY", None)
    process = subprocess.Popen(
        [RUNNER, "-n", "-p", str(shell)],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=True,
    )

    def output_on_failure():
        if process.poll() is None:
            process.terminate()
        try:
            return process.communicate(timeout=3)[0]
        except subprocess.TimeoutExpired:
            process.kill()
            return process.communicate(timeout=3)[0]

    def run_ipc(*args):
        command = [RUNNER, "ipc", "--pid", str(process.pid), "call", *args]
        result = subprocess.run(
            command,
            env=env,
            capture_output=True,
            text=True,
            timeout=5,
        )
        assert result.returncode == 0, (command, result.stdout, result.stderr)
        return result.stdout.strip()

    def read_state():
        try:
            value = json.loads(state_path.read_text(encoding="utf-8"))
            return value if isinstance(value, dict) else {}
        except (OSError, json.JSONDecodeError):
            return {}

    def wait_state(predicate, message, timeout=5):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            value = read_state()
            if predicate(value):
                return value
            if process.poll() is not None:
                break
            time.sleep(0.05)
        raise AssertionError(message + "\n" + json.dumps(read_state(), indent=2) + "\n" + output_on_failure())

    try:
        deadline = time.monotonic() + 10
        targets = ""
        while time.monotonic() < deadline and process.poll() is None:
            probe = subprocess.run(
                [RUNNER, "ipc", "--pid", str(process.pid), "show"],
                env=env,
                capture_output=True,
                text=True,
                timeout=2,
            )
            targets = probe.stdout + probe.stderr
            if TARGET in targets:
                break
            time.sleep(0.1)
        assert TARGET in targets, "Elsewhen IPC target was not registered:\n" + targets + "\n" + output_on_failure()
        assert "omarchy.elsewhen" not in targets, "Rise must not reuse Omarchy's IPC target"
        assert "function show()" not in targets, "`show` collides with the qs ipc show subcommand"
        methods = ("open", "close", "hide", "toggle", "refresh", "globe", "times", "add", "remove", "who", "here")
        for method in methods:
            assert f"function {method}(" in targets, f"missing IPC method: {method}\n{targets}"
        wait_state(lambda s: s.get("ready") is True, "service fixture did not become ready")

        run_ipc(TARGET, "open")
        state = wait_state(lambda s: s.get("visible") is True, "open did not show the panel")
        assert state.get("focusActivations") == 1, state
        run_ipc(TARGET, "close")
        wait_state(lambda s: s.get("visible") is False, "close did not hide the panel")
        run_ipc(TARGET, "open")
        state = wait_state(lambda s: s.get("visible") is True, "open did not show the panel")
        assert state.get("focusActivations") == 2, state
        run_ipc(TARGET, "hide")
        wait_state(lambda s: s.get("visible") is False, "hide did not hide the panel")
        run_ipc(TARGET, "toggle")
        state = wait_state(lambda s: s.get("visible") is True, "toggle did not open the panel")
        assert state.get("focusActivations") == 3, state
        run_ipc(TARGET, "toggle")
        state = wait_state(lambda s: s.get("visible") is False, "second toggle did not close the panel")
        assert state.get("focusActivations") == 3, state

        assert run_ipc(TARGET, "globe") == "globe"
        wait_state(lambda s: s.get("globeExpanded") is True, "globe did not expand")
        assert run_ipc(TARGET, "globe") == "list"
        wait_state(lambda s: s.get("globeExpanded") is False, "globe did not collapse")
        assert run_ipc("fixture.elsewhen", "disableGlobe") == "ok"
        assert run_ipc(TARGET, "globe") == "disabled"
        assert run_ipc("fixture.elsewhen", "enableGlobe") == "ok"

        assert run_ipc(TARGET, "refresh") == "ok"
        wait_state(lambda s: s.get("probeRequests") == 1, "refresh did not reach the service fixture")
        times = json.loads(run_ipc(TARGET, "times"))
        assert len(times) == 2 and {row["id"] for row in times} == {"Europe/Paris", "Asia/Tokyo"}, times

        added = run_ipc(TARGET, "add", "America/New_York", "New York")
        assert "New York|America/New_York" in added, added
        wait_state(lambda s: len(s.get("cities", [])) == 3, "add did not persist a new city")
        assert json.loads(run_ipc(TARGET, "who", "pARiS", "Emir, @octocat")) == ["Emir", "@octocat"]
        state = wait_state(
            lambda s: len(s.get("cities", [])) == 3 and s["cities"][0].get("people") == ["Emir", "@octocat"],
            "who did not update the case-insensitive city match",
        )
        assert run_ipc(TARGET, "who", "No Such City", "Nobody") == "no city named No Such City"
        assert run_ipc(TARGET, "here", "Springfield") == "Springfield"
        state = wait_state(
            lambda s: s.get("preferences", {}).get("here") == {"name": "Springfield", "zone": "Etc/UTC"},
            "here did not persist the local city override",
        )
        assert run_ipc(TARGET, "remove", "Asia/Tokyo").find("Asia/Tokyo") == -1
        wait_state(
            lambda s: len(s.get("cities", [])) == 2
            and all(city.get("zone") != "Asia/Tokyo" for city in s.get("cities", [])),
            "remove did not delete the requested time zone",
        )
        assert run_ipc("fixture.elsewhen", "clearLocalZone") == "ok"
        assert run_ipc(TARGET, "here", "Unknown") == "zone not known yet"
        print("ELSEWHEN_IPC_PASS 11 callable methods exercised through quickshell-rise.elsewhen")
    finally:
        if process.poll() is None:
            process.terminate()
        try:
            process.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate(timeout=3)
