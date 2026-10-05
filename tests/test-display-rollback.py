#!/usr/bin/env python3
"""Real detached rollback worker, inert hyprctl executable and private runtime."""
import json, os, shutil, subprocess, tempfile, time, unittest, runpy
from unittest import mock
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
class RollbackTests(unittest.TestCase):
 def test_expired_worker_cannot_apply_after_becoming_ready(self):
  guard=runpy.run_path(str(repo/'scripts/rise-display-manager-guard'))
  namespace=guard['apply_locked'].__globals__
  with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR'],prefix='display-expired-worker-') as folder:
   os.chmod(folder,0o700)
   baseline=dict(name='DP-1',width=2560,height=1440,refreshRate=155,x=0,y=560,scale=1,transform=0,disabled=False,mirrorOf='none')
   def expired_worker(argv,**kwargs):
    with guard['transaction'](argv[-1]) as (directory,data):
     data.update(ready=True,status='reverted',deadline=time.monotonic()-1)
     guard['write_state'](directory,data)
    return mock.Mock(poll=mock.Mock(return_value=0))
   args=['--action','monitor','--monitor','DP-1','--mode','2560x1440@155','--x','1','--y','560','--scale','1','--transform','0']
   with mock.patch.dict(os.environ,XDG_RUNTIME_DIR=folder), mock.patch.dict(namespace,monitors=lambda:[baseline]), mock.patch.dict(guard['api'],check_live_action=lambda *a,**k:None), mock.patch.object(subprocess,'Popen',side_effect=expired_worker), mock.patch.object(subprocess,'run',side_effect=AssertionError('Unarmed monitor mutation')) as mutation:
    with self.assertRaises(ValueError):guard['apply_locked'](json.dumps(args),15)
    mutation.assert_not_called()

 def test_timeout_confirmation_and_manual_revert(self):
  with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR'],prefix='display-rollback-') as folder:
   root=Path(folder); scripts=root/'scripts';scripts.mkdir();runtime=root/'runtime';runtime.mkdir(mode=0o700)
   for name in ['rise-display-manager-apply','rise-display-manager-guard']:
    self.assertTrue((repo/'scripts'/name).exists(),'missing independent rollback watchdog')
    shutil.copy2(repo/'scripts'/name,scripts/name)
   state=root/'monitors.json';state.write_text(json.dumps([dict(name='DP-1',width=2560,height=1440,refreshRate=155,x=0,y=560,scale=1,transform=0,disabled=False,mirrorOf='none'),dict(name='DP-2',width=2560,height=1440,refreshRate=155,x=2560,y=0,scale=1,transform=1,disabled=False,mirrorOf='none')]))
   initial=state.read_text(); cli=root/'hyprctl'
   cli.write_text(r'''#!/usr/bin/python3
import json,os,re,sys
from pathlib import Path
p=Path(os.environ['TEST_MONITOR_STATE']);ms=json.loads(p.read_text())
if sys.argv[1]=='monitors':print(json.dumps(ms))
elif sys.argv[1]=='eval':
 code=sys.argv[2];name=re.search(r'output = "([^"]+)"',code).group(1);m=next(m for m in ms if m['name']==name)
 pos=re.search(r'position = "(-?\d+)x(-?\d+)"',code)
 if pos and not os.environ.get('TEST_NO_APPLY'):m['x'],m['y']=map(int,pos.groups())
 m['disabled']='disabled = true' in code
 p.write_text(json.dumps(ms));print('ok')
else:sys.exit(99)
''');cli.chmod(0o700)
   env=dict(os.environ,PATH=str(root)+':'+os.environ['PATH'],XDG_RUNTIME_DIR=str(runtime),TEST_MONITOR_STATE=str(state))
   guard=scripts/'rise-display-manager-guard'
   def call(*args):
    r=subprocess.run(['/usr/bin/python3',str(guard),*args],env=env,capture_output=True,text=True,timeout=5)
    self.assertEqual(r.returncode,0,r.stdout+r.stderr);return json.loads(r.stdout)
   args=['--action','monitor','--monitor','DP-1','--mode','2560x1440@155','--x','1','--y','560','--scale','1','--transform','0']
   # Parent apply exits; a separate process must restore without UI help.
   pending=call('--apply',json.dumps(args),'--seconds','2')
   self.assertEqual(json.loads(state.read_text())[0]['x'],1)
   deadline=time.monotonic()+5
   while time.monotonic()<deadline and json.loads(state.read_text())[0]['x']!=0:time.sleep(.1)
   self.assertEqual(json.loads(state.read_text()),json.loads(initial),'detached worker did not restore')
   self.assertEqual(call('--status',pending['token'])['status'],'reverted')
   rejected=subprocess.run(['/usr/bin/python3',str(guard),'--confirm',pending['token']],env=env,capture_output=True,text=True,timeout=5)
   self.assertNotEqual(rejected.returncode,0,'late confirmation must fail')
   pending=call('--apply',json.dumps(args),'--seconds','2')
   self.assertEqual(call('--confirm',pending['token'])['status'],'confirmed')
   time.sleep(2.3);self.assertEqual(json.loads(state.read_text())[0]['x'],1,'confirmed settings reverted')
   # New baseline is now X1; temporary change to X2 must restore X1.
   args[args.index('--x')+1]='2'
   pending=call('--apply',json.dumps(args),'--seconds','2')
   self.assertEqual(call('--revert',pending['token'])['status'],'reverted')
   self.assertEqual(json.loads(state.read_text())[0]['x'],1)
   self.assertEqual(json.loads(state.read_text())[1],json.loads(initial)[1],'unrelated monitor changed')
   args[args.index('--x')+1]='3'
   no_apply=subprocess.run(['/usr/bin/python3',str(guard),'--apply',json.dumps(args),'--seconds','2'],env=dict(env,TEST_NO_APPLY='1'),capture_output=True,text=True,timeout=5)
   self.assertNotEqual(no_apply.returncode,0,'accepted textual ok without compositor state change')
   self.assertEqual(json.loads(state.read_text())[0]['x'],1)
   time.sleep(.3)
   invalid_snapshot=json.loads(state.read_text());invalid_snapshot[0]['scale']=1.333333;state.write_text(json.dumps(invalid_snapshot))
   time.sleep(.3)
   invalid=subprocess.run(['/usr/bin/python3',str(guard),'--apply',json.dumps(args),'--seconds','2'],env=env,capture_output=True,text=True,timeout=5)
   self.assertNotEqual(invalid.returncode,0,'applied a change with a non-restorable baseline')
   self.assertEqual(json.loads(state.read_text())[0]['x'],1,'mutated before validating original snapshot')
   bad=subprocess.run(['/usr/bin/python3',str(guard),'--status','../escape'],env=env,capture_output=True,text=True,timeout=5)
   self.assertNotEqual(bad.returncode,0,'invalid token accepted')
if __name__=='__main__':unittest.main()
