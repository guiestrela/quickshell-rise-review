#!/usr/bin/env python3
"""Exercise Wi-Fi scan ownership with inert fake NetworkManager devices."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RUNNER = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"
assert Path(RUNNER).is_file(), f"QtTest runner is required: {RUNNER}"

with tempfile.TemporaryDirectory(prefix="rise-wifi-lease-", dir=os.environ.get("TMPDIR")) as directory:
    fixture = Path(directory)
    service = (ROOT / "shared/services/NetworkManagerAdapter.qml").read_text(encoding="utf-8")
    service = service.replace("import Quickshell.Networking\n", "")
    service = service.replace(
        "import Quickshell.Io\n",
        'import "." as Fake\nimport "FakeTypes.js" as FakeTypes\n',
    )
    service = service.replace("Networking.", "Fake.Networking.")
    service = service.replace("DeviceType.Wifi", "FakeTypes.Wifi")
    service = service.replace("NetworkBackendType.NetworkManager", "FakeTypes.NetworkManager")
    for name in ("Portal", "Limited", "Full", "None"):
        service = service.replace(f"NetworkConnectivity.{name}", f"FakeTypes.{name}")
    for name in (
        "Open", "WpaPsk", "Wpa2Psk", "Sae", "Owe", "StaticWep", "DynamicWep",
        "Wpa2Eap", "WpaEap", "Wpa3SuiteB192", "Leap",
    ):
        service = service.replace(f"WifiSecurityType.{name}", f"FakeTypes.{name}")
    assert "Quickshell.Networking" not in service and "Quickshell.Io" not in service
    assert "Fake.Networking" in service
    (fixture / "NetworkManagerAdapter.qml").write_text(service, encoding="utf-8")
    (fixture / "qmldir").write_text(
        "module RiseWifiLeaseFixture\n"
        "singleton Networking 1.0 Networking.qml\n"
        "NetworkManagerAdapter 1.0 NetworkManagerAdapter.qml\n"
        "Process 1.0 Process.qml\n"
        "StdioCollector 1.0 StdioCollector.qml\n",
        encoding="utf-8",
    )
    (fixture / "FakeTypes.js").write_text("""var Wifi = 1
var NetworkManager = 1
var Portal = 1
var Limited = 2
var Full = 3
var None = 4
var Open = 10
var WpaPsk = 11
var Wpa2Psk = 12
var Sae = 13
var Owe = 14
var StaticWep = 15
var DynamicWep = 16
var Wpa2Eap = 17
var WpaEap = 18
var Wpa3SuiteB192 = 19
var Leap = 20
""", encoding="utf-8")
    (fixture / "Networking.qml").write_text("""pragma Singleton
import QtQuick
QtObject {
    property int backend: 1
    property bool canCheckConnectivity: false
    property bool connectivityCheckEnabled: false
    property int connectivity: 0
    property bool wifiEnabled: true
    property var devices: ({ values: [] })
}
""", encoding="utf-8")
    (fixture / "Process.qml").write_text("""import QtQuick
QtObject {
    property var command: []
    property bool running: false
    property var stdout: null
    property var stderr: null
    signal exited(int exitCode, int exitStatus)
    signal started()
}
""", encoding="utf-8")
    (fixture / "StdioCollector.qml").write_text("""import QtQuick
QtObject {
    property string text: ""
    property bool waitForEnd: false
    signal streamFinished()
}
""", encoding="utf-8")
    qml = fixture / "tst_NetworkManagerAdapterLifecycle.qml"
    qml.write_text(
        (ROOT / "tests/qml/tst_NetworkManagerAdapterLifecycle.qml").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    runtime = fixture / "runtime"
    runtime.mkdir(mode=0o700)
    env = os.environ.copy()
    for key in ("DISPLAY", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "DBUS_SYSTEM_BUS_ADDRESS"):
        env.pop(key, None)
    env.update(
        QT_QPA_PLATFORM="offscreen",
        QT_QUICK_BACKEND="software",
        QT_QPA_PLATFORMTHEME="",
        XDG_RUNTIME_DIR=str(runtime),
    )
    command = [RUNNER, "-input", str(qml)]
    result = subprocess.run(command, cwd=fixture, env=env, capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    print(output, end="")
    assert result.returncode == 0, f"inert NetworkManager scan lifecycle QtTest exited {result.returncode}"
    for diagnostic in ("ReferenceError", "TypeError", "Binding loop", "Unable to assign"):
        assert diagnostic not in output, f"unexpected QML diagnostic {diagnostic!r}"
print("Wi-Fi scan lease lifecycle PASS (inert devices; no NetworkManager service)")
