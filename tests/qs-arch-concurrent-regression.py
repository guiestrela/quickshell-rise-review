#!/usr/bin/env python3
"""Exercise concurrent checker processes with a locked repository seam."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ParallelChecks(unittest.TestCase):
    def test_updating_property_exists_in_both_themes(self):
        for theme in ['versions/V1/Theme.qml', 'versions/V1/variants/V2/Theme.qml']:
            with self.subTest(theme=theme):
                self.assertRegex((ROOT / theme).read_text(), r'property bool archRefreshing:\s*false',
                                 'Widget cannot publish the updating state to its Theme')

    def test_concurrent_scans_have_separate_repository_databases(self):
        with tempfile.TemporaryDirectory(prefix='arch-parallel-', dir=os.environ['TMPDIR']) as d:
            base = Path(d)
            tools = base / 'bin'
            tools.mkdir()
            checker = tools / 'checkupdates'
            checker.write_text('''#!/usr/bin/env bash
set -eu
db="${CHECKUPDATES_DB:-${TMPDIR}/checkup-db-${UID}}"
mkdir -p "$db"
exec 9>"$db/fixture.lock"
flock -n 9 || { echo 'Cannot fetch updates: database locked' >&2; exit 1; }
sleep 0.5
exit 2
''')
            checker.chmod(0o755)
            def scan(i):
                env = dict(os.environ, TMPDIR=str(base), PATH=str(tools)+':'+os.environ['PATH'],
                           QS_ARCH_SKIP_AUR='1', QS_ARCH_UPDATE_STATE=str(base/f'state-{i}.json'))
                env.pop('CHECKUPDATES_DB', None)
                return subprocess.run(['bash', str(ROOT/'scripts/qs-arch-update-check.sh')],
                                      env=env, capture_output=True, text=True, timeout=10)
            with ThreadPoolExecutor(max_workers=3) as workers:
                results = list(workers.map(scan, range(3)))
            self.assertEqual([r.returncode for r in results], [0,0,0],
                             'Concurrent Refresh failed: '+repr([r.stderr for r in results]))
            self.assertTrue(all(r.stdout.startswith('M|') for r in results))

if __name__ == '__main__':
    unittest.main()
