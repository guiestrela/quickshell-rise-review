#!/usr/bin/env python3
"""Ensure hidden horizontal slot repeaters are not instantiated vertically."""
from pathlib import Path
import os
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

models = {}
for variant in ("V1", "V2"):
    source = (ROOT / f"variants/{variant}/BarSlot.qml").read_text()
    component = source.index("component SlotRow: Row")
    repeater_start = source.index("Repeater {", component)
    repeater = source[repeater_start:repeater_start + 500]
    match = re.search(r"(?m)^\s*model:\s*([^\n]+)", repeater)
    if not match:
        raise SystemExit(f"Could not find production SlotRow Repeater model in {variant}")
    models[variant] = match.group(1).strip()

qml = r'''pragma ComponentBehavior: Bound
import QtQuick
import QtTest

Item {
    width: 240
    height: 120
    QtObject { id: state; property bool barVertical: false }
    QtObject { id: barSlot; property var root: state }
    ListModel {
        id: sourceModel
        ListElement { gid: "G1" }
        ListElement { gid: "G2" }
        ListElement { gid: "G3" }
        ListElement { gid: "G4" }
        ListElement { gid: "G5" }
    }
    component V1SlotRowFixture: Item {
        property var rmodel
        property alias repeater: repeater
        Repeater { id: repeater; model: MODEL_V1; delegate: Item { width: 8; height: 8 } }
    }
    component V2SlotRowFixture: Item {
        property var rmodel
        property alias repeater: repeater
        Repeater { id: repeater; model: MODEL_V2; delegate: Item { width: 8; height: 8 } }
    }
    V1SlotRowFixture { id: v1Row; rmodel: sourceModel }
    V2SlotRowFixture { id: v2Row; rmodel: sourceModel; y: 20 }
    TestCase {
        name: "VerticalRepeaterActivity"
        when: windowShown
        function test_horizontal_models_and_vertical_pruning() {
            verify(v1Row.repeater.count === 5, "V1 horizontal row keeps all configured cells")
            verify(v2Row.repeater.count === 5, "V2 horizontal row keeps all configured cells")
            state.barVertical = true
            wait(20)
            verify(v1Row.repeater.count === 0, "V1 horizontal delegates are removed in vertical mode")
            verify(v2Row.repeater.count === 0, "V2 horizontal delegates are removed in vertical mode")
            state.barVertical = false
            wait(20)
            verify(v1Row.repeater.count === 5, "V1 horizontal delegates return unchanged")
            verify(v2Row.repeater.count === 5, "V2 horizontal delegates return unchanged")
        }
    }
}
'''.replace("MODEL_V1", models["V1"]).replace("MODEL_V2", models["V2"])

scratch = Path(os.environ.get("TMPDIR", "/tmp"))
scratch.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="bar-orientation-", dir=scratch) as folder:
    base = Path(folder)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    fixture = base / "tst_vertical_repeater_activity.qml"
    fixture.write_text(qml)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen",
               QT_QUICK_BACKEND="software", QT_QPA_PLATFORMTHEME="")
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(fixture)],
                            env=env, text=True, capture_output=True, timeout=30)
    output = result.stdout + result.stderr
    print(output, end="")
    assert result.returncode == 0, output
    assert "Totals: 3 passed, 0 failed" in output, output
    assert not re.search(r"ERROR|ReferenceError|TypeError|Binding loop|Unable to assign", output), output
