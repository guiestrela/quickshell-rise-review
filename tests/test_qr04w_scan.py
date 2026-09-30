"""QR-04W: real folder scan stays within a tree and honors recursion."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'versions/V1/integrations/wallpaper-scan.py'
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
            self.assertEqual(scanner.scan(str(link)), [])


if __name__ == '__main__':
    unittest.main()
