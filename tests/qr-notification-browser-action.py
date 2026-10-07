#!/usr/bin/env python3
"""Focused Chromium fallback tests. Never focus a real window here."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('actions', ROOT/'versions/V1/integrations/notification-crash-action.py')
assert spec and spec.loader
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)

class BrowserAction(unittest.TestCase):
    def test_cli_lists_choices_without_focusing(self):
        from unittest.mock import patch
        from io import StringIO
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as tmp:
            state = Path(tmp)/'omarchy/notifications'; (state/'history').mkdir(parents=True)
            entry = {'backend':'omarchy','id':9,'timestamp':12345,'appName':'Chromium',
                     'summary':'Fixture','body':'No URL callback','actionKind':'unsupported'}
            (state/'history/12345-9.json').write_text(json.dumps({'originalId':9,'timestamp':12345,
                'app':'Chromium','summary':entry['summary'],'body':entry['body'],'execArgv':''}))
            clients = [{'address':'0x123','pid':100,'class':'chromium','mapped':True,'title':'Fixture window'}]
            out = StringIO()
            with patch.dict(os.environ,{'XDG_STATE_HOME':tmp}), patch('sys.argv',['helper','--check','--entry',json.dumps(entry)]), patch.object(mod,'hypr_query',return_value=clients), patch.object(mod,'focus_browser_window',side_effect=AssertionError('No auto focus')), patch('sys.stdout',out):
                self.assertEqual(mod.main(),0,out.getvalue())
            self.assertEqual(json.loads(out.getvalue())['chooseWindow'],True)

    def test_expired_entry_requires_explicit_window_choice(self):
        self.assertTrue(hasattr(mod, 'browser_windows'), 'Chromium fallback is missing')
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as tmp:
            state = Path(tmp); (state/'history').mkdir()
            entry = {'backend':'omarchy','id':9,'timestamp':12345,'appName':'Chromium',
                     'summary':'Fixture browser alert','body':'https://not-a-command.invalid',
                     'actionKind':'unsupported'}
            row = {'originalId':9,'timestamp':12345,'app':'Chromium',
                   'summary':entry['summary'],'body':entry['body'],'execArgv':''}
            (state/'history/12345-9.json').write_text(json.dumps(row))
            clients = [{'address':'0x123','pid':100,'class':'chromium','mapped':True,'title':'First'},
                       {'address':'0x456','pid':101,'class':'chromium','mapped':True,'title':'Second'},
                       {'address':'0x789','pid':102,'class':'evilchromium','mapped':True,'title':'Not browser'}]
            self.assertEqual([w['address'] for w in mod.browser_windows(entry,state,clients)],['0x123','0x456'])
            self.assertEqual(mod.browser_focus_target(entry,state,clients,{'address':'0x456','pid':101})['pid'],101)
            for selection in [{'address':'0x456','pid':999}, {'address':'0x789','pid':102},
                              {'address':'0x123;exec bad','pid':100}, {'address':'0x123','pid':True},
                              {'address':'0x123','pid':100,'exec':'bad'}]:
                with self.subTest(selection=selection), self.assertRaises(mod.ActionUnavailable):
                    mod.browser_focus_target(entry,state,clients,selection)
            row['timestamp'] += 1; (state/'history/12345-9.json').write_text(json.dumps(row))
            with self.assertRaises(mod.ActionUnavailable): mod.browser_windows(entry,state,clients)
            row['timestamp'] -= 1; row['execArgv']='["malicious"]'
            (state/'history/12345-9.json').write_text(json.dumps(row))
            with self.assertRaises(mod.ActionUnavailable): mod.browser_windows(entry,state,clients)

    def test_focus_dispatch_requires_compositor_readback(self):
        from unittest.mock import patch
        from subprocess import CompletedProcess
        target={'address':'0x123','pid':100,'class':'chromium'}
        with patch.object(mod,'browser_focus_target',return_value=target), patch.object(mod,'hypr_query',side_effect=[[],target]), patch.object(mod.subprocess,'run',return_value=CompletedProcess([],0)) as dispatch:
            mod.focus_browser_window({},Path('/fixture'),{'address':'0x123','pid':100})
            self.assertEqual(dispatch.call_args.args[0],['/usr/bin/hyprctl','dispatch','focuswindow','address:0x123'])
        with patch.object(mod,'browser_focus_target',return_value=target), patch.object(mod,'hypr_query',side_effect=[[],{'address':'0x999','pid':100,'class':'chromium'}]), patch.object(mod.subprocess,'run',return_value=CompletedProcess([],0)), patch.object(mod.time,'monotonic',side_effect=[0,2]):
            with self.assertRaises(mod.ActionUnavailable):
                mod.focus_browser_window({},Path('/fixture'),{'address':'0x123','pid':100})

if __name__ == '__main__': unittest.main()
