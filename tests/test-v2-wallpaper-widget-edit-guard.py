#!/usr/bin/env python3
"""Ensure the vertical wallpaper widget cannot run actions while editing slots."""
from pathlib import Path
import os
import subprocess
import tempfile

from qml_fixture_source import copy_qml_fixture

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="v2-wallpaper-edit-guard-", dir=os.environ.get("TMPDIR")) as folder:
    base = Path(folder)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    copy_qml_fixture(repo / "variants/V2/modules/WallpaperManagerQuickWidget.qml", base)
    widget = base / "WallpaperManagerQuickWidget.qml"
    widget.write_text(
        widget.read_text()
        .replace('import "../../../shared/logic/WallpaperManagerQuickWidgetLogic.js" as WallpaperManagerQuickWidgetLogic',
                 'import "WallpaperManagerQuickWidgetLogic.js" as WallpaperManagerQuickWidgetLogic')
        .replace('import "../../../shared/components" as CommonComponents', 'import "." as CommonComponents')
    )
    copy_qml_fixture(repo / "shared/logic/WallpaperManagerQuickWidgetLogic.js", base)
    for name in ["IconText.qml", "TooltipMixin.qml"]:
        copy_qml_fixture(repo / "shared/components" / name, base)

    qml = base / "tst_wallpaper_widget_edit_guard.qml"
    qml.write_text(r'''import QtQuick
import QtTest
import "."

TestCase {
    name: "WallpaperWidgetEditGuard"
    when: windowShown

    Window {
        id: window
        visible: true
        width: 120
        height: 60
        color: "black"

        QtObject {
            id: service
            function nextAll() { root.actionCount++ }
        }
        QtObject {
            id: root
            property bool modWallpapers: true
            property bool barUnlocked: false
            property bool wallpaperManagerVisible: false
            property color widgetIconColor: "white"
            property color seal: "#ffff00"
            property int actionCount: 0
            property string wallpaperManagerFolder: ""
            property var wallpaperManagerServiceApi: service
            function widgetContentColor(gid, fallback) { return fallback }
            function widgetHasFill(gid) { return false }
            function toggleWallpaperManager(screen, owner) {
                wallpaperManagerVisible = !wallpaperManagerVisible
                actionCount++
            }
            function hideTooltip(owner) {}
            function showTooltip(text, x, topY, bottomY, owner) {}
        }
        WallpaperManagerQuickWidget {
            id: widget
            root: root
            x: 12
            y: 12
            width: 36
            height: 28
        }
    }

    function init() {
        root.barUnlocked = false
        root.wallpaperManagerVisible = false
        root.actionCount = 0
    }

    function clickWidget(button) {
        mouseClick(widget.testMouseArea, widget.width / 2, widget.height / 2,
                   button, Qt.NoModifier, 0)
        wait(20)
    }

    function test_locked_clicks_keep_existing_wallpaper_actions() {
        clickWidget(Qt.LeftButton)
        compare(root.wallpaperManagerVisible, true)
        compare(root.actionCount, 1)
        root.wallpaperManagerVisible = false
        root.actionCount = 0
        clickWidget(Qt.MiddleButton)
        compare(root.actionCount, 1)
    }

    function test_edit_mode_suppresses_wallpaper_actions() {
        root.barUnlocked = true
        clickWidget(Qt.LeftButton)
        clickWidget(Qt.MiddleButton)
        compare(root.wallpaperManagerVisible, false,
                "a slot-edit click must not open the wallpaper manager")
        compare(root.actionCount, 0,
                "a slot-edit click must not apply the next wallpaper")
    }
}
''')

    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen",
               QT_QUICK_BACKEND="software", QT_QPA_PLATFORMTHEME="")
    env.pop("WAYLAND_DISPLAY", None)
    env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(qml)],
                            env=env, text=True, capture_output=True, timeout=30)
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode:
        raise SystemExit(result.returncode)
    if "WallpaperWidgetEditGuard::test_edit_mode_suppresses_wallpaper_actions()" not in output:
        raise SystemExit("QtTest did not execute the wallpaper widget edit-mode regression")
