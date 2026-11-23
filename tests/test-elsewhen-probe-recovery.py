#!/usr/bin/env python3
"""Native, offline Elsewhen startup tests with delayed real process wiring."""
from pathlib import Path
from contextlib import ExitStack
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import Quickshell
import "shared/services" as Services
Scope {
    id: test
    property string scenario: __SCENARIO__
    property var adapter: null
    property int phase: 0
    property int ticks: 0
    property bool hangProbe: false
    property int expiredSerial: 0
    Services.ElsewhenService {
        id: clockService
        settingsPath: __SETTINGS__
        autoRefresh: test.scenario !== "probe-timeout"
    }
    Component { id: adapterFactory; Services.ElsewhenProcessAdapter {} }
    function attach() {
        adapter = adapterFactory.createObject(null, {service: clockService,
            commandFactory: {
                probe: function(ids) { return [__PYTHON__, __HELPER__, test.hangProbe ? "hang" : "probe"].concat(ids) },
                catalog: function() { return [__PYTHON__, __HELPER__, "catalog"] }
            }})
        if (!adapter) fail("adapter construction failed")
    }
    function fail(reason) { console.error("RECOVERY_FAIL", scenario, reason); Qt.quit() }
    Timer {
        interval: 20; repeat: true; running: true
        onTriggered: {
            test.ticks++
            if (test.ticks > 100) {
                test.fail("pending=" + clockService.probeRunning + ", ready="
                    + clockService.clockRows[0].ready + ", error=" + clockService.lastError)
                return
            }
            if (test.phase === 0 && clockService.settingsReady) {
                if (test.scenario === "probe-timeout") {
                    test.attach()
                    if (clockService.probeTimeoutMs !== undefined) clockService.probeTimeoutMs = 80
                    test.hangProbe = true
                    clockService.active = true
                    clockService.refresh()
                    test.expiredSerial = clockService.requestSerial
                    test.phase = 3
                    return
                }
                if (test.scenario === "connected-first") test.attach()
                clockService.active = true
                test.phase = test.scenario === "connected-first" ? 2 : 1
            } else if (test.phase === 1 && test.ticks >= 8) {
                if (!clockService.probeRunning) {
                    test.fail("fixture did not reproduce a request before adapter attachment")
                    return
                }
                // A manual refresh must not leave the lost request queued forever.
                clockService.refresh()
                test.attach()
                test.phase = 2
            } else if (test.phase === 3 && !clockService.probeRunning) {
                if (clockService.lastError.indexOf("timed out") < 0
                        || clockService.acceptProbe("Etc/UTC|UTC|+0000", 0, test.expiredSerial, "")) {
                    test.fail("timeout did not invalidate the old request")
                    return
                }
                test.hangProbe = false
                clockService.refresh()
                test.phase = 4
            } else if (test.phase === 4 && !clockService.probeRunning && clockService.clockRows[0].ready) {
                if (clockService.lastError !== "") { test.fail(clockService.lastError); return }
                console.log("RECOVERY_PASS", test.scenario)
                Qt.quit()
            } else if (test.phase === 2 && !clockService.probeRunning
                    && clockService.clockRows[0].ready && !clockService.catalogRunning) {
                if (clockService.zoneCatalogText.indexOf("Asia/Tokyo") < 0
                        || clockService.lastError !== "") {
                    test.fail("catalog or probe did not recover")
                    return
                }
                console.log("RECOVERY_PASS", test.scenario)
                Qt.quit()
            }
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix="elsewhen-recovery-", dir=os.environ.get("TMPDIR")) as tmp, ExitStack() as cleanup:
        base = Path(tmp)
        for rel in ("shared/services/ElsewhenService.qml", "shared/services/ElsewhenProcessAdapter.qml",
                    "shared/integrations/elsewhen/Model.js", "shared/integrations/elsewhen/world.json",
                    "shared/integrations/elsewhen/cities.json"):
            target = base / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / rel, target)
        settings = base / "settings.json"
        saved = {"schemaVersion": 1, "cities": [{"name": "Tokyo", "zone": "Asia/Tokyo"}]}
        settings.write_text(json.dumps(saved))
        original = settings.read_bytes()
        helper = base / "helper.py"
        helper.write_text('import sys, time\n'
                          'if sys.argv[1] == "hang": time.sleep(5); sys.exit(0)\n'
                          'if sys.argv[1] == "catalog": print("Etc/UTC\\nAsia/Tokyo")\n'
                          'else: print("LOCAL|Etc/UTC\\nEtc/UTC|UTC|+0000\\nAsia/Tokyo|JST|+0900")\n')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                   QT_QPA_PLATFORMTHEME="", QT_FORCE_STDERR_LOGGING="1")
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE"):
            env.pop(name, None)
        for name in ("HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "XDG_RUNTIME_DIR"):
            directory = base / name
            directory.mkdir(mode=0o700)
            env[name] = str(directory)
        alias = Path(os.environ["XDG_RUNTIME_DIR"]) / ("er-" + uuid.uuid4().hex[:6])
        alias.symlink_to(base / "XDG_RUNTIME_DIR", target_is_directory=True)
        cleanup.callback(alias.unlink)
        env["XDG_RUNTIME_DIR"] = str(alias)
        for scenario in ("late-adapter", "connected-first", "probe-timeout"):
            source = QML
            for token, value in {"__SCENARIO__": scenario, "__SETTINGS__": str(settings),
                                 "__PYTHON__": sys.executable, "__HELPER__": str(helper)}.items():
                source = source.replace(token, json.dumps(value))
            shell = base / "shell.qml"
            shell.write_text(source)
            result = subprocess.run(["quickshell", "-n", "-p", str(shell)],
                                    env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            # A short owned alias points only into this private fixture runtime.
            assert result.returncode == 0 and "RECOVERY_PASS " + scenario in output, output
            assert not re.search(r"\bERROR\b|RECOVERY_FAIL|ReferenceError|TypeError|Unable to assign|Binding loop|Invalid assignment", output), output
            assert settings.read_bytes() == original, "Recovery modified city preferences"
            print("PASS", scenario)


if __name__ == "__main__":
    main()
