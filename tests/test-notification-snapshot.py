#!/usr/bin/env python3
"""Malformed notification rows must not hide valid independent notifications."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'shared/integrations/notification-snapshot.py'
spec = importlib.util.spec_from_file_location('notification_snapshot', SCRIPT)
snapshot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(snapshot)


class SnapshotTests(unittest.TestCase):
    def test_native_non_object_records_are_skipped(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for index, value in enumerate(([], None, 'invalid', 123, False)):
                (folder / f'bad-{index}.json').write_text(json.dumps(value))
            (folder / 'valid.json').write_text(json.dumps({'id': 42, 'summary': 'Retained'}))
            (folder / 'broken.json').write_text('{')
            rows = snapshot.read_entries(folder, False)
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]['id'], 42)
            self.assertEqual(rows[0]['summary'], 'Retained')
            self.assertFalse(rows[0]['active'])

    def test_mako_non_object_records_are_skipped(self):
        reply = subprocess.CompletedProcess([], 0, json.dumps([None, [], 5, {'id': 7}]), '')
        with patch.object(snapshot.subprocess, 'run', return_value=reply), \
                patch.object(snapshot, 'process_token', return_value='fixture'):
            result = snapshot.mako_snapshot()
        self.assertEqual([r['id'] for r in result['list']], [7])
        self.assertEqual([r['id'] for r in result['history']], [7])
        self.assertTrue(result['list'][0]['active'])
        self.assertFalse(result['history'][0]['active'])

    def test_process_token_handles_spaces_and_parentheses_in_comm(self):
        for comm in ('mako', 'omarchy shell', 'worker (panel) name'):
            with self.subTest(comm=comm):
                fields = ['S'] + ['0'] * 18 + ['987654'] + ['0'] * 5
                stat = f'123 ({comm}) ' + ' '.join(fields)
                with patch.object(snapshot.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '123\n', '')), \
                        patch.object(Path, 'read_text', side_effect=[stat, 'boot-id\n']):
                    self.assertEqual(snapshot.process_token('fixture'), 'boot-id-123-987654')

    def test_incomplete_proc_stat_returns_no_token(self):
        with patch.object(snapshot.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '123\n', '')), \
                patch.object(Path, 'read_text', return_value='incomplete'):
            self.assertEqual(snapshot.process_token('fixture'), '')


if __name__ == '__main__':
    unittest.main()
