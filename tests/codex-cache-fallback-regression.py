#!/usr/bin/env python3
"""Exercise collector main with isolated cache and controlled data boundaries."""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from typing import Any

SCRIPT = Path(sys.argv.pop(1)) if len(sys.argv) > 1 and not sys.argv[1].startswith('-') else Path(__file__).resolve().parents[1] / 'scripts/codex-usage'
loader = importlib.machinery.SourceFileLoader('codex_collector', str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
mod: Any = importlib.util.module_from_spec(spec)
loader.exec_module(mod)

class CacheFallbackTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR'))
        self.addCleanup(self.temp.cleanup)
        mod.CACHE_FILE = Path(self.temp.name) / 'usage.json'
        mod.fetch_env = lambda: None
        mod.fetch_rpc = lambda: None
        mod.scan_activity = lambda: (0, 0, {})
        mod.supplement_missing_general_windows_from_sessions = lambda *args: None
        self.old = {'schemaVersion': 3, '_source': 'rpc', '5h-utilization': '0.5100',
                    'windows': [{'kind':'primary', 'minutes':300, 'label':'5h',
                                 'utilization':0.51, 'reset':1790818276}]}
        self.rollout = {'source':'rollout', 'plan':'plus', 'rateLimits':{
            'limitId':'codex', 'primary':{'usedPercent':12,'windowDurationMins':300,
                                        'resetsAt':1790818276}}}
        mod.fetch_rollout = lambda: self.rollout

    def test_rpc_failure_does_not_replace_existing_usage_with_old_rollout(self):
        mod.CACHE_FILE.write_text(json.dumps(self.old))
        mod.main()
        actual = json.loads(mod.CACHE_FILE.read_text())
        self.assertEqual(actual['windows'], self.old['windows'])
        self.assertEqual(actual['5h-utilization'], '0.5100')
        self.assertEqual(actual['_source'], 'stale')

    def test_missing_cache_can_bootstrap_from_rollout(self):
        mod.main()
        actual = json.loads(mod.CACHE_FILE.read_text())
        self.assertEqual(actual['5h-utilization'], '0.1200')
        self.assertEqual(actual['_source'], 'rollout')

    def test_live_rpc_can_update_usage_downward(self):
        mod.CACHE_FILE.write_text(json.dumps(self.old))
        fresh = dict(self.rollout, source='rpc')
        mod.fetch_rpc = lambda: fresh
        mod.main()
        actual = json.loads(mod.CACHE_FILE.read_text())
        self.assertEqual(actual['5h-utilization'], '0.1200')
        self.assertEqual(actual['_source'], 'rpc')

    def test_all_sources_unavailable_preserves_last_value(self):
        mod.CACHE_FILE.write_text(json.dumps(self.old))
        mod.fetch_rollout = lambda: None
        mod.main()
        actual = json.loads(mod.CACHE_FILE.read_text())
        self.assertEqual(actual['windows'], self.old['windows'])
        self.assertEqual(actual['_source'], 'stale')

if __name__ == '__main__':
    unittest.main()
