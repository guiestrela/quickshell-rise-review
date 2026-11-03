#!/usr/bin/env python3
"""Authentication cache failures must not prevent independent CLI probes."""
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

API = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'scripts/rise-ai-auth-status'))


class AuthCacheTests(unittest.TestCase):
    def test_malformed_counters_fall_back_to_cli(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            cache = home / '.local/state/omarchy/agents/usage/codex.json'
            cache.parent.mkdir(parents=True)
            for value in ('invalid', {}, [1], float('inf'), None):
                with self.subTest(value=value):
                    cache.write_text(json.dumps({'totalPrompts': value}))
                    with patch('pathlib.Path.home', return_value=home), \
                            patch('shutil.which', return_value='/fixture/codex'), \
                            patch('subprocess.run') as run:
                        run.return_value.returncode = 0
                        run.return_value.stdout = 'Logged in'
                        run.return_value.stderr = ''
                        self.assertEqual(API['probe']('codex'), ('codex', True))
                        run.assert_called_once()

    def test_valid_counter_after_invalid_counter_is_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            cache = home / '.local/state/omarchy/agents/usage/codex.json'
            cache.parent.mkdir(parents=True)
            cache.write_text(json.dumps({'totalPrompts': {}, 'totalSessions': '2'}))
            with patch('pathlib.Path.home', return_value=home), patch('subprocess.run') as run:
                self.assertEqual(API['probe']('codex'), ('codex', True))
                run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
