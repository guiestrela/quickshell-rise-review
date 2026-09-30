import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdtempSync, rmSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';
const project = resolve(fileURLToPath(new URL('..', import.meta.url)));
const variant = process.argv.includes('--v2') ? 'v2' : 'v1';
const cases = [
  ['notify', 'notify'], ['tray', 'tray'], ['meshnet', 'meshnet'],
  ['lan-discovery', 'lan-discovery'], ['routing', 'routing'],
  ['virtual-location', 'virtual-location'], ['arp-ignore', 'arp-ignore'],
  ['post-quantum-vpn', 'post-quantum']
];
const scratch = mkdtempSync(join(process.env.TMPDIR, 'qr04n-switches-'));
try {
  const original = readFileSync(join(project, `tests/qml/qr04n-${variant}-wiring.qml`), 'utf8');
  const actions = cases.flatMap(([key]) => ['disabled', 'enabled'].map(state => `function() {
    var s = {}; s[${JSON.stringify(key)}] = ${JSON.stringify(state)}; host.controller.vpnSettings = s;
    var handler = host.panel.testTargets[${JSON.stringify('vpn-setting-' + key)}];
    host.verify(handler && handler.enabled, ${JSON.stringify('missing/disabled real handler: ' + key)});
    handler.clicked(null); return true; // busy is asserted by the fixture after Qt bindings settle
  }`));
  const qml = original.replace(/var actions = \[[\s\S]*?\n        \]/, 'var actions = [\n' + actions.join(',\n') + '\n        ]');
  assert.notEqual(qml, original, 'could not replace fixture actions');
  const shell = join(scratch, 'shell.qml');
  const log = join(scratch, 'argv.bin');
  writeFileSync(shell, qml);
  const run = spawnSync('qs', ['-n', '-p', shell], {
    encoding: 'utf8', timeout: 18000,
    env: {...process.env, QR04N_ARGV_LOG: log, DISPLAY: undefined, QT_QPA_PLATFORM: 'wayland'}
  });
  const output = `${run.stdout ?? ''}${run.stderr ?? ''}`;
  assert.equal(run.error, undefined, output);
  assert.equal(run.status, 0, output);
  assert.match(output, new RegExp(`QR04N_${variant.toUpperCase()}_WIRING_QML_PASS`), output);
  const argv = readFileSync(log, 'utf8').split('\n').filter(Boolean).map(line => line.split('\0').filter(Boolean));
  const actionArgv = argv.filter(args => ['connect','disconnect','pause','set'].includes(args[0]));
  assert.deepEqual(actionArgv, cases.flatMap(([, command]) => [['set',command,'on'],['set',command,'off']]));
  console.log(`QR04N_EXTRA_SWITCHES_RUNTIME_PASS ${variant} 8 real handlers / 16 exact stub argv; no real VPN actions`);
} finally { rmSync(scratch, {recursive:true, force:true}); }
