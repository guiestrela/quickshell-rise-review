#!/usr/bin/env python3
"""Real helper logic under isolated HOME and inert command boundary."""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

source = Path(__file__).resolve().parents[1] / "scripts/rise-display-manager-apply"
loader = importlib.machinery.SourceFileLoader("display_helper", str(source))
spec = importlib.util.spec_from_loader(loader.name, loader)
helper = importlib.util.module_from_spec(spec)
loader.exec_module(helper)


def layout():
    return {"monitors": [{"output": "DP-1", "mode": "2560x1440@59.95", "position": "0x0", "scale": 1, "transform": 0},
                          {"output": "DP-2", "mode": "1920x1080@60", "position": "2560x0", "scale": 1, "transform": 0}],
            "manageWorkspaces": True, "workspaces": [{"workspace": 1, "monitor": "DP-1"}, {"workspace": 2, "monitor": "DP-1"}]}

class HelperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ["TMPDIR"], prefix="display-helper-")
        self.home = Path(self.temp.name)
        self.target = self.home / ".config/hypr/monitors.lua"
        self.target.parent.mkdir(parents=True)
        self.home_patch = patch.dict(os.environ, {"HOME": str(self.home)})
        self.home_patch.start()

    def tearDown(self):
        self.home_patch.stop()
        self.temp.cleanup()

    def test_monitor_actions_use_lua_and_reject_false_success(self):
        monitors=[{'name':'DP-1','disabled':False,'mirrorOf':'none'}, {'name':'DP-2','disabled':False,'mirrorOf':'none'}]
        for action, extra, expected in [('monitor', ['--mode','2560x1440@155.00Hz','--x','0','--y','560','--scale','1.25','--transform','1'], 'position = "0x560"'), ('monitor', ['--mirror','DP-2'], 'mirror = "DP-2"'), ('disable', [], 'disabled = true')]:
            calls=[]
            def fake_run(argv, *, capture=False):
                calls.append(argv)
                if argv[:2]==['hyprctl','monitors']: return SimpleNamespace(stdout=json.dumps(monitors))
                if argv[:2]==['hyprctl','keyword']: return SimpleNamespace(stdout="keyword can't work with non-legacy parsers. Use eval.")
                return SimpleNamespace(stdout='ok\n')
            with self.subTest(action=action, extra=extra), patch.object(helper,'run',fake_run), patch('sys.argv',['helper','--action',action,'--monitor','DP-1']+extra), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(helper.main(),0)
                self.assertEqual(calls[-1][:2], ['hyprctl','eval'])
                self.assertIn('hl.monitor({',calls[-1][2]); self.assertIn(expected,calls[-1][2])
        def rejected_run(argv, *, capture=False):
            if argv[:2]==['hyprctl','monitors']: return SimpleNamespace(stdout=json.dumps(monitors))
            return SimpleNamespace(stdout='Lua error: rejected\n')
        with patch.object(helper,'run',rejected_run), patch('sys.argv',['helper','--action','monitor','--monitor','DP-1']), contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(helper.main(),1)
            self.assertNotIn('Display action applied',output.getvalue())

    def test_mirror_ids_are_named_and_source_cannot_be_disabled(self):
        ms=[dict(id=0,name='DP-1',mirrorOf='1'),dict(id=1,name='DP-2',mirrorOf='none'),dict(id=2,name='DP-3',mirrorOf='none')]
        def fake(argv,**kwargs):return SimpleNamespace(stdout=json.dumps(ms))
        with patch.object(helper,'run',fake), patch('sys.argv',['helper','--action','monitors']), contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(helper.main(),0)
            self.assertEqual(json.loads(out.getvalue())[0]['mirrorOf'],'DP-2')
        with patch.object(helper,'run',fake):
            with self.assertRaises(ValueError):helper.check_live_action('DP-2',disabling=True)

    def test_extend_explicitly_clears_existing_mirror(self):
        calls=[]
        ms=[dict(name='DP-1',mirrorOf='DP-2'),dict(name='DP-2',mirrorOf='none')]
        def fake(argv,**kwargs):
            calls.append(argv)
            return SimpleNamespace(stdout=json.dumps(ms) if argv[1]=='monitors' else 'ok')
        with patch.object(helper,'run',fake), patch('sys.argv',['helper','--action','monitor','--monitor','DP-1','--mirror','none']), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(helper.main(),0)
        self.assertIn('mirror = ""',calls[-1][2])

    def test_brightness_query_and_write_verify_selected_output(self):
        calls=[]
        def fake(argv,**kwargs):
            calls.append(argv)
            return SimpleNamespace(stdout='73\n' if '--no-osd' in argv and not argv[-1].endswith('%') else '')
        with patch.object(helper,'run',fake), patch('sys.argv',['helper','--action','brightness-state','--monitor','DP-2']), contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(helper.main(),0)
            self.assertEqual(json.loads(out.getvalue()),dict(monitor='DP-2',percent=73))
        self.assertEqual(calls[-1],['omarchy-brightness-display','--no-osd','--monitor','DP-2'])
        # An exit-0 skipped write must not be announced as successful.
        with patch.object(helper,'run',fake), patch('sys.argv',['helper','--action','brightness','--monitor','DP-2','--percent','72']), contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(helper.main(),1)
            self.assertNotIn('Brightness updated',out.getvalue())

    def test_save_modes_backup_unmanaged_and_defaults(self):
        old = "-- preserve outside managed block\nhl.config({ misc = {} })\n"
        self.target.write_text(old)
        helper.save_layout(layout())
        saved = self.target.read_text()
        self.assertIn(old.rstrip(), saved)
        self.assertIn('mode = "2560x1440@59.95"', saved)
        self.assertEqual(saved.count("default:true"), 1)
        self.assertEqual(self.target.with_suffix(".lua.bak").read_text(), old)

    def test_validation_rejects_cycles_unknown_targets_and_last_disabled(self):
        for patcher in (
            lambda d: d["monitors"][0].update(mirror="DP-1"),
            lambda d: d["monitors"][0].update(mirror="NO-SUCH-OUTPUT"),
            lambda d: (d["monitors"][0].update(mirror="DP-2"), d["monitors"][1].update(mirror="DP-1")),
            lambda d: (d["monitors"][0].update(disabled=True), d["monitors"][1].update(disabled=True)),
            lambda d: d["monitors"][0].update(position="99999x0"),
            lambda d: d["workspaces"][0].update(workspace=True),
            lambda d: d["workspaces"][1].update(workspace=1),
        ):
            data=layout(); patcher(data)
            with self.subTest(data=data), self.assertRaises(ValueError): helper.build_block(data)

    def test_disabled_output_is_serialized(self):
        data=layout(); data["monitors"][1].update(disabled=True)
        self.assertIn('output = "DP-2", disabled = true', helper.build_block(data))

    def test_native_fractional_mode_normalizes(self):
        args = helper.parser_for_action().parse_args(["--action", "monitor", "--monitor", "DP-1", "--mode", "2560x1440@59.95Hz"])
        self.assertEqual(helper.monitor_args(args)[1], "2560x1440@59.95")

    def test_backup_and_target_symlinks_fail_closed(self):
        outside=self.home / "outside"; outside.write_text("KEEP")
        self.target.write_text("OLD")
        backup=self.target.with_suffix(".lua.bak"); backup.symlink_to(outside)
        with self.assertRaises((ValueError,OSError)): helper.save_layout(layout())
        self.assertEqual(outside.read_text(),"KEEP")
        self.assertEqual(self.target.read_text(),"OLD")
        backup.unlink(); self.target.unlink(); self.target.symlink_to(outside)
        with self.assertRaises((ValueError,OSError)): helper.save_layout(layout())
        self.assertTrue(self.target.is_symlink())
        self.assertEqual(outside.read_text(),"KEEP")

    def test_save_requires_connected_independent_output(self):
        data=layout(); data['monitors'][0]['disabled']=True
        data['monitors'][1]['output']='NO-SUCH-OUTPUT'; data['manageWorkspaces']=False
        self.target.write_text('KEEP')
        calls=[]
        def fake_run(argv, *, capture=False):
            calls.append(argv)
            return SimpleNamespace(stdout=json.dumps([{'name':'DP-1','disabled':False,'mirrorOf':'none'}]))
        with patch.object(helper,'run',fake_run), patch('sys.argv',['helper','--action','save','--payload',json.dumps(data)]), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(helper.main(),1,'nonexistent independent display must not authorize reload')
        self.assertEqual(self.target.read_text(),'KEEP')
        self.assertNotIn(['hyprctl','reload'],calls)

    def test_source_with_live_mirrors_cannot_become_a_mirror(self):
        monitors=[{'name':'DP-1','mirrorOf':'none'},{'name':'DP-2','mirrorOf':'DP-1'},{'name':'DP-3','mirrorOf':'none'}]
        calls=[]
        def fake_run(argv, *, capture=False):
            calls.append(argv)
            return SimpleNamespace(stdout=json.dumps(monitors))
        with patch.object(helper,'run',fake_run), patch('sys.argv',['helper','--action','monitor','--monitor','DP-1','--mirror','DP-3']), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(helper.main(),1)
        self.assertFalse(any(c[:2] in (['hyprctl','keyword'], ['hyprctl','eval']) for c in calls))

    def test_main_last_display_disable_and_reload_rollback(self):
        calls=[]
        monitors=[{"name":"DP-1","disabled":False,"mirrorOf":"none"}]
        def fake_run(argv, *, capture=False):
            calls.append(argv)
            if argv[:2]==["hyprctl","monitors"]: return SimpleNamespace(stdout=json.dumps(monitors))
            if argv==["hyprctl","reload"]: raise helper.subprocess.CalledProcessError(1,argv)
            return SimpleNamespace(stdout="")
        with patch.object(helper,"run",fake_run), patch("sys.argv",["helper","--action","disable","--monitor","DP-1"]), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(helper.main(),1)
        self.assertFalse(any(c[:2] in (['hyprctl','keyword'], ['hyprctl','eval']) for c in calls))
        old="-- original config\n"; self.target.write_text(old)
        monitors.append({'name':'DP-2','disabled':False,'mirrorOf':'none'})
        with patch.object(helper,"run",fake_run), patch("sys.argv",["helper","--action","save","--payload",json.dumps(layout())]), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(helper.main(),1)
        self.assertIn(['hyprctl','reload'],calls,'exercise rollback after actual stub reload failure')
        self.assertEqual(self.target.read_text(),old,"failed reload must restore prior bytes")

if __name__=="__main__": unittest.main()
