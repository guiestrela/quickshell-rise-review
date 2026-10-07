#!/usr/bin/env python3
"""Registered app fixtures only: never execute a desktop application."""
import importlib.util,json,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
HELPER=Path(__file__).resolve().parents[1]/'versions/V1/integrations/notification-app-open.py'
class Catalog(unittest.TestCase):
 def test_unique_registered_app_and_catalog_guards(self):
  spec=importlib.util.spec_from_file_location('app_open',HELPER);assert spec and spec.loader
  mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
  self.assertTrue(hasattr(mod,'desktop_command'),'Registered app resolution is missing')
  with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as tmp:
   root=Path(tmp);user=root/'user';system=root/'system';user.mkdir();system.mkdir()
   file=system/'org.fixture.App.desktop'
   def desktop(p,name='Fixture App',extra=''):
    p.write_text('[Desktop Entry]\nType=Application\nName='+name+'\nExec=/usr/bin/true\nStartupWMClass=FixtureApp\n'+extra);p.chmod(0o600)
   desktop(file)
   with patch.object(mod,'desktop_dirs',return_value=[user,system]):
    self.assertEqual(mod.desktop_command('FixtureApp'),['/usr/bin/gio','launch',str(file)])
    self.assertEqual(mod.desktop_command('org.fixture.App'),['/usr/bin/gio','launch',str(file)])
    entry={'backend':'omarchy','id':22,'timestamp':12345,'appName':'Fixture App','summary':'Fixture','body':'Fixture'}
    state=root/'notifications';state.mkdir();cache=root/'cache.json';cache.write_text(json.dumps({'recent':[entry]}))
    self.assertEqual(mod.plan_open(entry,state,cache),['/usr/bin/gio','launch',str(file)])
    with patch.object(mod.subprocess,'Popen') as start:
     start.return_value.wait.return_value=0;mod.launch(mod.desktop_command('FixtureApp'))
     self.assertEqual(start.call_args.args[0],['/usr/bin/gio','launch',str(file)])
     with self.assertRaises(ValueError):mod.launch(['/usr/bin/gio','launch',str(file),'--flag'])
    other=system/'Other.desktop';desktop(other)
    with self.assertRaises(ValueError):mod.desktop_command('FixtureApp')
    other.unlink();file.chmod(0o666)
    with self.assertRaises(ValueError):mod.desktop_command('FixtureApp')
    file.chmod(0o600);desktop(user/file.name,extra='Hidden=true\n')
    with self.assertRaises(ValueError):mod.desktop_command('FixtureApp')
    desktop(user/file.name,name='User Fixture');self.assertEqual(mod.desktop_command('User Fixture')[-1],str(user/file.name))
    with self.assertRaises(ValueError):mod.desktop_command('../unregistered')
if __name__=='__main__':unittest.main()
