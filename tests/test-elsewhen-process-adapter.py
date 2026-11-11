#!/usr/bin/env python3
"""Exercise the real Elsewhen Process adapter with an inert executable."""
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
HELPER_SOURCE = '''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
action = sys.argv[1]
args = sys.argv[2:]
with Path(os.environ["RISE_ELSEWHEN_COMMAND_LOG"]).open("a", encoding="utf-8") as log:
    log.write(json.dumps({"action": action, "args": args}) + "\\n")
if action == "probe":
    print("LOCAL|Etc/UTC\\nEtc/UTC|UTC|+0000\\nAsia/Tokyo|JST|+0900")
elif action == "probe-fail":
    print("fixture denied probe", file=sys.stderr)
    sys.exit(5)
elif action == "catalog":
    print("America/New_York\\nEurope/Paris\\nAsia/Tokyo")
elif action == "catalog-fail":
    print("fixture denied catalog", file=sys.stderr)
    sys.exit(6)
elif action == "geocode" and args == ["springfield"]:
    print(json.dumps({"results": [{"name": "Springfield", "admin1": "Illinois", "country_code": "US", "timezone": "America/Chicago", "latitude": 39.78, "longitude": -89.64}]}))
elif action == "geocode-slow":
    import time
    time.sleep(0.25)
    print(json.dumps({"results": [{"name": "Boston", "admin1": "Massachusetts", "country_code": "US", "timezone": "America/New_York", "latitude": 42.36, "longitude": -71.06}]}))
elif action == "geocode-latest":
    import time
    time.sleep(0.5)
    print(json.dumps({"results": [{"name": "Chicago", "admin1": "Illinois", "country_code": "US", "timezone": "America/Chicago", "latitude": 41.88, "longitude": -87.63}]}))
elif action == "geocode-fail":
    print("fixture denied geocode", file=sys.stderr)
    sys.exit(7)
elif action == "timezone" and args == ["Europe/Paris"]:
    print("fixture accepted requested zone")
elif action == "timezone":
    print("fixture denied requested zone", file=sys.stderr)
    sys.exit(3)
else:
    print("unexpected inert helper action", file=sys.stderr)
    sys.exit(4)
'''

if not os.environ.get("WAYLAND_DISPLAY") or not os.environ.get("XDG_RUNTIME_DIR"):
    raise SystemExit("This Quickshell process fixture requires the current Wayland runtime")
SCRATCH.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="rise-elsewhen-process-", dir=SCRATCH) as directory:
    base = Path(directory)
    services = base / "shared/services"
    services.mkdir(parents=True)
    for name in ("ElsewhenService.qml", "ElsewhenProcessAdapter.qml"):
        source = ROOT / "shared/services" / name
        if source.exists():
            shutil.copy2(source, services / name)
    components = base / "shared/components"
    components.mkdir(parents=True)
    shutil.copy2(ROOT / "shared/components/UiText.qml", components / "UiText.qml")
    panels = base / "shared/panels"
    panels.mkdir(parents=True)
    shutil.copy2(ROOT / "shared/panels/ElsewhenPanelContent.qml", panels / "ElsewhenPanelContent.qml")
    shutil.copytree(ROOT / "shared/integrations/elsewhen", base / "shared/integrations/elsewhen")
    shell = base / "shell.qml"
    shell_text = (ROOT / "tests/tst_elsewhen_process_adapter.qml").read_text(encoding="utf-8")
    shell_text = shell_text.replace('"../shared/services"', '"./shared/services"')
    shell_text = shell_text.replace('"../shared/panels"', '"./shared/panels"')
    shell.write_text(shell_text, encoding="utf-8")
    settings = base / "settings.json"
    settings.write_text(json.dumps(INITIAL_SETTINGS), encoding="utf-8")
    helper = base / "inert-helper"
    helper.write_text(HELPER_SOURCE, encoding="utf-8")
    helper.chmod(0o700)
    command_log = base / "commands.jsonl"
    env = dict(
        os.environ,
        RISE_ELSEWHEN_SETTINGS_PATH=str(settings),
        RISE_ELSEWHEN_TEST_HELPER=str(helper),
        RISE_ELSEWHEN_COMMAND_LOG=str(command_log),
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
    assert result.returncode == 0 and "ELSEWHEN_ADAPTER_PASS" in output, output
    assert "ELSEWHEN_ADAPTER_FAIL" not in output, output
    assert not re.search(r"(ReferenceError|TypeError|Cannot assign|is not a type)", output), output
    events = [json.loads(line) for line in command_log.read_text(encoding="utf-8").splitlines()]
    assert len(events) == 10, events
    assert {event["action"] for event in events} == {
        "catalog", "catalog-fail", "geocode", "geocode-fail", "geocode-slow",
        "geocode-latest", "probe", "probe-fail", "timezone"
    }, events
    assert sum(event["action"] == "probe" for event in events) == 1, events
    assert sum(event["action"] == "probe-fail" for event in events) == 1, events
    assert sum(event["action"] == "catalog" for event in events) == 1, events
    assert sum(event["action"] == "catalog-fail" for event in events) == 1, events
    assert sum(event["action"] == "geocode" for event in events) == 1, events
    assert sum(event["action"] == "geocode-fail" for event in events) == 1, events
    assert sum(event["action"] == "geocode-slow" for event in events) == 1, events
    assert sum(event["action"] == "geocode-latest" for event in events) == 1, events
    assert [event["args"] for event in events if event["action"].startswith("geocode")] == [
        ["springfield"], ["nowhere"], ["boston"], ["chicago"]
    ], events
    assert any(event["action"] == "probe" and "Asia/Tokyo" in event["args"] for event in events), events
    print("ELSEWHEN_ADAPTER_PASS inert command log verified")
