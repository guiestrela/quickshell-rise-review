import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const root = process.env.QSR_TEST_ROOT ?? process.cwd();
const variants = [
  ['V1', 'versions/V1/modules/MemoryWidget.qml'],
  ['V2', 'versions/V1/variants/V2/modules/MemoryWidget.qml'],
];

for (const [variant, relativePath] of variants) {
  test(`${variant} top-bar memory usage shows one decimal place`, () => {
    const qml = fs.readFileSync(path.join(root, relativePath), 'utf8');
    const match = qml.match(/readonly property string usedLabel:\s*([^\n]+)/);
    assert.ok(match, 'memory widget must define its usage label');
    assert.match(match[1], /usedGiB\.toFixed\(1\)\s*\+\s*"G"/);

    const label = vm.runInNewContext(match[1], { usedGiB: 8970 / 1024 });
    assert.equal(label, '8.8G');
  });
}
