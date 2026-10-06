#!/usr/bin/env python3
"""Exercise real pipe framing without Codex, credentials, or network."""
from typing import Any
import json
from pathlib import Path
import runpy
import subprocess
import sys
import unittest

SCRIPT = Path(sys.argv.pop(1)) if len(sys.argv) > 1 and not sys.argv[1].startswith('-') else Path(__file__).resolve().parents[1] / 'scripts/codex-usage'
collector = runpy.run_path(str(SCRIPT))

class RpcPipeTest(unittest.TestCase):
    def request(self, child, request_id=1):
        proc: Any = subprocess.Popen([sys.executable, '-u', '-c', child], stdin=subprocess.PIPE,
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        # Let the regression exercise both the old text writes and new bytes
        # writes while retaining real pipe buffering on stdout.
        class CompatibleInput:
            def write(self, data):
                return stdin.write(data.encode('utf-8') if isinstance(data, str) else data)
            def flush(self):
                stdin.flush()
            def close(self):
                stdin.close()
        stdin = proc.stdin
        proc.stdin = CompatibleInput()
        self.addCleanup(self.close, proc)
        return proc, collector['rpc_request'](proc, request_id, 'probe', timeout=0.8)

    @staticmethod
    def close(proc):
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill(); proc.wait()
        proc.stdin.close(); proc.stdout.close()

    def test_notification_and_response_in_one_write(self):
        _, result = self.request('import os,sys; sys.stdin.readline(); os.write(1,b\'{"method":"notice"}\\n{"id":1,"result":{"fresh":true}}\\n\'); sys.stdin.readline()')
        self.assertTrue(result['result']['fresh'])

    def test_partial_line_arrives_in_multiple_writes(self):
        _, result = self.request('import os,sys,time; sys.stdin.readline(); os.write(1,b\'{"id":1,\'); time.sleep(0.05); os.write(1,b\'"result":{"fresh":true}}\\n\'); sys.stdin.readline()')
        self.assertTrue(result['result']['fresh'])

    def test_buffer_preserved_for_next_request(self):
        proc, result = self.request('import os,sys; sys.stdin.readline(); os.write(1,b\'{"id":1,"result":{}}\\n{"id":2,"result":{"fresh":true}}\\n\'); sys.stdin.readline(); sys.stdin.readline()')
        self.assertEqual(result['id'], 1)
        second = collector['rpc_request'](proc, 2, 'probe', timeout=0.8)
        self.assertTrue(second['result']['fresh'])

    def test_silent_peer_times_out(self):
        with self.assertRaises(TimeoutError):
            self.request('import sys,time; sys.stdin.readline(); time.sleep(3)')

if __name__ == '__main__':
    unittest.main()
