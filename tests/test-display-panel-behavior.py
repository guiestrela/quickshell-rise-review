#!/usr/bin/env python3
"""Production UI dispatch tests with inert controller, no live monitor actions.
Shared panel is instantiated under V1/V2 token fixtures. Method dispatch is not
physical pointer, complete Theme, or compositor visual acceptance.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
source = repo / "versions/V1/panels/DisplayManagerPanel.qml"
base = (repo / "versions/V1/tests/qr-display-panel-runtime.qml").read_text()
for variant in ("V1", "V2"):
    with tempfile.TemporaryDirectory(prefix="display-ui-", dir=os.environ["TMPDIR"]) as directory:
        folder = Path(directory)
        (folder / "panels").mkdir()
        (folder / "panels/DisplayManagerPanel.qml").write_bytes(source.read_bytes())
        fixture = base.replace('import "../panels"', 'import "panels"')
        fixture = fixture.replace('property color bg: "#202020"', 'property color bg: "#202020"\n property color paper: "#202020"\n property color muted: "#aaaaaa"\n property color fillHover: "#404040"\n property color pillBorder: "#505050"\n property real pillBorderW: 1\n property real pillRadius: 12')
        fixture = fixture.replace('property var monitors: []', 'property var monitors: [{ name: "DP-1", width: 2560, height: 1440, x: 0, y: 0, scale: 1, transform: 0, refreshRate: 59.95, mirrorOf: "none", availableModes: ["2560x1440@59.95Hz"] }, { name: "DP-2", width: 1920, height: 1080, x: 2560, y: 0, scale: 1, transform: 0, refreshRate: 60, mirrorOf: "none", availableModes: ["1920x1080@60.00Hz"] }]\n property var positions: ({})\n property var calls: []')
        fixture = fixture.replace('property string selectedMonitor: ""', 'property string selectedMonitor: "DP-1"')
        fixture = fixture.replace('function monitor(name) { return null }', 'function monitor(name) { for (var i=0;i<monitors.length;i++) if(monitors[i].name===name) return monitors[i]; return null }')
        fixture = fixture.replace('function applyMonitor() { }', 'function applyMonitor(name, mode, x, y, scale, transform, mirror) { calls.push([name,mode,x,y,scale,transform,mirror]); return true }')
        fixture = fixture.replace('function setPosition() { }', 'function setPosition(name,x,y) { var next=Object.assign({},positions); next[name]={x:x,y:y}; positions=next }')
        start = fixture.index('    Timer {')
        fixture = fixture[:start] + '''    Timer {
        interval: 300; running: true
        onTriggered: {
            function check(ok, message) { if (!ok) throw new Error(message) }
            try {
                check(!productionPanel.visible, "fixture must stay hidden")
                check(!productionPanel.commitCanvasPosition("DP-2",2560,0,-800,0,1), "overlapping mouse drop must be blocked before backend")
                check(fakeController.calls.length===0, "overlap dispatched a compositor mutation")
                check(productionPanel.commitCanvasPosition("DP-1",0,0,-20,-10,0.1), "drag dispatch rejected")
                var call=fakeController.calls[0]
                check(call[0]==="DP-1" && call[2]===-200 && call[3]===-100, "drag must convert pixels into changed coordinates")
                check(call[1]==="2560x1440@59.95", "drag must preserve mode/refresh")
                var count=fakeController.calls.length
                fakeController.busy=true
                check(!productionPanel.commitCanvasPosition("DP-2",2560,0,10,10,0.1), "busy drag must be rejected")
                check(fakeController.calls.length===count, "busy drag dispatched")
                fakeController.busy=false
                check(!productionPanel.commitCanvasPosition("DP-1",0,0,NaN,0,0.1), "invalid drag must be rejected")
                check(productionPanel.mirrorTargets().join(",")==="DP-2", "mirror targets must exclude selected display")
                check(productionPanel.activeDisplayCount()===2, "active display count")
                fakeController.positions=({})
                count=fakeController.calls.length
                check(!productionPanel.commitCanvasPosition("DP-2",2560,0,-1,0,1), "one-pixel overlap must be blocked")
                check(fakeController.calls.length===count, "one-pixel overlap reached backend")
                check(productionPanel.commitCanvasPosition("DP-2",2560,0,0,30,1), "touching edges must remain valid")
                fakeController.positions=({})
                fakeController.monitors=[{name:"DP-1",width:2560,height:1440,x:0,y:0,scale:1,transform:0,refreshRate:60,mirrorOf:"none"},{name:"DP-2",width:1920,height:1080,x:2560,y:0,scale:1,transform:1,refreshRate:60,mirrorOf:"none"}]
                check(!productionPanel.commitCanvasPosition("DP-1",0,0,200,1500,1), "portrait logical height must participate in collision")
                fakeController.monitors=[{name:"DP-1",width:2560,height:1440,x:0,y:0,scale:2,transform:0,refreshRate:60,mirrorOf:"none"},{name:"DP-2",width:1920,height:1080,x:2560,y:0,scale:1,transform:0,refreshRate:60,mirrorOf:"none"}]
                check(productionPanel.commitCanvasPosition("DP-2",2560,0,-1280,0,1), "scaled touching edges must not use physical width")
                console.log("DISPLAY_UI_BEHAVIOR_PASS VARIANT")
            } catch (error) { console.error("DISPLAY_UI_ASSERTION_FAILED " + error) }
            Qt.quit()
        }
    }
}'''.replace('VARIANT', variant)
        (folder / "shell.qml").write_text(fixture)
        env = dict(os.environ, QT_QPA_PLATFORM="wayland")
        env.pop("DISPLAY", None)
        result = subprocess.run(["qs", "-n", "-p", str(folder / "shell.qml")], env=env, capture_output=True, text=True, timeout=15)
        output = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout + result.stderr)
        print(output)
        assert result.returncode == 0 and f"DISPLAY_UI_BEHAVIOR_PASS {variant}" in output, f"{variant} behavior failed"
        assert not any(marker in output for marker in ("ERROR:", "ReferenceError", "TypeError", "ASSERTION_FAILED")), f"{variant} QML error"
print("DISPLAY_UI_BEHAVIOR_PASS V1/V2 (inert method dispatch)")
