#!/usr/bin/env python3
"""Restricted notification action tests; never launch an agent or use real journal data."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'versions/V1/integrations/notification-crash-action.py'
BOOT = 'a' * 32


def load_helper():
    assert HELPER.exists(), 'Missing safe dispatcher for the selected crash notification'
    spec = importlib.util.spec_from_file_location('crash_action', HELPER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def record(pid='1080', exe='/usr/bin/gnome-keyring-daemon', timestamp='2000000000000'):
    return {'MESSAGE_ID': 'fc2e22bc6ee647b6b90729ab34a250b1',
            '_EXE': '/usr/lib/systemd/systemd-coredump',
            '_SYSTEMD_UNIT': 'systemd-coredump@1-2-3.service', '_BOOT_ID': BOOT,
            'COREDUMP_UID': '1000', 'COREDUMP_PID': pid,
            'COREDUMP_COMM': 'gnome-keyring-d', 'COREDUMP_EXE': exe,
            'COREDUMP_SIGNAL_NAME': 'SIGABRT', '__REALTIME_TIMESTAMP': timestamp,
            '__CURSOR': 'fixture-cursor-' + pid}


def entry(timestamp=2000000001):
    return {'backend': 'omarchy', 'appName': 'omarchy-action',
            'summary': 'Process crashed: gnome-keyring-daemon',
            'body': 'Click to diagnose with AI', 'timestamp': timestamp, 'id': 58}


class CrashAction(unittest.TestCase):
    def test_journal_limit_cannot_hide_ambiguity_or_reused_pid(self):
        from types import SimpleNamespace
        from unittest.mock import patch
        import json
        mod = load_helper()
        # Journal must return a sentinel record beyond its accepted bound.
        rows = [record('1080')]
        for pid in range(2000, 2511):
            rows.append(record(str(pid), '/usr/bin/other'))
        latest = record('1080'); latest['__CURSOR'] = 'new-crash-same-pid'
        rows.append(latest)
        def journal(argv, **kwargs):
            limit = int(argv[argv.index('-n') + 1])
            return SimpleNamespace(returncode=0, stdout='\n'.join(json.dumps(r) for r in rows[-limit:]))
        with patch.object(mod.subprocess, 'run', side_effect=journal):
            with self.assertRaises(mod.ActionUnavailable):
                mod.read_journal(1000)

    def test_legacy_history_requires_unique_current_boot_record(self):
        mod = load_helper()
        old = entry(0)
        self.assertTrue(mod.plan_action(old, [record()], 1000, BOOT)['legacy'])
        with self.assertRaises(mod.ActionUnavailable):
            mod.plan_action(old, [record(), record('1081')], 1000, BOOT)

    def test_reject_untrusted_record_uid_boot_exe_signal_and_control_chars(self):
        mod = load_helper()
        for field, value in [('_BOOT_ID', 'b'*32), ('COREDUMP_UID', '1001'),
                             ('_EXE', '/usr/bin/logger'), ('_SYSTEMD_UNIT', 'fake.service'),
                             ('COREDUMP_SIGNAL_NAME', 'SIGABRT;id'), ('COREDUMP_COMM', 'a\n b')]:
            bad = record(); bad[field] = value
            with self.subTest(field=field), self.assertRaises(mod.ActionUnavailable):
                mod.plan_action(entry(), [bad], 1000, BOOT)

    def test_reject_unknown_callback_and_divergent_reference(self):
        mod = load_helper()
        for extension in [{'actionKind': 'unknown'}, {'execArgv': ['/bin/sh', '-c', 'id']},
                          {'crashReference': {'pid': '999', 'comm': 'fake', 'exe': '/bin/sh', 'signal': 'SIGABRT'}}]:
            with self.subTest(extension=extension), self.assertRaises(mod.ActionUnavailable):
                mod.plan_action(dict(entry(), **extension), [record()], 1000, BOOT)

    def test_timestamp_and_pid_reuse_rejected(self):
        mod = load_helper()
        with self.assertRaises(mod.ActionUnavailable):
            mod.plan_action(entry(1000), [record()], 1000, BOOT)
        later = record(timestamp='1000000000000'); later['__CURSOR'] = 'same-pid-other-event'
        with self.assertRaises(mod.ActionUnavailable):
            mod.plan_action(entry(), [record(), later], 1000, BOOT)

    def test_no_record_or_other_app_cannot_open(self):
        mod = load_helper()
        with self.assertRaises(mod.ActionUnavailable):
            mod.plan_action(entry(), [], 1000, BOOT)
        with self.assertRaises(mod.ActionUnavailable):
            mod.plan_action(dict(entry(), appName='other'), [record()], 1000, BOOT)

    def test_one_time_claim_survives_another_item_and_elapsed_time(self):
        import tempfile
        from unittest.mock import patch
        mod = load_helper()
        calls = []
        with tempfile.TemporaryDirectory() as state:
            plan = mod.plan_action(entry(), [record()], 1000, BOOT)
            mod.launch_action(plan, state, executor=lambda argv: calls.append(argv))
            mod.launch_action(dict(plan, cursor='another-valid-record'), state, executor=lambda argv: calls.append(argv))
            with patch.object(mod.time, 'monotonic', return_value=1e12):
                with self.assertRaises(mod.ActionUnavailable):
                    mod.launch_action(plan, state, executor=lambda argv: calls.append(argv))
            self.assertEqual(len(calls), 2)

    def test_failed_launcher_is_not_claimed(self):
        import tempfile
        mod = load_helper()
        plan = mod.plan_action(entry(), [record()], 1000, BOOT)
        with tempfile.TemporaryDirectory() as state:
            def fail(argv): raise OSError('fixture launch failed')
            with self.assertRaises(OSError): mod.launch_action(plan, state, executor=fail)
            calls=[]
            mod.launch_action(plan, state, executor=lambda argv: calls.append(argv))
            self.assertEqual(len(calls), 1)

    def test_malicious_notification_cannot_supply_command(self):
        mod = load_helper()
        bad=entry(); bad['summary']='Process crashed: x; touch /tmp/unsafe'
        with self.assertRaises(mod.ActionUnavailable):
            mod.plan_action(bad, [record()], 1000, BOOT)

    def test_selected_crash_uses_fixed_command_and_authoritative_record(self):
        mod = load_helper()
        result = mod.plan_action(entry(), [record(), record('99', '/usr/bin/other')], 1000, BOOT)
        self.assertEqual(result['argv'], ['/usr/bin/omarchy-agent-crash', '1080',
                         'gnome-keyring-d', '/usr/bin/gnome-keyring-daemon', 'SIGABRT'])
        self.assertEqual(result['cursor'], 'fixture-cursor-1080')


if __name__ == '__main__':
    unittest.main()
