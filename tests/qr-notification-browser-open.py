#!/usr/bin/env python3
"""HTTPS notification navigation fixtures; never launch a browser in tests."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
HELPER=ROOT/'versions/V1/integrations/notification-browser-open.py'

class BrowserOpen(unittest.TestCase):
    def test_expired_selected_entry_opens_only_available_href(self):
        self.assertTrue(HELPER.exists(), 'Selected notification new-tab launcher is missing')
        spec=importlib.util.spec_from_file_location('browser_open',HELPER)
        assert spec and spec.loader
        mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as tmp:
            root=Path(tmp);state=root/'notifications';state.mkdir();cache=root/'cache.json'
            entry={'backend':'omarchy','id':9,'timestamp':12345,'appName':'Chromium',
                   'summary':'Fixture','body':'<a href="https://www.tudocelular.com/">Site</a>\nFixture text'}
            cache.write_text(json.dumps({'recent':[entry]}))
            self.assertEqual(mod.plan_open(entry,state,cache),
                ['/usr/bin/chromium','--new-tab','https://www.tudocelular.com/'])
            for url in ['https://web.whatsapp.com/', 'https://www.vans.com.br/',
                        'https://example.org/a?selected=one', 'https://www.tudocelular.com.evil.invalid/']:
                entry['body']='<a href="'+url+'">Site</a>';cache.write_text(json.dumps({'recent':[entry]}))
                with self.subTest(approved_https=url):
                    self.assertEqual(mod.plan_open(entry,state,cache),[mod.BROWSER,'--new-tab',url])
            for url in ['javascript:alert(1)','file:///etc/passwd','http://www.tudocelular.com/',
                        'https:///', 'data:text/html,fixture',
                        'https://user:password@www.tudocelular.com/','https://www.tudocelular.com:444/',
                        'https://www.tudocelular.com/\\n--flag']:
                entry['body']='<a href="'+url+'">Site</a>';cache.write_text(json.dumps({'recent':[entry]}))
                with self.subTest(url=url),self.assertRaises(ValueError):mod.plan_open(entry,state,cache)
            entry['body']='<a href="https://www.tudocelular.com/">Site</a><a href="https://tudocelular.com/other">Other</a>'
            cache.write_text(json.dumps({'recent':[entry]}))
            with self.assertRaises(ValueError):mod.plan_open(entry,state,cache)
            entry['body']='<a href="https://www.tudocelular.com/">Site</a>'
            saved=dict(entry);saved['timestamp']+=1;cache.write_text(json.dumps({'recent':[saved]}))
            with self.assertRaises(ValueError):mod.plan_open(entry,state,cache)
            cache.write_text(json.dumps({'recent':[entry,entry]}))
            with self.assertRaises(ValueError):mod.plan_open(entry,state,cache)
            cache.write_text(json.dumps({'recent':[entry]}));cache.chmod(0o666)
            with self.assertRaises(ValueError):mod.plan_open(entry,state,cache)

    def test_browser_startup_or_existing_instance_handoff(self):
        from unittest.mock import patch
        import subprocess
        spec=importlib.util.spec_from_file_location('browser_open',HELPER);assert spec and spec.loader
        mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
        argv=['/usr/bin/chromium','--new-tab','https://www.tudocelular.com/']
        with patch.object(mod.subprocess,'Popen') as start:
            start.return_value.wait.return_value=0
            mod.launch(argv);self.assertEqual(start.call_args.args[0],argv)
            start.return_value.wait.side_effect=subprocess.TimeoutExpired(argv,0.75)
            mod.launch(argv)
            start.return_value.wait.side_effect=None;start.return_value.wait.return_value=1
            with self.assertRaises(ValueError):mod.launch(argv)

if __name__=='__main__':unittest.main()
