#!/usr/bin/env python3
"""Run real V1 pill QML with only AI Process/detection boundaries inert."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
modules = repo / 'versions/V1/modules'
with tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR')) as temp:
    root = Path(temp)
    qml_modules = root / 'modules'
    qml_modules.mkdir()
    for name in ('ClaudeWidget.qml', 'NordVPNWidget.qml', 'UiText.qml', 'PillShadow.qml', 'TooltipMixin.qml'):
        shutil.copy2(modules / name, qml_modules / name)
    for name in ('assets', 'shaders'):
        shutil.copytree(repo / 'versions/V1' / name, root / name)

    vpn_path = qml_modules / 'NordVPNWidget.qml'
    vpn_path.write_text(vpn_path.read_text().replace(
        'id: label\n', 'id: label; objectName: "vpnLabel"\n'))

    claude_path = qml_modules / 'ClaudeWidget.qml'
    claude = claude_path.read_text()
    start = claude.index('    // ── process detection ──')
    end = claude.index('    // ── background pill ──', start)
    claude = claude[:start] + '    // Inert harness: omit all four external process probes.\n\n' + claude[end:]
    claude = claude.replace('id: usageLabel\n', 'id: usageLabel; objectName: "aiUsageLabel"\n')
    claude = claude.replace('    Process { id: launchAgent }',
        '    QtObject { id: launchAgent; property var command: []; property bool running: false }')
    claude_path.write_text(claude)

    qml = '''import QtQuick
import Quickshell
import "modules"
ShellRoot {
 id: harness
 function findNamed(item, name) {
  if (item.objectName === name) return item
  for (var i = 0; i < item.children.length; i++) {
   var found = findNamed(item.children[i], name)
   if (found) return found
  }
  return null
 }
 property QtObject theme: QtObject {
  property bool modNordVpn: true
  property bool compactNordVpn: false
  property bool compactAi: false
  property string nordVpnStatus: "Connected"
  property bool vpnVisible: false
  property real activePopupScreenName: 0
  property color seal: "#ffffff"
  property color sumi: "#777777"
  property string mono: "monospace"
  property int pillRadius: 12
  property int pillH: 24
  property color fillIdle: "#222222"
  property color pill: "#222222"
  property color pillBorder: "#333333"
  property int pillBorderW: 1
  property color ink: "#ffffff"
  property bool modClaude: true
  property bool aiUsageVisible: false
  property string aiTool: "claude"
  property bool aiClFresh: true
  property int aiClPct5h: 47
  property int aiClPct7d: 20
  property bool aiClBlocked: false
  property string aiClTokens: "100"
  property string aiClRate: ""
  property int aiClReset5hTs: 0
  property int aiClReset7dTs: 0
  property int aiClToday: 0
  property bool aiClHas: true
  property bool aiCxFresh: true
  property int aiCxPct5h: 52
  property int aiCxPct7d: 19
  property string aiCxPlan: ""
  property string aiCxTokens: ""
  property string aiCxRate: ""
  property int aiCxReset5hTs: 0
  property int aiCxReset7dTs: 0
  property bool aiCxHas: true
  property var aiCxBuckets: []
  property var aiCxWindows: []
  property string aiCodexStatus: "ok"
  property string aiCodexLimitReachedType: ""
  property int aiCxPrimaryPct: 44
  property string aiCxPrimaryLabel: "5h"
  property bool aiOcFresh: true
  property int aiOcPct5h: 32
  property int aiOcPct7d: 12
  property string aiOcPlan: ""
  property string aiOcTokens: ""
  property string aiOcRate: ""
  property string aiOcModel: ""
  property int aiOcToday: 0
  property bool aiOcHas: true
  property bool aiCpFresh: true
  property int aiCpPct: 24
  property string aiCpLabel: "30d"
  property int aiCpResetTs: 0
  property string aiCpPlan: ""
  property bool aiCpUnlimited: false
  property int aiCpCreditsUsed: 10
  property int aiCpCreditsEntitlement: 100
  property bool aiCpHas: true
  function aiFmtReset(ts) { return "" }
  function aiCodexStatusLabel(status, reached) { return "ok" }
  function refreshAiUsage() {}
  function setPanelAnchor(name, x, screen) {}
  function showTooltip(text, x, top, bottom, owner) { harness.tooltipText = text; harness.tooltipOwner = owner }
  function hideTooltip(owner) { if (harness.tooltipOwner === owner) harness.tooltipOwner = null }
 }
 property string tooltipText: ""
 property var tooltipOwner: null
 NordVPNWidget { id: vpn; root: harness.theme; width: implicitWidth; objectName: "vpn" }
 ClaudeWidget { id: ai; root: harness.theme; width: implicitWidth; objectName: "ai"; clActive: true; cxActive: true; ocActive: true; cpActive: true }
 Timer { interval: 80; running: true; repeat: false; onTriggered: {
  var vpnFull = vpn.implicitWidth
  harness.theme.compactNordVpn = true
  if (!(vpn.implicitWidth < vpnFull)) { console.error("VPN_COMPACT_WIDTH", vpnFull, vpn.implicitWidth); Qt.exit(1); return }
  if (harness.findNamed(vpn, "vpnLabel").visible) { console.error("VPN_LABEL_STILL_VISIBLE"); Qt.exit(1); return }
  vpn.testClickHandler.clicked(null)
  if (!harness.theme.vpnVisible) { console.error("VPN_CLICK_LOST"); Qt.exit(1); return }
  var aiWidths = []
  var tools = ["claude", "codex", "opencode", "copilot"]
  harness.theme.compactAi = false
  for (var i = 0; i < tools.length; i++) {
   harness.theme.aiTool = tools[i]
   aiWidths.push(ai.implicitWidth)
   harness.theme.compactAi = true
   if (!(ai.implicitWidth < aiWidths[i])) { console.error("AI_COMPACT_WIDTH", tools[i], aiWidths[i], ai.implicitWidth); Qt.exit(1); return }
   if (harness.findNamed(ai, "aiUsageLabel").visible) { console.error("AI_LABEL_STILL_VISIBLE", tools[i]); Qt.exit(1); return }
   harness.theme.compactAi = false
  }
  harness.theme.nordVpnStatus = "Disconnected"
  if (!vpn.tooltipText.includes("disconnected")) { console.error("VPN_STATUS_TOOLTIP"); Qt.exit(1); return }
  harness.theme.nordVpnStatus = "Connected"
  if (!vpn.tooltipText.includes("connected")) { console.error("VPN_CONNECTED_TOOLTIP"); Qt.exit(1); return }
  harness.theme.nordVpnStatus = "Unavailable"
  if (!vpn.tooltipText.includes("unavailable")) { console.error("VPN_UNAVAILABLE_TOOLTIP"); Qt.exit(1); return }
  harness.theme.nordVpnStatus = "Connecting"
  if (!vpn.tooltipText.includes("checking")) { console.error("VPN_PENDING_TOOLTIP"); Qt.exit(1); return }
  console.log("V1_COMPACT_WIDGET_RUNTIME_PASS", "vpn", vpnFull, vpn.implicitWidth, "ai", aiWidths.join(","))
  Qt.exit(0)
 }}
}
'''
    qml_path = root / 'compact.qml'
    qml_path.write_text(qml)
    env = dict(os.environ)
    env.pop('DISPLAY', None)
    env['XDG_RUNTIME_DIR'] = '/run/user/1000'
    env['WAYLAND_DISPLAY'] = 'wayland-1'
    env['QT_QPA_PLATFORM'] = 'wayland'
    result = subprocess.run(['qs', '-n', '-p', str(qml_path)], env=env,
        capture_output=True, text=True, timeout=20)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode or 'V1_COMPACT_WIDGET_RUNTIME_PASS' not in output:
        raise SystemExit(result.returncode or 1)
