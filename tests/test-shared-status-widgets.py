#!/usr/bin/env python3
"""Load production clock/recording adapters with inert state; never launch actions."""
from pathlib import Path
import json
import os
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
qml = '''import QtQuick
import Quickshell
Scope {
 QtObject {
  id: theme
  property bool clock12h: false
  property bool screenRecording: false
  property int screenRecordingElapsed: 0
  property color ink: "#dddddd"
  property color seal: "#ff6600"
  property string mono: "monospace"
  property var tooltipOwner: null
  function widgetContentColor(group, fallback) { return "#66ccff" }
  function refreshRecordingStatus() { throw new Error("unexpected live action") }
  function hideTooltip(owner) {}
  function showTooltip(text, x, y, bottom, owner) {}
 }
 function check(value, message) { if (!value) throw new Error(message) }
 function load(url) {
  var c=Qt.createComponent(url)
  check(c.status === Component.Ready, c.errorString())
  var item=c.createObject(null, {root:theme})
  check(item !== null, c.errorString())
  return item
 }
 Component.onCompleted: {
  var clock=load(CLOCK)
  clock.now=new Date(2026,0,2,13,5,0)
  check(clock.timeStr === "13:05", "24h time")
  theme.clock12h=true
  check(clock.timeStr === "1:05 PM", "12h time")
  check(String(clock.contentColor) === CLOCK_COLOR, "clock variant color")
  var recorder=load(RECORDER)
  check(recorder.implicitWidth === 0, "inactive recording width")
  theme.screenRecording=true
  theme.screenRecordingElapsed=3661
  check(recorder.elapsedStr === "1:01:01", "recording elapsed time")
  check(recorder.implicitWidth > 0, "active recording width")
  check(String(recorder.contentColor) === RECORD_COLOR, "recording variant color")
  theme.screenRecording=false
  check(recorder.implicitWidth === 0, "recording hidden on stop")
  clock.destroy(); recorder.destroy()
  console.log("SHARED_STATUS_WIDGETS_PASS")
  Qt.callLater(Qt.quit)
 }
}
'''
for variant in ('V1', 'V2'):
    with tempfile.TemporaryDirectory(prefix='rise-status-widgets-', dir='/tmp') as temp:
        folder = Path(temp)
        runtime = folder / 'runtime'
        runtime.mkdir(mode=0o700)
        source = qml
        for token, value in {
            'CLOCK_COLOR': '#dddddd' if variant == 'V1' else '#66ccff',
            'RECORD_COLOR': '#ff6600' if variant == 'V1' else '#66ccff',
            'CLOCK': (repo / f'variants/{variant}/modules/ClockWidget.qml').as_uri(),
            'RECORDER': (repo / f'variants/{variant}/modules/ScreenRecordWidget.qml').as_uri(),
        }.items():
            source = source.replace(token, json.dumps(value))
        probe = folder / 'shell.qml'
        probe.write_text(source)
        result = subprocess.run(['timeout', '8', 'qs', '-n', '-p', str(probe)], capture_output=True,
                                text=True, timeout=15, env={**os.environ,
                                'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software',
                                'QT_QPA_PLATFORMTHEME': '', 'XDG_RUNTIME_DIR': str(runtime)})
        output = result.stdout + result.stderr
        assert result.returncode == 0 and 'SHARED_STATUS_WIDGETS_PASS' in output, output
        assert not re.search(r'ERROR|ReferenceError|TypeError|Unable to assign|Binding loop', output), output
        print(f'PASS: {variant} shared clock and recording state/colors')
