#!/usr/bin/env python3
"""Check both OpenCode message schemas against the same usage contract."""
import json
import runpy
import sqlite3
import unittest
from pathlib import Path

collector = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'scripts/opencode-usage'))


class OpenCodeUsageTest(unittest.TestCase):
    def test_schemas(self):
        for modern in (False, True):
            with self.subTest(modern=modern):
                con = sqlite3.connect(':memory:')
                self.addCleanup(con.close)
                table = 'session_message' if modern else 'message'
                con.execute(f'create table {table} (session_id text, time_created integer, time_updated integer, data text' + (', type text)' if modern else ')'))
                data = {'tokens': {'input': 100, 'output': 20, 'reasoning': 5, 'cache': {'read': 200, 'write': 10}}, 'cost': 0.25}
                data.update({'model': {'id': 'test-model', 'providerID': 'test-provider'}} if modern else {'role': 'assistant', 'modelID': 'test-model', 'providerID': 'test-provider'})
                def insert(payload, role, timestamp):
                    values = ['session', timestamp, timestamp, json.dumps(payload)] + ([role] if modern else [])
                    con.execute(f'insert into {table} values ({",".join("?" for _ in values)})', values)
                insert(data, 'assistant', 2000)
                insert({'role': 'user'}, 'user', 3000)
                insert(data, 'assistant', 500)
                self.assertEqual(collector['sum_since'](con, 1000), (135, 0.25, 335))
                self.assertEqual(collector['newest_model'](con), 'test-model (test-provider)')
                rows = collector['model_rows'](con, 1000)
                self.assertEqual(len(rows), 1)
                self.assertEqual(rows[0]['total'], 270)
                self.assertEqual(rows[0]['todayLabel'], '135')
                self.assertEqual(rows[0]['sessions'], 1)


if __name__ == '__main__':
    unittest.main()
