#!/usr/bin/env python3
"""Run the shared Elsewhen panel-content fixture offscreen with inert state."""
from pathlib import Path
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
RUNNER = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"

SCRATCH.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="rise-elsewhen-panel-content-", dir=SCRATCH) as directory:
    base = Path(directory)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    commons = base / "qs/Commons"
    commons.mkdir(parents=True)
    (commons / "qmldir").write_text(
        "module qs.Commons\nsingleton Style 1.0 Style.qml\nsingleton Color 1.0 Color.qml\n"
    )
    (commons / "Style.qml").write_text(
        'pragma Singleton\nimport QtQuick\nQtObject {\n'
        '  property int cornerRadius: 6\n'
        '  property string fontFamily: "monospace"\n'
        '  property var font: ({family:fontFamily,body:12,bodySmall:11,title:14,caption:10,display:24})\n'
        '  property var spacing: ({inputPaddingY:7})\n'
        '  property int normalBorderWidth: 1\n'
        '  function space(px) { return Math.round(px) }\n'
        '}\n'
    )
    (commons / "Color.qml").write_text(
        'pragma Singleton\nimport QtQuick\nQtObject {\n'
        '  readonly property color accent: "#7aa2f7"\n'
        '  readonly property color muted: "#565f89"\n'
        '  readonly property color background: "#1a1b26"\n'
        '  readonly property QtObject popups: QtObject {\n'
        '    readonly property color background: "#1a1b26"\n'
        '    readonly property color text: "#a9b1d6"\n'
        '    readonly property color border: "#7aa2f7"\n'
        '  }\n'
        '  readonly property QtObject menu: QtObject {\n'
        '    readonly property color selectedBackground: "#24283b"\n'
        '  }\n'
        '}\n'
    )
    env = dict(
        os.environ,
        XDG_RUNTIME_DIR=str(runtime),
        QT_QPA_PLATFORM="offscreen",
        QT_QUICK_BACKEND="software",
        QT_QPA_PLATFORMTHEME="",
    )
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(
        [RUNNER, "-import", str(base), "-input", str(ROOT / "tests/tst_elsewhen_panel_content.qml")],
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )
    output = result.stdout + result.stderr
    print(output, end="")
    assert result.returncode == 0, output
    totals = re.search(r"Totals: (\d+) passed, 0 failed, 0 skipped", output)
    assert totals, output
    assert int(totals.group(1)) == len(re.findall(r"^PASS\s*:", output, re.MULTILINE)), output
    assert not re.search(r"ERROR|ReferenceError|TypeError|Binding loop|Unable to assign|Incorrect argument radius", output), output
