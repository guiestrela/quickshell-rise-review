#!/usr/bin/env python3
"""Compose V1/V2 ControlPanel focus-return checks on Wayland.

By default this gate requires an isolated Wayland runtime supplied through
RISE_TEST_PRIVATE_XDG_RUNTIME_DIR and RISE_TEST_PRIVATE_WAYLAND_DISPLAY, beneath
profile TMPDIR. The only exception is an explicit --allow-active-session opt-in
for authorized inert fixtures; it identifies the live session truthfully and
never changes the strict private-runtime default.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
from typing import NoReturn

ROOT = Path(__file__).resolve().parents[1]
PARSER = argparse.ArgumentParser(description=__doc__)
PARSER.add_argument("--lint-generated", action="store_true", help="lint the generated test shell without a Wayland runtime")
PARSER.add_argument("--allow-active-session", action="store_true",
                    help="run inert panel fixtures on the explicitly identified current Wayland session")
ARGS = PARSER.parse_args()
SCRATCH = os.environ.get("TMPDIR")
if ARGS.allow_active_session:
    RUNTIME_VALUE = os.environ.get("XDG_RUNTIME_DIR", "")
    DISPLAY = os.environ.get("WAYLAND_DISPLAY", "")
else:
    RUNTIME_VALUE = os.environ.get("RISE_TEST_PRIVATE_XDG_RUNTIME_DIR", "")
    DISPLAY = os.environ.get("RISE_TEST_PRIVATE_WAYLAND_DISPLAY", "")


def blocked(reason: str) -> NoReturn:
    print("NATIVE_COMPOSITION_BLOCKED: " + reason)
    raise SystemExit(77)


if not SCRATCH or not Path(SCRATCH).is_dir():
    blocked("TMPDIR must point to the profile scratch directory")

scratch = Path(SCRATCH).resolve()
runtime = None
if not ARGS.lint_generated:
    if ARGS.allow_active_session:
        if (os.environ.get("RISE_TEST_PRIVATE_XDG_RUNTIME_DIR")
                or os.environ.get("RISE_TEST_PRIVATE_WAYLAND_DISPLAY")):
            blocked("active-session opt-in must not use private-runtime overrides")
        if not RUNTIME_VALUE or not DISPLAY:
            blocked("active-session opt-in requires the current XDG_RUNTIME_DIR and WAYLAND_DISPLAY")
        runtime = Path(RUNTIME_VALUE).resolve()
        current_runtime = Path(os.environ["XDG_RUNTIME_DIR"]).resolve()
        current_display = os.environ["WAYLAND_DISPLAY"]
        if runtime != current_runtime or DISPLAY != current_display:
            blocked("active-session identity must match the explicitly supplied current session")
        if Path(DISPLAY).name != DISPLAY or DISPLAY in (".", ".."):
            blocked("active Wayland display must be the current socket basename")
        if not runtime.is_dir():
            blocked("current XDG_RUNTIME_DIR does not exist")
        runtime_stat = runtime.stat()
        if runtime_stat.st_uid != os.getuid() or stat.S_IMODE(runtime_stat.st_mode) & 0o077:
            blocked("current XDG_RUNTIME_DIR must be owned by this user and inaccessible to group/other")
        socket_path = runtime / DISPLAY
        if not socket_path.is_socket() or socket_path.stat().st_uid != os.getuid():
            blocked("the explicitly named current Wayland socket is absent or not owned by this user")
        print(f"ACTIVE_SESSION_TEST_AUTHORIZED: runtime={runtime} display={DISPLAY} uid={os.getuid()}; inert fixtures only")
    else:
        if not RUNTIME_VALUE or not DISPLAY:
            blocked("provide RISE_TEST_PRIVATE_XDG_RUNTIME_DIR and RISE_TEST_PRIVATE_WAYLAND_DISPLAY; ambient session fallback is forbidden")
        if DISPLAY == os.environ.get("WAYLAND_DISPLAY"):
            blocked("the requested display matches ambient WAYLAND_DISPLAY; live-session use is forbidden")
        if Path(DISPLAY).name != DISPLAY or DISPLAY in (".", ".."):
            blocked("private display must be a socket basename inside its runtime directory")
        runtime = Path(RUNTIME_VALUE).resolve()
        try:
            runtime.relative_to(scratch)
        except ValueError:
            blocked("private XDG_RUNTIME_DIR must be beneath profile TMPDIR")
        if not runtime.is_dir():
            blocked("private XDG_RUNTIME_DIR does not exist")
        runtime_stat = runtime.stat()
        if runtime_stat.st_uid != os.getuid() or stat.S_IMODE(runtime_stat.st_mode) & 0o077:
            blocked("private runtime must be owned by this user and inaccessible to group/other")
        ipc_probe = runtime / "quickshell" / "by-id" / "12345678" / "ipc.sock"
        if len(os.fsencode(ipc_probe)) >= 108:
            blocked("private runtime makes Quickshell's IPC path too long; use a verified short alias backed by profile TMPDIR")
        socket_path = runtime / DISPLAY
        if not socket_path.is_socket():
            blocked("private Wayland socket is absent; no compositor was started by this gate")

QS = shutil.which("qs") or ""
if not ARGS.lint_generated and not QS:
    blocked("Quickshell executable 'qs' is unavailable")

sources = [ROOT / "variants/V1/panels/ControlPanel.qml", ROOT / "variants/V2/panels/ControlPanel.qml"]
texts = [path.read_text(encoding="utf-8") for path in sources]
root_names = sorted(set().union(*(
    set(re.findall(r"ctrlPanel\.root\.([A-Za-z_][A-Za-z0-9_]*)", text))
    for text in texts
)) | {"activePopupScreenName", "hasBattery", "hasBacklight", "networkMode"})
method_names = sorted(set().union(*(
    set(re.findall(r"ctrlPanel\.root\.([A-Za-z_][A-Za-z0-9_]*)\s*\(", text))
    for text in texts
)))
# These nested native adapters consume the same ControlPanel root through
# PillShadow, BarStylePreview, SidePanelPositioner, and ConnectedPanelSurface.
# Keep their complete inert API explicit rather than guessing from direct
# ctrlPanel.root references only.
root_names = sorted(set(root_names) | {
    "barVertical", "verticalBarWidth", "verticalAnchorY", "setPanelInsetX",
    "panelInsetX", "panelInsetReady", "paper", "ink", "seal", "pillShadow",
    "styleShadow",
})
method_names = sorted(set(method_names) | {"verticalAnchorY", "setPanelInsetX"})


def qml_value(name):
    if name == "activePopupScreenName":
        return "Quickshell.screens.length ? Quickshell.screens[0].name : ''"
    if name == "activePopupScreen":
        return "Quickshell.screens.length ? Quickshell.screens[0] : null"
    if name == "variantHost":
        return "({ runningVariant: variant.toLowerCase(), switching: false })"
    if name == "controlVisible":
        return "false"
    if name == "launcherBarX":
        return "Quickshell.screens.length ? Quickshell.screens[0].width / 2 : 400"
    if name == "evenW":
        return "function(value) { return Math.max(1, Math.round(value)); }"
    if name == "launcherLogoLabel":
        return "function(value) { return String(value || 'Rise'); }"
    if name in {"paletteColor", "paletteContrastColor", "widgetAssignedColor"}:
        return "function() { return '#404040'; }"
    if name == "verticalAnchorY":
        return "function(anchorName) { return 180; }"
    if name == "setPanelInsetX":
        return "function(value) { if (isFinite(value) && value > 0) { inertRoot.panelInsetX = value; inertRoot.panelInsetReady = true; } }"
    if name in method_names:
        return "function() { return false; }"
    if name == "networkMode":
        return "'wifi'"
    if name == "barPosition":
        return "'top'"
    if name.endswith("Options"):
        return "[]"
    if name == "verticalBarWidth":
        return "36"
    if name == "panelInsetX":
        return "0"
    if name in {"bg", "barColor", "paper", "ink", "seal", "pillShadow", "fillActive", "fillHover", "fillIdle", "sep", "sumi", "sumiHi", "pillBorder", "styleBorder", "panelOuterBorderColor"}:
        return "'#404040'"
    if name.endswith("Alpha"):
        return "0.15"
    if name.endswith(("Radius", "Height", "Width", "BarX", "BorderW", "Size", "X")) or name in {"v2BarHeight", "panelOuterBorderW"}:
        return "8"
    if name.startswith(("has", "mod", "compact", "widgetHas")) or name in {
        "barUnlocked", "layoutProtected", "styleFrost", "barFrost", "spacerDotsEnabled",
        "panelTooltipBorderEnabled", "barVertical", "styleShadow", "panelInsetReady"
    }:
        return "false"
    if name == "launcherLogoText":
        return "'Rise'"
    if name == "launcherLogoIcon":
        return "'R'"
    if name in {"barShellStyle", "mprisBarStyle", "pickerStyle", "workspaceMode", "workspaceStyle", "launcherLogoMode"}:
        return "'default'"
    return "''"


def qml_type(name):
    return {
        "controlVisible": "bool", "barVertical": "bool", "styleShadow": "bool",
        "panelInsetReady": "bool", "verticalBarWidth": "int", "panelInsetX": "real",
        "paper": "color", "ink": "color", "seal": "color", "pillShadow": "color",
    }.get(name, "var")


root_fields = ["id: inertRoot", 'property string variant: "V1"'] + [
    f"property {qml_type(name)} {name}: {qml_value(name)}"
    for name in root_names
]
qml_root = chr(10).join("            " + field for field in root_fields)
source_urls = {name: json.dumps(sources[index].as_uri()) for index, name in enumerate(("V1", "V2"))}

NATIVE_FAILURE_PATTERNS = (
    re.compile(r"\b(?:ReferenceError|TypeError)\b"),
    re.compile(r"\bInvalid\s+assignment\b", re.IGNORECASE),
    re.compile(r"\bUnable\s+to\s+assign\b", re.IGNORECASE),
    re.compile(r"\bBinding\s+loop\s+detected\b", re.IGNORECASE),
    re.compile(r"\b(?:Could not|Unable to) evaluate (?:the )?binding\b", re.IGNORECASE),
    re.compile(r"\bCannot\s+(?:assign|read|set)\b", re.IGNORECASE),
    re.compile(r"\bis not a function\b", re.IGNORECASE),
    re.compile(r"no signal of the target matches the name", re.IGNORECASE),
)


def native_runtime_errors(output):
    return [line.strip() for line in output.splitlines()
            if any(pattern.search(line) for pattern in NATIVE_FAILURE_PATTERNS)]


def read_native_log(output, runtime):
    match = re.search(r"Saving logs to [\"']([^\"']+)[\"']", output)
    if not match:
        return "", None, "Quickshell did not report its native log path"
    log_path = Path(match.group(1)).resolve()
    allowed_root = (runtime / "quickshell" / "by-id").resolve()
    try:
        log_path.relative_to(allowed_root)
    except ValueError:
        return "", None, "Quickshell log path is outside this test runtime"
    if not log_path.is_file() or log_path.stat().st_uid != os.getuid():
        return "", None, "Quickshell native log is absent or not owned by this user"
    try:
        return log_path.read_text(encoding="utf-8", errors="replace"), str(log_path), None
    except OSError as error:
        return "", None, "cannot read Quickshell native log: " + str(error)

qml = f'''import QtQuick
import Quickshell

Scope {{
    id: testHost
    property string currentVariant: "V1"
    property var currentPanel: null
    property var currentRoot: null
    property var currentComponent: null
    property int phase: 0
    property int ticks: 0

    Component {{
        id: nativeRootComponent
        QtObject {{
{qml_root}
        }}
    }}

    function fail(message) {{
        console.error("CONTROL_PANEL_NATIVE_FAIL " + currentVariant + " " + message)
        Qt.exit(1)
    }}

    function makeRoot(variant) {{
        if (!Quickshell.screens || Quickshell.screens.length === 0)
            return null
        return nativeRootComponent.createObject(testHost, {{ variant: variant }})
    }}

    function findByName(item, name, depth) {{
        if (!item || depth > 40)
            return null
        if (item.objectName === name)
            return item
        var children = item.children || []
        for (var i = 0; i < children.length; i++) {{
            var found = findByName(children[i], name, depth + 1)
            if (found)
                return found
        }}
        return null
    }}

    function beginVariant(name) {{
        currentVariant = name
        currentRoot = makeRoot(name)
        if (!currentRoot) {{
            fail("no screen is available on the private compositor")
            return
        }}
        var url = name === "V1" ? {source_urls['V1']} : {source_urls['V2']}
        currentComponent = Qt.createComponent(url)
        phase = 1
        ticks = 0
    }}

    function createPanel() {{
        if (currentComponent.status === Component.Error) {{
            fail(currentComponent.errorString())
            return
        }}
        currentPanel = currentComponent.createObject(null, {{ root: currentRoot }})
        if (!currentPanel) {{
            fail("production ControlPanel component did not instantiate")
            return
        }}
        currentRoot.controlVisible = true

        currentPanel.toolsOpen = true
        phase = 2
        ticks = 0
    }}

    function finishVariant() {{
        console.log("CONTROL_PANEL_NATIVE_PASS " + currentVariant + " composed imports, Health focus, adapter close route and opener focus restoration")
        currentPanel.destroy()
        currentPanel = null
        currentRoot.controlVisible = false
        currentRoot.destroy()
        currentRoot = null
        if (currentVariant === "V1") {{
            currentComponent = null
            Qt.callLater(function() {{ testHost.beginVariant("V2") }})
        }} else {{
            console.log("CONTROL_PANEL_NATIVE_COMPOSITION_PASS V1+V2; no service actions invoked")
            Qt.quit()
        }}
    }}

    Timer {{
        interval: 20
        running: true
        repeat: true
        onTriggered: {{
            if (testHost.phase === 0) {{
                testHost.beginVariant("V1")
                return
            }}
            if (++testHost.ticks > 300) {{
                testHost.fail("timed out in phase " + testHost.phase)
                return
            }}
            if (testHost.phase === 1) {{
                if (testHost.currentComponent.status === Component.Ready)
                    testHost.createPanel()
                else if (testHost.currentComponent.status === Component.Error)
                    testHost.fail(testHost.currentComponent.errorString())
                return
            }}
            var content = testHost.currentPanel ? testHost.currentPanel.contentItem : null
            var overlay = testHost.findByName(content, "control-panel-tools-overlay", 0)
            var card = testHost.findByName(overlay, "control-panel-tools", 0)
            var opener = testHost.findByName(content, "control-panel-health-opener", 0)
            if (testHost.phase === 2) {{
                if (!overlay || !card || !opener)
                    return
                if (!overlay.visible || !overlay.open || !card.activeFocus)
                    return
                if (overlay.variantName !== testHost.currentVariant
                        || overlay.focusReturnRoot !== testHost.currentRoot
                        || overlay.focusReturnTarget !== opener) {{
                    testHost.fail("production adapter wiring does not match its active variant/opener")
                    return
                }}
                overlay.closeRequested()
                testHost.phase = 3
                testHost.ticks = 0
                return
            }}
            if (testHost.phase === 3 && !testHost.currentPanel.toolsOpen && opener.activeFocus)
                testHost.finishVariant()
        }}
    }}
}}
'''

with tempfile.TemporaryDirectory(prefix="rise-control-panel-native-", dir=str(scratch)) as folder:
    root = Path(folder)
    for name in ("home", "config", "cache", "state", "data"):
        (root / name).mkdir(mode=0o700)
    shell = root / "control-panel-native.qml"
    shell.write_text(qml, encoding="utf-8")
    if ARGS.lint_generated:
        if ("id: nativeRootComponent" not in qml
                or "property bool controlVisible: false" not in qml
                or "property color paper: '#404040'" not in qml
                or "property color pillShadow: '#404040'" not in qml
                or "function(anchorName) { return 180; }" not in qml
                or "inertRoot.panelInsetReady = true" not in qml
                or "nativeRootComponent.createObject(testHost, { variant: variant })" not in qml):
            raise SystemExit("NATIVE_GATE_ROOT_CONTRACT_FAIL: the generated root must expose the notifying inert adapter API")
        samples = (
            "ReferenceError: fixture regression",
            "TypeError: fixture regression",
            "QML: Invalid assignment to property value",
            "WARN: Unable to assign [undefined] to QColor",
            "WARN: Binding loop detected for property value",
            "QML Connections: no signal of the target matches the name onPaperChanged",
        )
        if not all(native_runtime_errors(sample) for sample in samples):
            raise SystemExit("NATIVE_GATE_ERROR_FILTER_FAIL: runtime defects must be fatal despite success markers")
        qmllint = shutil.which("qmllint") or "/usr/lib/qt6/bin/qmllint"
        if not Path(qmllint).is_file():
            blocked("qmllint is unavailable for generated-shell syntax validation")
        lint = subprocess.run([qmllint, "-I", "/usr/lib/qt6/qml", str(shell)],
                              capture_output=True, text=True, timeout=30)
        print(lint.stdout + lint.stderr, end="")
        if lint.returncode:
            raise SystemExit(lint.returncode)
        print("NATIVE_GATE_ERROR_FILTER_PASS; TypeError/ReferenceError/assignment/binding defects fail the gate")
        print("NATIVE_GATE_FIXTURE_QML_SYNTAX_PASS; no Quickshell process or compositor used")
        raise SystemExit(0)
    if runtime is None:
        blocked("runtime validation was skipped")
    env = os.environ.copy()
    for key in ("DISPLAY", "WAYLAND_SOCKET", "DBUS_SESSION_BUS_ADDRESS", "DBUS_SYSTEM_BUS_ADDRESS"):
        env.pop(key, None)
    env.update({
        "HOME": str(root / "home"),
        "XDG_CONFIG_HOME": str(root / "config"),
        "XDG_CACHE_HOME": str(root / "cache"),
        "XDG_STATE_HOME": str(root / "state"),
        "XDG_DATA_HOME": str(root / "data"),
        "XDG_RUNTIME_DIR": str(runtime),
        "WAYLAND_DISPLAY": DISPLAY,
        "QT_QPA_PLATFORM": "wayland",
        "QT_QUICK_BACKEND": "software",
        "QT_QPA_PLATFORMTHEME": "",
        "TMPDIR": str(scratch),
    })
    result = subprocess.run([QS, "-n", "-p", str(shell)], cwd=ROOT, env=env,
                            capture_output=True, text=True, timeout=20)
    output = result.stdout + result.stderr
    print(output, end="")
    native_log, native_log_path, native_log_error = read_native_log(output, runtime)
    if native_log_error:
        print("NATIVE_COMPOSITION_LOG_CAPTURE_FAIL: " + native_log_error)
    else:
        print("NATIVE_COMPOSITION_LOG_CAPTURED: " + str(native_log_path))
    required_markers = (
        "CONTROL_PANEL_NATIVE_PASS V1",
        "CONTROL_PANEL_NATIVE_PASS V2",
        "CONTROL_PANEL_NATIVE_COMPOSITION_PASS V1+V2",
    )
    missing_markers = [marker for marker in required_markers if marker not in output]
    runtime_errors = list(dict.fromkeys(native_runtime_errors(output) + native_runtime_errors(native_log)))
    if result.returncode != 0 or missing_markers or runtime_errors or native_log_error:
        print("NATIVE_COMPOSITION_FAIL: " + str(result.returncode))
        if missing_markers:
            print("NATIVE_COMPOSITION_MISSING_MARKERS: " + "; ".join(missing_markers))
        if runtime_errors:
            print("NATIVE_COMPOSITION_RUNTIME_DEFECTS:")
            print("\n".join("  " + line for line in runtime_errors))
        raise SystemExit(result.returncode or 1)
