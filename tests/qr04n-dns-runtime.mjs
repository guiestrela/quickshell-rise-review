import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdtempSync, rmSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';
const project = resolve(fileURLToPath(new URL('..', import.meta.url)));
const variant = process.argv.includes('--v2') ? 'v2' : 'v1';
const scratch = mkdtempSync(join(process.env.TMPDIR, 'qr04n-dns-'));
try {
  const fixture = readFileSync(join(project, `tests/qml/qr04n-${variant}-wiring.qml`), 'utf8');
  const marker = `console.log("QR04N_${variant.toUpperCase()}_WIRING_QML_PASS real widget/panel/controller; stub-only argv; invalid inputs rejected")\n            Qt.exit(0)`;
  const sequence = `host.verify(!host.controller.setDnsServers("1.1.1.256"), "invalid IPv4 was accepted");
            host.verify(!host.controller.setDnsServers("1.1.1.1, 2.2.2.2, 3.3.3.3, 4.4.4.4"), "more than 3 DNS servers accepted");
            host.panel.testDnsInput.text = "1.1.1.1, 8.8.8.8";
            host.panel.testDnsSetHandler.clicked(null);
            dnsPhase = 1;
            dnsCheck.start();
            return`;
  const qml = fixture.replace(marker, sequence).replace('    property int step: 0', '    property int step: 0\n    property int dnsPhase: 0');
  assert.notEqual(qml, fixture, 'could not inject DNS behavioral assertions');
  const timer = `\n    Timer { id: dnsCheck; interval: 50; repeat: true; onTriggered: {
        if (host.controller.vpnBusy) return;
        if (host.dnsPhase === 1) {
            host.verify(host.panel.testDnsResetHandler.enabled, "DNS reset handler disabled after operation");
            host.panel.testDnsResetHandler.clicked(null); host.dnsPhase = 2; return;
        }
        if (host.dnsPhase === 2) {
            stop();
            console.log("QR04N_${variant.toUpperCase()}_DNS_QML_PASS real panel handlers; validation/reset; stub only");
            Qt.exit(0);
        }
    } }\n`;
  const shellText = qml.replace(/\n}\s*$/, `${timer}\n}`);
  const shell = join(scratch, 'shell.qml');
  const log = join(scratch, 'argv.bin');
  writeFileSync(shell, shellText);
  const run = spawnSync('qs', ['-n', '-p', shell], {encoding:'utf8', timeout:18000,
    env:{...process.env, QR04N_ARGV_LOG:log, DISPLAY:undefined, QT_QPA_PLATFORM:'wayland'}});
  const output = `${run.stdout ?? ''}${run.stderr ?? ''}`;
  assert.equal(run.error, undefined, output);
  assert.equal(run.status, 0, output);
  assert.match(output, new RegExp(`QR04N_${variant.toUpperCase()}_DNS_QML_PASS`), output);
  const argv = readFileSync(log,'utf8').split('\n').filter(Boolean).map(line=>line.split('\0').filter(Boolean));
  const dnsArgv = argv.filter(args=>args[0]==='set' && args[1]==='dns');
  assert.deepEqual(dnsArgv, [['set','dns','1.1.1.1','8.8.8.8'], ['set','dns','off']]);
  console.log(`QR04N_DNS_RUNTIME_PASS ${variant}: validation/busy/reset; exact argv; invalid requests generated no Process`);
} finally { rmSync(scratch,{recursive:true,force:true}); }
