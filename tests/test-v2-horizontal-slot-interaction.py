#!/usr/bin/env python3
"""Exercise production V1/V2 horizontal drag handlers with inert models."""
from pathlib import Path
import os
import subprocess
import tempfile

from qml_fixture_source import copy_qml_fixture

repo = Path(__file__).resolve().parents[1]
variant = os.environ.get("RISE_HORIZONTAL_VARIANT", "V2").upper()
if variant not in {"V1", "V2"}:
    raise SystemExit(f"Unsupported horizontal slot variant: {variant}")
source = (repo / f"variants/{variant}/BarSlot.qml").read_text()

def extract_block(text, start):
    opening = text.index("{", start)
    depth = 1
    pos = opening + 1
    quote = None
    escaped = False
    while depth:
        char = text[pos]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        pos += 1
    return text[start:pos]

start = source.index("    property bool dragging:")
end = source.index("    // ── order persistence", start)
drag_block = source[start:end]
vertical_loader_marker = "    Loader {\n        id: verticalLoader"
if vertical_loader_marker in drag_block:
    vertical_loader_start = drag_block.index(vertical_loader_marker)
    vertical_loader = extract_block(drag_block, vertical_loader_start)
    drag_block = drag_block[:vertical_loader_start] + drag_block[vertical_loader_start + len(vertical_loader):]
catcher_marker = source.index("// ── drag-catcher: only in unlock mode, overlays the widget ──")
mouse_start = source.index("                MouseArea {", catcher_marker)
mouse_area = extract_block(source, mouse_start)

with tempfile.TemporaryDirectory(prefix="v2-horizontal-pointer-", dir=os.environ.get("TMPDIR")) as folder:
    base = Path(folder)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    copy_qml_fixture(repo / "shared/logic/NordVpnLayout.js", base)

    qml = r'''pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtTest
import "NordVpnLayout.js" as NordVpnLayout

Item {
    id: window
    width: 1300
    height: 140

    QtObject {
        id: state
        property bool barVertical: false
        property bool barUnlocked: true
        property bool layoutProtected: false
        property bool trayDragActive: false
        property bool trayDropActive: false
        property bool trayVisible: false
        property var trayDropRectsByScreen: ({})
    }

    ListModel { id: leftModel
        ListElement { gid: "G1" } ListElement { gid: "G2" } ListElement { gid: "G3" }
        ListElement { gid: "G4" } ListElement { gid: "G5" } ListElement { gid: "G6" }
        ListElement { gid: "G7" } ListElement { gid: "G8" } ListElement { gid: "G9" }
        ListElement { gid: "G10" }
    }
    ListModel { id: centerModel; ListElement { gid: "G11" } }
    ListModel { id: rightModel
        ListElement { gid: "G12" } ListElement { gid: "G13" } ListElement { gid: "G14" }
        ListElement { gid: "G15" } ListElement { gid: "G16" } ListElement { gid: "G17" }
        ListElement { gid: "G18" }
    }

    Item {
        id: barSlot
        anchors.fill: parent
        property var root: state
        property string screenName: "fixture"
        property color accent: "#ff8800"
        property bool _orderLoaded: true
        property int orderSaveCalls: 0
        function saveOrder() { orderSaveCalls++ }
        function moveSlotToTray(model, index) { return false }
        QtObject { id: verticalLoader; property var item: null }
        DRAG_BLOCK
    }

    QtObject {
        id: leftRowItem
        property var rmodel: leftModel
        property var rep: ({ count: 10, itemAt: function(index) { return index < 10 ? leftSlot : null } })
    }
    QtObject {
        id: centerRowItem
        property var rmodel: centerModel
        property var rep: ({ count: 1, itemAt: function(index) { return index === 0 ? centerSlot : null } })
    }
    QtObject {
        id: rightRowItem
        property var rmodel: rightModel
        property var rep: ({ count: 7, itemAt: function(index) { return index < 7 ? rightSlot : null } })
    }

    Component { id: widget; Item { implicitWidth: 48; implicitHeight: 32 } }
    component HorizontalCell: Item {
        id: slot
        property var rmodel
        property int index: 0
        property string gid: ""
        property bool occupied: true
        property bool hasContent: true
        property bool autoShown: true
        width: 90
        height: 40
        Loader {
            id: ldr
            anchors.fill: parent
            sourceComponent: widget
        }
        MOUSE_AREA
    }

    HorizontalCell {
        id: leftSlot
        x: 30; y: 40
        rmodel: leftModel
        index: 0
        gid: "G1"
    }
    HorizontalCell {
        id: centerSlot
        x: 600; y: 100
        rmodel: centerModel
        index: 0
        gid: "G11"
    }

    HorizontalCell {
        id: rightSlot
        x: 1160; y: 40
        rmodel: rightModel
        index: 0
        gid: "G12"
    }

    TestCase {
        name: "HORIZONTAL_SLOT_POINTER_TEST"
        when: windowShown
        function test_drag_between_horizontal_regions() {
            wait(50)
            var from = leftSlot.mapToItem(window, leftSlot.width / 2, leftSlot.height / 2)
            var to = rightSlot.mapToItem(window, rightSlot.width / 2, rightSlot.height / 2)
            mousePress(window, from.x, from.y, Qt.LeftButton)
            compare(barSlot.srcModel, leftModel)
            compare(barSlot.srcIndex, 0)
            verify(barSlot.dragging)
            mouseMove(window, to.x, to.y, 40)
            compare(barSlot.dropModel, rightModel)
            compare(barSlot.dropIndex, 0)
            compare(barSlot.orderSaveCalls, 0, "pointer movement does not persist order before release")
            mouseRelease(window, to.x, to.y, Qt.LeftButton)
            compare(leftModel.get(0).gid, "G12")
            compare(rightModel.get(0).gid, "G1")
            compare(centerModel.get(0).gid, "G11")
            compare(barSlot.orderSaveCalls, 1)
            verify(!barSlot.dragging)
            verify(!state.trayDragActive)
            verify(!state.trayDropActive)
        }
    }
}
'''.replace("DRAG_BLOCK", drag_block).replace("MOUSE_AREA", mouse_area).replace(
    "HORIZONTAL_SLOT_POINTER_TEST", f"{variant}HorizontalSlotPointer")
    probe = base / "tst_horizontal_slots.qml"
    probe.write_text(qml)
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
               QT_QPA_PLATFORMTHEME="", XDG_RUNTIME_DIR=str(runtime))
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(probe)],
                            env=env, text=True, capture_output=True, timeout=30)
    output = result.stdout + result.stderr
    print(output, end="")
    assert result.returncode == 0, result.returncode
    assert not any(token in output for token in
                   ["ReferenceError", "TypeError", "Binding loop", "Unable to assign"])
