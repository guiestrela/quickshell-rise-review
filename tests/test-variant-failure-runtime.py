#!/usr/bin/env python3
"""Exercise real VariantHost timers with inert variants and no shell services."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
runner = shutil.which('qmltestrunner') or '/usr/lib/qt6/bin/qmltestrunner'
with tempfile.TemporaryDirectory(prefix='rise-variant-failure-', dir='/tmp') as directory:
    temp = Path(directory)
    shutil.copy2(repo / 'versions/V1/core/VariantHost.qml', temp / 'VariantHost.qml')
    (temp / 'Variant.qml').write_text('''import QtQuick
Item {
    required property var variantHost
    readonly property string variantId: variantHost.targetVariant
    property bool ready: false
}
''')
    (temp / 'tst_failure.qml').write_text('''import QtQuick
import QtTest
Item {
    QtObject {
        id: state
        property bool initialized: true
        property string committedVariant: "v1"
        signal commitSucceeded(string variant)
        signal commitFailed(string variant)
        function commit(variant) { committedVariant = variant; commitSucceeded(variant) }
    }
    VariantHost {
        id: controller
        stateService: state
        v1Source: Qt.resolvedUrl("Variant.qml")
        v2Source: Qt.resolvedUrl("Variant.qml")
    }
    SignalSpy { id: failures; target: controller; signalName: "switchFailed" }
    TestCase {
        name: "VariantFailure"
        when: windowShown
        function test_failure_stops_and_can_recover() {
            tryCompare(controller, "phase", "waiting-ready")
            // Advance the counter, leaving the production timers and callbacks intact.
            controller.readyTicks = 49
            tryCompare(controller, "phase", "rollback-ready")
            controller.readyTicks = 49
            tryCompare(controller, "phase", "failed")
            compare(failures.count, 1)
            var finalTicks = controller.readyTicks
            wait(650)
            compare(failures.count, 1, "terminal failure must be emitted once")
            compare(controller.readyTicks, finalTicks, "readiness polling must stop")
            controller.requestSwitch("v1")
            tryCompare(controller, "phase", "waiting-ready")
            controller.activeItem.ready = true
            tryCompare(controller, "ready", true, 4000)
            compare(controller.runningVariant, "v1")
            compare(failures.count, 1)
        }
    }
}
''')
    runtime = temp / 'runtime'
    runtime.mkdir(mode=0o700)
    env = os.environ.copy()
    env.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               QT_QPA_PLATFORMTHEME='', XDG_RUNTIME_DIR=str(runtime))
    result = subprocess.run([runner, '-input', str(temp / 'tst_failure.qml')],
                            env=env, text=True, capture_output=True, timeout=15)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode:
        raise SystemExit(result.returncode)
    assert not any(error in output for error in ['ReferenceError', 'TypeError', 'Binding loop'])
