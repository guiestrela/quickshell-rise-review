import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdtempSync, rmSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';
const project = resolve(fileURLToPath(new URL('..', import.meta.url)));
const variant = process.argv.includes('--v2') ? 'v2' : 'v1';
const scenario = process.argv.includes('--unavailable') ? 'unavailable' : 'busy';
const scratch = mkdtempSync(join(process.env.TMPDIR, 'qr04n-dns-guard-'));
try {
  const fixture = readFileSync(join(project, `tests/qml/qr04n-${variant}-wiring.qml`), 'utf8');
  let qml = fixture;
  if (scenario === 'busy') {
    const marker = 'host.verify(host.controller.vpnBusy, "accepted action did not expose busy state")';
    qml = fixture.replace(marker, `${marker}\n                host.verify(!host.controller.setDnsServers("4.4.4.4"), "DNS set accepted while busy")\n                host.verify(!host.controller.resetDnsServers(), "DNS reset accepted while busy")`);
  } else {
    const marker = 'host.verify(!host.controller.setVpnSetting("protocol"), "settings action was accepted while unavailable")';
    qml = fixture.replace(marker, `${marker}\n                    host.verify(!host.controller.setDnsServers("1.1.1.1"), "DNS set accepted while unavailable")\n                    host.verify(!host.controller.resetDnsServers(), "DNS reset accepted while unavailable")`);
  }
  assert.notEqual(qml, fixture, 'could not inject DNS guard assertions');
  const shell = join(scratch, 'shell.qml');
  const log = join(scratch, 'argv.bin');
  writeFileSync(shell, qml);
  const run = spawnSync('qs', ['-n', '-p', shell], {encoding:'utf8', timeout:18000,
    env:{...process.env, QR04N_ARGV_LOG:log, QR04N_STATUS_MODE:scenario === 'unavailable' ? 'unavailable' : undefined,
      DISPLAY:undefined, QT_QPA_PLATFORM:'wayland'}});
  const output = `${run.stdout ?? ''}${run.stderr ?? ''}`;
  assert.equal(run.error, undefined, output);
  assert.equal(run.status, 0, output);
  const expected = scenario === 'unavailable' ? `QR04N_${variant.toUpperCase()}_UNAVAILABLE_QML_PASS` : `QR04N_${variant.toUpperCase()}_WIRING_QML_PASS`;
  assert.match(output, new RegExp(expected), output);
  const argv = readFileSync(log,'utf8').split('\n').filter(Boolean).map(line=>line.split('\0').filter(Boolean));
  assert.deepEqual(argv.filter(args=>args[0]==='set' && args[1]==='dns'), [], 'guarded DNS operation reached CLI stub');
  console.log(`QR04N_DNS_GUARD_PASS ${variant}/${scenario}: rejected; no DNS mutation argv`);
} finally { rmSync(scratch,{recursive:true,force:true}); }
