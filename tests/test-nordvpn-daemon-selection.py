#!/usr/bin/env python3
"""Fixture-only validation of the fixed, read-only NordVPN Settings RPC."""
import importlib.machinery
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
import os
import shutil
import subprocess
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'scripts/rise-nordvpn-selection'
assert HELPER.is_file(), 'Read-only selection helper must exist'
loader = importlib.machinery.SourceFileLoader('rise_nordvpn_selection', str(HELPER))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
helper = importlib.util.module_from_spec(spec)
loader.exec_module(helper)

def varint(value):
    result = bytearray()
    while value >= 128:
        result.append((value & 127) | 128); value >>= 7
    result.append(value)
    return bytes(result)

def message(technology=2, protocol=1, code=1000):
    settings = b'\x08' + varint(technology) + b'\x60' + varint(protocol)
    payload = b'\x08' + varint(code) + b'\x12' + varint(len(settings)) + settings
    return b'\0' + len(payload).to_bytes(4, 'big') + payload

class SelectionTests(unittest.TestCase):
    def test_confirmed_daemon_selection(self):
        self.assertEqual(helper.decode_selection(message()), {'schema': 1, 'technology': 'NORDLYNX', 'protocol': 'UDP'})
        self.assertEqual(helper.decode_selection(message(1, 2))['protocol'], 'TCP')
        self.assertEqual(helper.decode_selection(message(3, 3))['protocol'], '')

    def test_malformed_frames_fail_closed(self):
        for raw in [b'', b'\0'*4, b'\1'+message()[1:], message()[:-1], message()+b'extra', b'\0\0\0\0\1\xff']:
            with self.subTest(raw=raw), self.assertRaises(ValueError): helper.decode_selection(raw)

    def test_unknown_or_failed_responses_never_guess(self):
        for raw in [message(code=1001), message(technology=0), message(technology=99), message(protocol=0), message(protocol=99), message(technology=1,protocol=3)]:
            with self.subTest(raw=raw), self.assertRaises(ValueError): helper.decode_selection(raw)

    def test_only_the_fixed_local_readonly_rpc_is_called(self):
        calls = []
        def run(argv, **kwargs):
            calls.append(argv)
            self.assertEqual(argv[:2], ['curl', '-q'], 'Disable default curlrc before any other curl option')
            self.assertEqual(argv[-1], 'http://localhost/pb.Daemon/Settings')
            self.assertEqual(argv[argv.index('--unix-socket')+1], '/run/nordvpn/nordvpnd.sock')
            self.assertEqual(kwargs['input'], b'\0'*5)
            self.assertIn('--noproxy', argv)
            Path(argv[argv.index('--dump-header')+1]).write_text('HTTP/2 200\ncontent-type: application/grpc\n\ngrpc-status: 0\n')
            Path(argv[argv.index('--output')+1]).write_bytes(message())
            return SimpleNamespace(returncode=0, stderr=b'')
        self.assertEqual(helper.read_selection(run)['technology'], 'NORDLYNX')
        self.assertEqual(len(calls), 1)

    @unittest.skipUnless(shutil.which('curl'), 'curl is required for the local curlrc fixture')
    def test_hostile_default_curlrc_cannot_add_a_transfer(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR')) as directory:
            home = Path(directory)
            source, leaked = home / 'fixture', home / 'extra-transfer'
            source.write_text('fixture-only')
            (home / '.curlrc').write_text(f'url = "{source.as_uri()}"\noutput = "{leaked}"\nnext\n')
            def run(argv, **kwargs):
                safe = list(argv)
                # No real socket or network, and no dependency on curl's HTTP/2 build.
                safe.remove('--http2-prior-knowledge')
                safe[safe.index('--unix-socket') + 1] = str(home / 'absent.sock')
                control = [arg for arg in safe if arg != '-q']
                subprocess.run(control, **kwargs)
                self.assertEqual(leaked.read_text(), 'fixture-only', 'positive control must load hostile curlrc')
                leaked.unlink()
                result = subprocess.run(safe, **kwargs)
                self.assertFalse(leaked.exists(), 'default curlrc created an independent transfer')
                return result
            with patch.dict(os.environ, {'HOME': directory, 'CURL_HOME': directory, 'XDG_CONFIG_HOME': directory}):
                with self.assertRaises(ValueError):
                    helper.read_selection(run)

    def test_rpc_errors_are_not_reported_as_selection(self):
        def run(argv, **kwargs):
            Path(argv[argv.index('--dump-header')+1]).write_text('HTTP/2 200\ngrpc-status: 7\n')
            Path(argv[argv.index('--output')+1]).write_bytes(message())
            return SimpleNamespace(returncode=0, stderr=b'')
        with self.assertRaises(ValueError): helper.read_selection(run)

if __name__ == '__main__': unittest.main()
