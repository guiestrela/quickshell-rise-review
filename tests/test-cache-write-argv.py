#!/usr/bin/env python3
"""Exercise production QML cache argv builders with private scratch files."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BUILDERS = [
    (f"variants/{variant}/{filename}", process, newline)
    for variant in ("V1", "V2")
    for filename, process, newline in (
        ("Theme.qml", "widgetSaveProc", True),
        ("BarSlot.qml", "orderSaveProc", False),
    )
]
EXTRACT = r"""
const fs = require('fs'), vm = require('vm');
const input = JSON.parse(fs.readFileSync(0, 'utf8'));
const source = fs.readFileSync(input.source, 'utf8');
const match = source.match(new RegExp(input.process + '\\.command\\s*=\\s*(\\[[\\s\\S]*?\\])'));
if (!match) throw new Error('Production cache command assignment not found');
const argv = vm.runInNewContext(match[1], {
    line: input.payload, serialized: input.payload,
    widgetsCachePath: input.path, orderCachePath: input.path
});
process.stdout.write(JSON.stringify(argv));
"""


class CacheWriteArgvTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="rise-cache-argv-", dir=os.environ.get("TMPDIR") or None)
        self.addCleanup(self.tmp.cleanup)
        self.folder = Path(self.tmp.name)

    def write(self, source, process, path, payload):
        path.parent.mkdir(parents=True, exist_ok=True)
        extracted = subprocess.run(
            ["node", "-e", EXTRACT],
            input=json.dumps({"source": str(ROOT / source), "process": process,
                              "path": str(path), "payload": payload}),
            capture_output=True, text=True, check=True, timeout=10,
        )
        argv = json.loads(extracted.stdout)
        self.assertIsInstance(argv, list)
        result = subprocess.run(argv, capture_output=True, text=True, timeout=5,
                                cwd=self.folder)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_apostrophe_in_home_path(self):
        for source, process, newline in BUILDERS:
            with self.subTest(source=source):
                target = self.folder / source / "someone's home" / ".cache" / "settings"
                self.write(source, process, target, "G1|G2|G3|")
                self.assertEqual(target.read_bytes(), b"G1|G2|G3|" + (b"\n" if newline else b""))

    def test_shell_syntax_in_payload_is_only_data(self):
        for index, (source, process, newline) in enumerate(BUILDERS):
            with self.subTest(source=source):
                sentinel = self.folder / f"unexpected-command-{index}"
                payload = "' ; printf unsafe > " + shlex.quote(str(sentinel)) + " ; #"
                target = self.folder / source / "settings"
                self.write(source, process, target, payload)
                self.assertFalse(sentinel.exists(), "Serialized cache data executed as shell code")
                self.assertEqual(target.read_text(), payload + ("\n" if newline else ""))

    def test_preserves_backslashes_unicode_and_newline_format(self):
        payload = "-n back\\slash café $HOME `id`\nsecond line"
        for source, process, newline in BUILDERS:
            with self.subTest(source=source):
                target = self.folder / source / "settings"
                self.write(source, process, target, payload)
                self.assertEqual(target.read_text(), payload + ("\n" if newline else ""))

    def test_shell_syntax_in_path_is_only_data(self):
        for source, process, newline in BUILDERS:
            with self.subTest(source=source):
                target = self.folder / source / "$(printf unsafe) `id` $HOME" / "settings"
                self.write(source, process, target, "safe")
                self.assertEqual(target.read_text(), "safe" + ("\n" if newline else ""))


if __name__ == "__main__":
    unittest.main()
