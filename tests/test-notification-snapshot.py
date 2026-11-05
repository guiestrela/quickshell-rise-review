#!/usr/bin/env python3
"""Malformed notification rows must not hide valid independent notifications."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import time
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'shared/integrations/notification-snapshot.py'
spec = importlib.util.spec_from_file_location('notification_snapshot', SCRIPT)
snapshot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(snapshot)


class SnapshotTests(unittest.TestCase):
    def test_modern_store_identity_timestamps_and_retention(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            folder = state / 'notifications'
            folder.mkdir()
            now = time.time()
            row = dict(key='native-one', originalId=7, ts=now, app='Fixture', summary='One', body='Body')
            (folder / 'live.json').write_text(json.dumps([None, row, row]))
            second = dict(row, key='native-two', summary='Two', closed_ts=now)
            expired = dict(second, key='expired', closed_ts=now-90000)
            (folder / 'history.json').write_text(json.dumps([second, expired]))
            with patch.object(snapshot, 'process_token', side_effect=AssertionError('Modern keys survive daemon restarts')):
                result = snapshot.omarchy_snapshot(state)
            self.assertTrue(result['valid'])
            self.assertTrue(result['store'])
            self.assertEqual([r['sourceKey'] for r in result['list']], ['native-one'])
            self.assertEqual([r['sourceKey'] for r in result['history']], ['native-two'])
            self.assertEqual(result['history'][0]['id'], 7)
            self.assertEqual(result['list'][0]['timestamp'], round(now*1000))

    def test_modern_empty_store_does_not_fall_back_to_mako(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            folder = state / 'notifications'
            folder.mkdir()
            (folder / 'quiet.json').write_text('{"dnd":false}')
            result = snapshot.omarchy_snapshot(state)
            self.assertTrue(result['valid'])
            self.assertEqual(result['list'], [])
            self.assertEqual(result['history'], [])

    def test_modern_invalid_document_is_not_an_authoritative_empty_history(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            folder = state / 'notifications'
            folder.mkdir()
            for document in ('{', '{}', 'null', '"invalid"'):
                (folder / 'live.json').write_text(document)
                self.assertFalse(snapshot.omarchy_snapshot(state)['valid'])

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
