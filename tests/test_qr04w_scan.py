"""QR-04W: real folder scan stays within a tree and honors recursion."""
import importlib.util
from contextlib import contextmanager
from unittest.mock import patch
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'shared/integrations/wallpaper-scan.py'
spec = importlib.util.spec_from_file_location('rise_wallpaper_scan', SCRIPT)
assert spec is not None and spec.loader is not None
scanner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scanner)


class WallpaperScanTests(unittest.TestCase):
    def test_non_recursive_scans_only_top_level(self):
        with tempfile.TemporaryDirectory(prefix='qr04w-scan-', dir=os.environ['TMPDIR']) as temp:
            folder = Path(temp)
            (folder / 'top.jpg').write_bytes(b'test')
            (folder / 'nested').mkdir()
            (folder / 'nested' / 'deep.png').write_bytes(b'test')
            self.assertEqual(scanner.scan(str(folder), recursive=False), [str(folder / 'top.jpg')])
            self.assertEqual(set(scanner.scan(str(folder), recursive=True)),
                             {str(folder / 'top.jpg'), str(folder / 'nested' / 'deep.png')})

    def test_entry_limit_bounds_directory_enumeration(self):
        with tempfile.TemporaryDirectory(prefix='qr04w-scan-', dir=os.environ['TMPDIR']) as temp:
            folder = Path(temp)
            for index in range(20):
                (folder / f'{index}.jpg').write_bytes(b'test')
            original = os.scandir
            enumerated = []

            @contextmanager
            def tracked_scandir(path):
                with original(path) as iterator:
                    def entries():
                        for entry in iterator:
                            enumerated.append(entry.name)
                            yield entry
                    yield entries()

            with patch.object(scanner, 'MAX_ENTRIES', 3), patch.object(scanner.os, 'scandir', tracked_scandir):
                result = scanner.scan(str(folder))
            self.assertEqual(len(result), 3)
            self.assertEqual(len(enumerated), 3, 'the cap must apply before materializing entries')

    def test_cli_flat_flag(self):
        with tempfile.TemporaryDirectory(prefix='qr04w-scan-', dir=os.environ['TMPDIR']) as temp:
            folder = Path(temp)
            (folder / 'top.jpg').write_bytes(b'test')
            (folder / 'nested').mkdir()
            (folder / 'nested' / 'deep.png').write_bytes(b'test')
            run = subprocess.run([sys.executable, str(SCRIPT), str(folder), '--flat'],
                                 capture_output=True, text=True, check=True)
            self.assertEqual(json.loads(run.stdout), [str(folder / 'top.jpg')])

    def test_symlink_folder_is_not_followed(self):
        with tempfile.TemporaryDirectory(prefix='qr04w-scan-', dir=os.environ['TMPDIR']) as temp:
            folder = Path(temp)
            outside = folder / 'outside'
            outside.mkdir()
            (outside / 'private.jpg').write_bytes(b'test')
            link = folder / 'wall'
            link.symlink_to(outside, target_is_directory=True)
            with self.assertRaises(NotADirectoryError):
                scanner.scan(str(link))
            run = subprocess.run([sys.executable, str(SCRIPT), str(link)],
                                 capture_output=True, text=True)
            self.assertNotEqual(run.returncode, 0)
            self.assertEqual(json.loads(run.stdout), [])

    def test_missing_folder_reports_error_and_empty_json(self):
        with tempfile.TemporaryDirectory(prefix='qr04w-scan-', dir=os.environ['TMPDIR']) as temp:
            run = subprocess.run([sys.executable, str(SCRIPT), str(Path(temp) / 'missing')],
                                 capture_output=True, text=True)
            self.assertNotEqual(run.returncode, 0)
            self.assertEqual(json.loads(run.stdout), [])


if __name__ == '__main__':
    unittest.main()
