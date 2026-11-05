#!/usr/bin/env python3
"""Selected app launch fixtures; no real launch or mailbox access."""
import importlib.util,json,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
HELPER=Path(__file__).resolve().parents[1]/'shared/integrations/notification-app-open.py'
class AppOpen(unittest.TestCase):
 def test_omasnap_opens_selected_saved_image_without_starting_capture(self):
  spec=importlib.util.spec_from_file_location('app_open',HELPER);mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
  with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as tmp:
   root=Path(tmp);state=root/'notifications';state.mkdir()
   pictures=root/'Pictures/Screenshots';pictures.mkdir(parents=True)
   image=pictures/'screenshot-2026-11-05_11-07-19-fixture.png'
   image.write_bytes(b'\x89PNG\r\n\x1a\nfixture')
   entry=dict(backend='omarchy',id=7,timestamp=12345678,appName='omasnap',summary='Screenshot saved',body='Fixture')
   row=dict(key='native-shot',originalId=7,ts=12345.678,app='omasnap',summary=entry['summary'],body=entry['body'],execArgv=json.dumps(['xdg-open',str(image)]))
   record=state/'history.json'
   cache=root/'cache.json';cache.write_text(json.dumps({'recent':[entry]}))
   with patch.object(mod.Path,'home',return_value=root),patch.object(mod,'desktop_command',side_effect=AssertionError('Never launch the capture app')):
    record.write_text(json.dumps([row]))
    self.assertEqual(mod.plan_open(entry,state,cache),['/usr/bin/xdg-open',str(image)])
    for bad in [['omasnap'],['bash','-c','capture'],['xdg-open','https://example.invalid/'],['xdg-open',str(root/'other.png')]]:
     record.write_text(json.dumps([dict(row,execArgv=bad)]))
     with self.subTest(callback=bad),self.assertRaises(ValueError):mod.plan_open(entry,state,cache)
    record.write_text(json.dumps([row,row]))
    with self.assertRaises(ValueError):mod.plan_open(entry,state,cache)
    record.write_text(json.dumps([dict(row,summary='Other screenshot')]))
    with self.assertRaises(ValueError):mod.plan_open(entry,state,cache)
    record.write_text(json.dumps([row]));image.unlink();image.symlink_to(cache)
    with self.assertRaises(OSError):mod.plan_open(entry,state,cache)
    record.unlink()
    with self.assertRaises(ValueError):mod.plan_open(entry,state,cache)
 def test_selected_thunderbird_history_uses_fixed_app_only(self):
  self.assertTrue(HELPER.exists(),'Selected app launcher is missing')
  spec=importlib.util.spec_from_file_location('app_open',HELPER);assert spec and spec.loader;mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
  with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as tmp:
   root=Path(tmp);state=root/'notifications';state.mkdir();cache=root/'cache.json'
   entry={'backend':'omarchy','id':12,'timestamp':12345,'appName':'Thunderbird','summary':'Fixture','body':'Fixture'}
   def save(row):cache.write_text(json.dumps({'recent':[row]}))
   save(entry);self.assertEqual(mod.plan_open(entry,state,cache),['/usr/bin/thunderbird'])
   for key,value in [('appName','Unknown'),('appName',[]),('backend','mako'),('execArgv',['evil']),('timestamp',True),('id',0)]:
    changed=dict(entry);changed[key]=value;save(changed)
    with self.subTest(key=key),self.assertRaises(ValueError):mod.plan_open(changed,state,cache)
   changed=dict(entry);changed['body']='changed';save(changed)
   with self.assertRaises(ValueError):mod.plan_open(entry,state,cache)
   cache.write_text(json.dumps({'recent':[entry,entry]}))
   with self.assertRaises(ValueError):mod.plan_open(entry,state,cache)
   save(entry);cache.chmod(0o666)
   with self.assertRaises(ValueError):mod.plan_open(entry,state,cache)
   cache.chmod(0o600)
   native={'originalId':12,'timestamp':12345,'app':'Thunderbird','summary':'Fixture','body':'Fixture','execArgv':None}
   target=state/'12345-12.json';target.write_text(json.dumps(native))
   self.assertEqual(mod.plan_open(entry,state,cache),['/usr/bin/thunderbird'])
   native['execArgv']='untrusted';target.write_text(json.dumps(native))
   with self.assertRaises(ValueError):mod.plan_open(entry,state,cache)
 def test_launch_no_notification_arguments(self):
  self.assertTrue(HELPER.exists(),'Selected app launcher is missing')
  spec=importlib.util.spec_from_file_location('app_open',HELPER);assert spec and spec.loader;mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
  with patch.object(mod.subprocess,'Popen') as start:
   start.return_value.wait.return_value=0
   mod.launch(['/usr/bin/thunderbird']);self.assertEqual(start.call_args.args[0],['/usr/bin/thunderbird'])
   with self.assertRaises(ValueError):mod.launch(['/usr/bin/thunderbird','-compose'])
   with self.assertRaises(ValueError):mod.launch(['/usr/bin/other'])
   start.return_value.wait.return_value=1
   with self.assertRaises(ValueError):mod.launch(['/usr/bin/thunderbird'])
if __name__=='__main__':unittest.main()
