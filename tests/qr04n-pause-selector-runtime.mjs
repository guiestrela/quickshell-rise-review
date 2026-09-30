import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdtempSync, rmSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';
const project = resolve(fileURLToPath(new URL('..', import.meta.url)));
const variant = process.argv.includes('--v2') ? 'v2' : 'v1';
const unavailable = process.argv.includes('--unavailable');
const scratch = mkdtempSync(join(process.env.TMPDIR, 'qr04n-pause-selector-'));
try {
  const fixture = readFileSync(join(project, `tests/qml/qr04n-${variant}-wiring.qml`), 'utf8');
  const marker = 'host.verify(host.panel.visible, "instantiated VPN panel remained hidden")';
  assert.equal(fixture.split(marker).length, 2);
  let qml = fixture.replace(marker, `${marker}\n                pauseCheck.start(); return;`);
  qml = qml.replace('    property int step: 0', `    property int step: 0
    property int pausePhase: -1
    property int pauseIndex: 0
    property var tooltipOwner: null
    property string tooltipText: ""
    property bool tooltipShown: false
    function showTooltip(text, x, topY, bottomY, owner) { tooltipText = text; tooltipOwner = owner; tooltipShown = true }
    function hideTooltip(owner) { if (tooltipOwner === owner) { tooltipShown = false; tooltipOwner = null } }`);
  const timers = `
    Timer { id: pauseCheck; interval: 70; repeat: true; onTriggered: {
      try {
        var p = host.panel;
        var durations = ["5m", "15m", "30m", "1h", "24h"];
        host.verify(p.testPauseSelectorHandler !== undefined && p.testPauseApplyHandler !== undefined,
          "pause duration selector/apply handlers are missing");
        if (Quickshell.env("QR04N_STATUS_MODE") === "unavailable") {
          host.verify(!p.testPauseSelectorHandler.enabled && !p.testPauseApplyHandler.enabled, "pause controls enabled while unavailable");
          p.testPauseApplyHandler.clicked(null);
          host.verify(!host.controller.vpnBusy, "pause action started while unavailable");
          console.log("QR04N_PAUSE_SELECTOR_QML_PASS unavailable"); Qt.exit(0); return;
        }
        if (host.pausePhase === -1) { host.controller.vpnState = "Connecting"; host.pausePhase = -2; return }
        if (host.pausePhase === -2) {
          host.verify(!p.testPauseSelectorHandler.enabled && !p.testPauseApplyHandler.enabled, "pause controls enabled while busy");
          p.testPauseApplyHandler.clicked(null);
          host.controller.vpnState = "Connected"; host.pausePhase = 0; return;
        }
        if (host.pausePhase === 0) {
          host.verify(p.testPauseSelectorHandler.enabled && p.testPauseApplyHandler.enabled, "pause controls not restored");
          var before = host.controller.vpnActionMessage;
          p.testPauseSelectorHandler.clicked(null);
          host.verify(p.pauseSelectorExpanded, "duration menu did not open");
          var option = p.testTargets["vpn-pause-" + durations[host.pauseIndex]];
          host.verify(option && option.enabled, "duration option missing/disabled");
          option.clicked(null);
          host.verify(p.selectedPauseDuration === durations[host.pauseIndex] && !p.pauseSelectorExpanded, "duration selection did not update/close");
          host.verify(!host.controller.vpnBusy && host.controller.vpnActionMessage === before, "selecting duration executed a VPN action");
          p.testPauseApplyHandler.clicked(null);
          host.pausePhase = 1; return;
        }
        if (host.pausePhase === 1) {
          host.verify(!p.testPauseApplyHandler.enabled && !p.testPauseSelectorHandler.enabled, "pause controls enabled during action");
          p.testPauseApplyHandler.clicked(null);
          host.pausePhase = 2; return;
        }
        if (host.controller.vpnBusy) return;
        host.pauseIndex++;
        if (host.pauseIndex === durations.length) {
          p.testPauseSelectorHandler.clicked(null);
          host.verify(p.pauseSelectorExpanded, "menu did not expand before closing");
          p.closePanel();
          host.verify(!p.pauseSelectorExpanded, "explicit panel close preserved expanded pause menu");
          host.vpnVisible = true;
          p.testPauseSelectorHandler.clicked(null);
          host.verify(p.pauseSelectorExpanded, "menu did not expand after reopening");
          host.vpnVisible = false;
          host.verify(!p.pauseSelectorExpanded, "external panel close preserved expanded pause menu");
          host.vpnVisible = true;
          host.verify(!p.pauseSelectorExpanded && p.selectedPauseDuration === "24h", "reopen lost duration or expanded menu");
          console.log("QR04N_PAUSE_SELECTOR_QML_PASS all durations; selection-only; busy guards; explicit/external close resets menu"); Qt.exit(0); return;
        }
        host.pausePhase = 0;
      } catch (e) { console.error("QR04N_PAUSE_SELECTOR_FAIL", e); Qt.exit(1) }
    } }
`;
  qml = qml.replace(/\n}\s*$/, `${timers}\n}`);
  const shell = join(scratch, 'shell.qml');
  const log = join(scratch, 'argv.bin');
  writeFileSync(shell, qml);
  const run = spawnSync('qs', ['-n', '-p', shell], {encoding:'utf8', timeout:18000,
    env:{...process.env, QR04N_ARGV_LOG:log, QR04N_STATUS_MODE:unavailable ? 'unavailable' : undefined,
      DISPLAY:undefined, QT_QPA_PLATFORM:'wayland'}});
  const output = `${run.stdout ?? ''}${run.stderr ?? ''}`;
  assert.equal(run.error, undefined, output);
  assert.equal(run.status, 0, output);
  assert.match(output, /QR04N_PAUSE_SELECTOR_QML_PASS/, output);
  const argv = readFileSync(log,'utf8').split('\n').filter(Boolean).map(line=>line.split('\0').filter(Boolean));
  assert.deepEqual(argv.filter(args=>args[0]==='pause'), unavailable ? [] :
    ['5m','15m','30m','1h','24h'].map(duration=>['pause',duration]));
  console.log(`QR04N_PAUSE_SELECTOR_RUNTIME_PASS ${variant}/${unavailable ? 'unavailable' : 'durations+busy'}: real panel handlers/controller; exact recording-stub argv; no real VPN`);
} finally { rmSync(scratch,{recursive:true,force:true}); }
