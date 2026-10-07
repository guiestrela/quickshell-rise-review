#!/usr/bin/env python3
"""Screenshot action fixtures: no GUI editor or crash agent is executed."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

def module():
    spec = importlib.util.spec_from_file_location('actions', ROOT/'versions/V1/integrations/notification-crash-action.py')
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

class ScreenshotAction(unittest.TestCase):
    def test_cli_check_opens_only_selected_plan_without_a_journal(self):
        import subprocess
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as tmp:
            home = Path(tmp)
            state = home/'.local/state/omarchy/notifications'; state.mkdir(parents=True)
            pictures = home/'Pictures'; pictures.mkdir()
            capture = pictures/'screenshot-2026-10-07_10-22-44.png'
            capture.write_bytes(b'\x89PNG\r\n\x1a\nfixture')
            entry = {'backend':'omarchy','id':7,'timestamp':1791379364613,
                     'appName':'omarchy-action','summary':'Screenshot saved to clipboard and file',
                     'body':'Edit with Super + Alt + , (or click this)', 'actionKind':'unsupported'}
            row = {'id':7,'originalId':7,'timestamp':entry['timestamp'],'app':entry['appName'],
                   'summary':entry['summary'],'body':entry['body'],
                   'execArgv':json.dumps(['tensaku-edit',str(capture)])}
            (state/f'{entry["timestamp"]}-7.json').write_text(json.dumps(row))
            env = dict(os.environ, HOME=str(home), XDG_STATE_HOME=str(home/'.local/state'))
            run = subprocess.run(['python3', str(ROOT/'versions/V1/integrations/notification-crash-action.py'),
                                  '--check','--entry',json.dumps(entry)],
                                 env=env, capture_output=True,text=True,timeout=4)
            self.assertEqual(run.returncode,0,run.stdout+run.stderr)
            self.assertEqual(json.loads(run.stdout)['action'],'screenshot-edit')

    def test_selected_screenshot_uses_fixed_editor(self):
        mod = module()
        self.assertTrue(hasattr(mod, 'plan_screenshot_action'), 'Screenshot dispatcher is missing')
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as tmp:
            state = Path(tmp)/'notifications'; state.mkdir()
            pictures = Path(tmp)/'Pictures'; pictures.mkdir()
            capture = pictures/'screenshot-2026-10-07_10-22-44.png'
            capture.write_bytes(b'\x89PNG\r\n\x1a\n' + b'fixture')
            entry = {'backend':'omarchy','id':7,'timestamp':1791379364613,
                     'appName':'omarchy-action','summary':'Screenshot saved to clipboard and file',
                     'body':'Edit with Super + Alt + , (or click this)', 'actionKind':'unsupported'}
            row = {'originalId':7, 'timestamp':entry['timestamp'], 'app':entry['appName'],
                   'summary':entry['summary'],'body':entry['body'],
                   'execArgv':json.dumps(['tensaku-edit',str(capture)])}
            record = state/f'{entry["timestamp"]}-7.json'; record.write_text(json.dumps(row))
            self.assertEqual(mod.plan_screenshot_action(entry,state,pictures)['argv'],
                             ['/usr/bin/tensaku-edit',str(capture)])
            for bad in [['bash','-c'], ['tensaku-edit',str(Path(tmp)/capture.name)],
                        ['tensaku-edit',str(capture),'extra'], ['tensaku-edit','--help']]:
                with self.subTest(callback=bad):
                    row['execArgv'] = json.dumps(bad); record.write_text(json.dumps(row))
                    with self.assertRaises(mod.ActionUnavailable):
                        mod.plan_screenshot_action(entry,state,pictures)
            row['execArgv'] = json.dumps(['tensaku-edit',str(capture)])
            row['timestamp'] += 1; record.write_text(json.dumps(row))
            with self.assertRaises(mod.ActionUnavailable):
                mod.plan_screenshot_action(entry,state,pictures)
            row['timestamp'] -= 1; record.write_text(json.dumps(row))
            capture.unlink(); capture.symlink_to(record)
            with self.assertRaises(OSError):
                mod.plan_screenshot_action(entry,state,pictures)
            capture.unlink(); capture.write_bytes(b'not a PNG fixture')
            with self.assertRaises(mod.ActionUnavailable):
                mod.plan_screenshot_action(entry,state,pictures)
            capture.unlink(); os.mkfifo(capture)
            with self.assertRaises(mod.ActionUnavailable):
                mod.plan_screenshot_action(entry,state,pictures)

    def test_editor_failure_is_not_reported_as_success(self):
        from unittest.mock import patch
        mod = module()
        with patch.object(mod.subprocess, 'Popen') as spawn:
            spawn.return_value.wait.return_value = 1
            with self.assertRaises(mod.ActionUnavailable):
                mod.launch_screenshot_action({'argv':['/usr/bin/tensaku-edit','/fixture/image.png']})

if __name__ == '__main__':
    unittest.main()
