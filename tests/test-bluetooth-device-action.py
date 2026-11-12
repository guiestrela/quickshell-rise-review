#!/usr/bin/env python3
"""Regression checks for controller resolution; never access real Bluetooth."""
import contextlib
import io
from pathlib import Path
import runpy
import subprocess
import unittest
from unittest.mock import patch

HELPER = Path(__file__).resolve().parents[1] / 'scripts/rise-bluetooth-device-action'
CONTROLLER = '00:11:22:33:44:55'
DEVICE = 'AA:BB:CC:DD:EE:FF'


class ControllerSelection(unittest.TestCase):
    def test_resolves_hci_identifier_before_selecting_controller(self):
        calls = []
        def fake_run(command, **kwargs):
            calls.append((command, kwargs))
            if command[0] == '/usr/bin/busctl':
                return subprocess.CompletedProcess(command, 0, 's "' + CONTROLLER + '"\n', '')
            script = kwargs.get('input', '')
            if 'select hci0\n' in script:
                return subprocess.CompletedProcess(command, 0, 'Controller hci0 not available\n', '')
            return subprocess.CompletedProcess(command, 0, 'Connected: no\n', '')
        module = runpy.run_path(str(HELPER), run_name='helper_test')
        with patch('sys.argv', [str(HELPER), 'info', 'hci0', DEVICE]), patch('subprocess.run', side_effect=fake_run), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            result = module['main']()
        self.assertEqual(result, 0, 'hci0 must resolve to the actual controller address')
        self.assertEqual(calls[0][0][-3:], ['/org/bluez/hci0', 'org.bluez.Adapter1', 'Address'])
        self.assertEqual(calls[-1][1]['input'], f'select {CONTROLLER}\ninfo {DEVICE}\nquit\n')


    def test_connect_waits_for_device_method_instead_of_quitting_cli(self):
        module = runpy.run_path(str(HELPER), run_name='helper_test')
        calls = []
        def fake_run(command, **kwargs):
            calls.append(command)
            if 'get-property' in command:
                return subprocess.CompletedProcess(command, 0, f's "{CONTROLLER}"\n', '')
            return subprocess.CompletedProcess(command, 0, '', '')
        with patch('sys.argv', [str(HELPER), 'connect', 'hci0', DEVICE]), patch('subprocess.run', side_effect=fake_run), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(module['main'](), 0)
        self.assertEqual(calls[-1][-3:], ['/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF', 'org.bluez.Device1', 'Connect'])
        self.assertEqual(calls[-1][0], '/usr/bin/busctl')
        self.assertIn('call', calls[-1])

    def test_unresolved_controller_never_runs_a_device_action(self):
        module = runpy.run_path(str(HELPER), run_name='helper_test')
        failures = [
            subprocess.CompletedProcess([], 1, '', 'No such object'),
            subprocess.CompletedProcess([], 0, 's "invalid"\n', ''),
            subprocess.TimeoutExpired('busctl', 6),
            FileNotFoundError('busctl'),
        ]
        for failure in failures:
            with self.subTest(failure=type(failure).__name__):
                with patch('sys.argv', [str(HELPER), 'connect', 'hci7', DEVICE]), patch('subprocess.run', side_effect=[failure]) as run, contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                    self.assertNotEqual(module['main'](), 0)
                self.assertEqual(run.call_count, 1)
                self.assertIn('/org/bluez/hci7', run.call_args.args[0])

    def test_invalid_adapter_is_rejected_without_subprocesses(self):
        module = runpy.run_path(str(HELPER), run_name='helper_test')
        with patch('sys.argv', [str(HELPER), 'connect', 'hci0\nquit', DEVICE]), patch('subprocess.run') as run, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(module['main'](), 2)
            run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
