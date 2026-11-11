#!/usr/bin/env python3
"""Production coordinator/presentation with inert process and action boundaries."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile
import time

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='rise-indicators-', dir='/tmp') as tmp:
    folder = Path(tmp)
    runtime = folder / 'runtime'
    runtime.mkdir(mode=0o700)
    source = (repo / 'shared/services/OmarchyIndicators.qml').read_text()
    source = source.replace('Process {', 'TestProcess {').replace('IpcHandler {', 'TestIpcHandler {')
    source = source.replace('StdioCollector {', 'TestCollector {')
    source = source.replace('Quickshell.execDetached', 'service.root.launch')
    (folder / 'OmarchyIndicators.qml').write_text(source)
    for name in ('OmarchyIndicatorsWidget.qml', 'UiText.qml', 'TooltipMixin.qml'):
        shutil.copyfile(repo / 'shared/components' / name, folder / name)
    (folder / 'TestProcess.qml').write_text('''import QtQuick
Item {
 property var command: []
 property bool running: false
 property var stdout: null
 signal exited(int exitCode, int exitStatus)
 function finish(code, output) {
  if (stdout) stdout.text = output || ""
  running = false
  exited(code, 0)
 }
}
''')
    (folder / 'TestCollector.qml').write_text('import QtQuick\nQtObject { property bool waitForEnd: true; property string text: "" }\n')
    (folder / 'TestIpcHandler.qml').write_text('import QtQuick\nItem { property string target: ""; property bool enabled: false }\n')
    (folder / 'shell.qml').write_text('''import QtQuick
import Quickshell
Scope {
 id: test
 property int phase: 0
 QtObject {
  id: theme
  property bool stayAwake: false
  property bool notifSilenced: false
  property bool screenRecording: false
  property color seal: "#e99870"
  property string mono: "JetBrainsMono Nerd Font"
  property var tooltipOwner: null
  property string tooltipText: ""
  property var launches: []
  function showTooltip(text, x, y, bottom, owner) {}
  function hideTooltip(owner) {}
  function refreshStatusIndicators() {}
  function refreshRecordingStatus() {}
  function launch(argv) { launches = launches.concat([argv]) }
 }
 QtObject {
  id: native
  property bool stayAwake: false
  property bool doNotDisturb: false
  property bool enabled: false
  property bool active: false
  property var peers: []
  property int refreshes: 0
  function setIdleEnabled(value) { stayAwake = !value }
  function setDoNotDisturb(value) { doNotDisturb = value }
  function setNightlight(value) { enabled = value }
  function refresh() { refreshes++ }
 }
 QtObject {
  id: facade
  function firstPartyServiceFor(id) { return native }
 }
 OmarchyIndicators { id: coordinator; root: theme }
 OmarchyIndicatorsWidget { id: horizontal; root: theme; coordinator: coordinator; contentColor: "#e99870" }
 OmarchyIndicatorsWidget { id: vertical; root: theme; coordinator: coordinator; contentColor: "#77bbdd"; vertical: true }
 function check(ok, message) { if (!ok) throw new Error(message) }
 function process(name) {
  for (var child of coordinator.children) if (child.objectName === name) return child
  throw new Error("missing process " + name)
 }
 Timer {
  interval: 30; running: true; repeat: true
  onTriggered: {
   try {
    if (test.phase === 0) {
     test.check(horizontal.implicitWidth === 0, "inactive group collapses")
     test.check(vertical.implicitHeight === 0, "inactive vertical group collapses")
     coordinator.shell = facade
     test.phase++
    } else if (test.phase === 1) {
     test.check(test.process("sudoStatus").running && test.process("reminderStatus").running, "one startup query pair")
     coordinator.refresh(); coordinator.refresh()
     test.check(coordinator.refreshPending, "coalesce refresh requests")
     test.process("sudoStatus").finish(1, "")
     test.process("reminderStatus").finish(0, '{"count":2,"tooltip":"Two reminders"}')
     test.check(coordinator.reminderCount === 2, "native reminder JSON")
     for (var invalid of ['null', '[]', '{"count":-1,"tooltip":"bad"}', '{"count":0}', '{"count":"3","tooltip":"bad"}'])
      test.check(!coordinator.acceptReminder(invalid) && coordinator.reminderCount === 2, "reject invalid reminder response")
     test.phase++
    } else if (test.phase === 2) {
     test.check(test.process("sudoStatus").running, "queued refresh ran")
     test.process("sudoStatus").finish(0, "")
     test.process("reminderStatus").finish(0, '{"count":0,"tooltip":"Set reminder"}')
     coordinator.activate("StayAwake"); coordinator.activate("Dnd"); coordinator.activate("NightLight")
     native.active = true; native.peers = ["fixture-peer"]
     theme.screenRecording = true
     test.check(coordinator.awake && coordinator.silenced && coordinator.night, "native service actions/bindings")
     test.check(coordinator.remote && coordinator.recording && coordinator.passwordless, "all native statuses")
     test.check(horizontal.hasActive && vertical.hasActive, "shared state reaches both outputs")
     horizontal.revealInactive = true; vertical.revealInactive = true
     coordinator.activate("ScreenRecording"); coordinator.activate("Reminder")
     test.check(theme.launches[0][1] === "--stop-recording", "recording action")
     test.check(theme.launches[1][1] === "-i", "inactive reminder action")
     coordinator.activate("PasswordlessSudo")
     test.check(test.process("sudoDisable").running, "explicit sudo revoke only")
     test.phase++
    } else if (test.phase === 3) {
     test.check(horizontal.implicitWidth > 120 && horizontal.implicitHeight === 28, "horizontal geometry " + horizontal.implicitWidth + "x" + horizontal.implicitHeight)
     test.check(vertical.implicitWidth === 28 && vertical.implicitHeight > 150, "vertical geometry " + vertical.implicitWidth + "x" + vertical.implicitHeight)
     test.check(horizontal.entries.length === 7, "seven unique indicators")
     test.check(horizontal.plainTooltip('<img src="https://example.invalid">').indexOf('<') === -1, "tooltip markup stays inert")
     coordinator.activate("StayAwake"); coordinator.activate("Dnd"); coordinator.activate("NightLight")
     native.active = false; theme.screenRecording = false; coordinator.passwordless = false
     horizontal.revealInactive = false; vertical.revealInactive = false
     test.phase++
    } else {
     test.check(horizontal.implicitWidth === 0 && vertical.implicitHeight === 0, "collapse after deactivation")
     console.log("OMARCHY_INDICATORS_PASS")
     Qt.quit()
    }
   } catch (error) { console.error(error); Qt.exit(1) }
  }
 }
}
''')
    result = subprocess.run(['timeout', '12', 'qs', '-n', '-p', str(folder / 'shell.qml')],
                            capture_output=True, text=True, timeout=20,
                            env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen',
                                 'QT_QUICK_BACKEND': 'software', 'QT_QPA_PLATFORMTHEME': '',
                                 'XDG_RUNTIME_DIR': str(runtime)})
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'OMARCHY_INDICATORS_PASS' in output, output
    assert not re.search(r'ERROR|ReferenceError|TypeError|Unable to assign|Binding loop', output), output
    print('PASS: native indicators, shared coordinator, inert actions and both orientations')

    # Exercise the actual Quickshell Process/collector and IPC handler too.
    # Only helper executable discovery is redirected; these scripts never
    # reach sudo, systemd, the recorder, or a user's account.
    (folder / 'OmarchyIndicators.qml').write_text((repo / 'shared/services/OmarchyIndicators.qml').read_text())
    commands = folder / 'bin'
    commands.mkdir()
    calls = folder / 'calls'
    for name, response in [('omarchy-sudo-passwordless', 'exit 1'),
                           ('omarchy-reminder', "printf '%s\\n' '{\"count\":3,\"tooltip\":\"Fixture reminders\"}'")]:
        helper = commands / name
        helper.write_text('#!/bin/sh\nprintf x >> "$RISE_INDICATOR_CALLS"\n' + response + '\n')
        helper.chmod(0o700)
    (folder / 'shell.qml').write_text('''import QtQuick
import Quickshell
Scope {
 id: harness
 property int ticks: 0
 QtObject {
  id: theme
  property bool stayAwake: false
  property bool notifSilenced: false
  property bool screenRecording: false
  property int refreshes: 0
  function refreshStatusIndicators() { refreshes++ }
  function refreshRecordingStatus() {}
 }
 QtObject { id: facade; function firstPartyServiceFor(id) { return null } }
 OmarchyIndicators { id: coordinator; root: theme; shell: facade }
 Timer {
  interval: 20; running: true; repeat: true
  onTriggered: {
   harness.ticks++
   if (coordinator.reminderCount === 3 && theme.refreshes >= 2) {
    console.log("OMARCHY_INDICATORS_NATIVE_IPC_PASS"); Qt.quit()
   } else if (harness.ticks > 250) { console.error("native IPC timeout"); Qt.exit(1) }
  }
 }
}
''')
    environment = {**os.environ, 'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software',
                   'QT_QPA_PLATFORMTHEME': '', 'XDG_RUNTIME_DIR': str(runtime),
                   'PATH': str(commands) + ':/usr/bin:/bin', 'RISE_INDICATOR_CALLS': str(calls)}
    child = subprocess.Popen(['qs', '-n', '-p', str(folder / 'shell.qml')],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=environment)
    try:
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline and child.poll() is None:
            if calls.exists() and len(calls.read_text()) >= 2:
                break
            time.sleep(0.02)
        ipc = subprocess.run(['qs', 'ipc', '-n', '-p', str(folder / 'shell.qml'),
                              'call', 'omarchy.indicators', 'refresh'],
                             capture_output=True, text=True, timeout=5, env=environment)
        stdout, stderr = child.communicate(timeout=8)
        output = stdout + stderr
        assert ipc.returncode == 0 and 'not found' not in ipc.stdout.lower(), ipc.stdout + ipc.stderr
        assert child.returncode == 0 and 'OMARCHY_INDICATORS_NATIVE_IPC_PASS' in output, output
        assert not re.search(r'ERROR|ReferenceError|TypeError|Unable to assign|Binding loop', output), output
    finally:
        if child.poll() is None:
            child.kill()
            child.communicate()
    print('PASS: real Process/collector, stub helpers, and native indicator refresh IPC')
