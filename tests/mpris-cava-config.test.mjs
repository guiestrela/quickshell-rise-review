import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, chmodSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import vm from 'node:vm';
const scratch = mkdtempSync(join(tmpdir(), 'mpris-cava-'));
try {
  // Read the actual fd-backed configuration passed to cava by the QML command.
  const stub = join(scratch, 'cava');
  writeFileSync(stub, '#!/bin/bash\ncat "$2"\n');
  chmodSync(stub, 0o755);
  for (const variant of ['', 'variants/V2/']) {
    const qml = readFileSync(new URL(`../versions/V1/${variant}modules/MprisWidget.qml`, import.meta.url), 'utf8');
    const expression = qml.match(/id: museCava[\s\S]*?command: (\[[\s\S]*?\n        \])/)[1];
    const argv = vm.runInNewContext(expression);
    const run = spawnSync(argv[0], argv.slice(1), { encoding: 'utf8', env: { ...process.env, PATH: `${scratch}:${process.env.PATH}` } });
    assert.equal(run.status, 0, run.stderr);
    assert.match(run.stdout, /^\[general\]\nbars = 24\n/);
    assert.match(run.stdout, /\n\[input\]\nmethod = pipewire\nsource = auto\n/);
    assert.match(run.stdout, /\n\[output\]\nmethod = raw\n/);
    assert.ok(!run.stdout.includes('\\n'), 'config must contain actual line breaks');
  }
  console.log('CAVA configuration execution passed (V1/V2)');
} finally { rmSync(scratch, { recursive: true, force: true }); }
