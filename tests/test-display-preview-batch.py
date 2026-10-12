#!/usr/bin/env python3
"""Pure validation + detached batch guard using a private, inert compositor CLI."""
import json, os, runpy, shutil, subprocess, tempfile, time, unittest
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
class PreviewBatch(unittest.TestCase):
 def test_validated_runtime_only_code(self):
  api=runpy.run_path(str(repo/'scripts/rise-display-manager-apply'))
  self.assertIn('preview_command',api,'Apply needs one runtime-only batch, not Save layout')
  live=[dict(name='A',width=1000,height=1000,x=0,y=0,scale=1,transform=0,refreshRate=60,disabled=False,mirrorOf='none'),dict(name='B',width=1000,height=1000,x=1000,y=0,scale=1,transform=0,refreshRate=60,disabled=False,mirrorOf='none')]
  payload={'monitors':[{'output':'A','mode':'1000x1000@60','position':'0x100','scale':1,'transform':0,'disabled':False,'mirror':''},{'output':'B','mode':'1000x1000@60','position':'1000x100','scale':1,'transform':0,'disabled':False,'mirror':''}],'changed':['A','B']}
  code,requested=api['preview_command'](payload,live)
  self.assertEqual(code.count('hl.monitor('),2);self.assertNotIn('output = ""',code);self.assertIn('disabled = false',code);self.assertNotIn('workspace',code)
  for bad in [{'changed':['missing']}, {'changed':['A','A']}, {'monitors':[dict(payload['monitors'][0],position='10x10'),dict(payload['monitors'][1],position='900x10')]}]:
   with self.assertRaises(ValueError):api['preview_command']({**payload,**bad},live)
 def test_detached_batch_revert_and_keep(self):
  with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR'],prefix='draft-batch-') as directory:
   root=Path(directory);scripts=root/'scripts';scripts.mkdir();runtime=root/'runtime';runtime.mkdir(mode=0o700)
   for name in ['rise-display-manager-apply','rise-display-manager-guard']:shutil.copy2(repo/'scripts'/name,scripts/name)
   baseline=[dict(id=0,name='A',width=1000,height=1000,x=0,y=0,scale=1,transform=0,refreshRate=60,disabled=False,mirrorOf='none'),dict(id=1,name='B',width=1000,height=1000,x=1000,y=0,scale=1,transform=0,refreshRate=60,disabled=False,mirrorOf='none')]
   state=root/'monitors.json';state.write_text(json.dumps(baseline));cli=root/'hyprctl'
   cli.write_text('''#!/usr/bin/python3
import json,os,re,sys
from pathlib import Path
p=Path(os.environ['TEST_MONITOR_STATE']);ms=json.loads(p.read_text())
if sys.argv[1]=='monitors':print(json.dumps(ms))
elif sys.argv[1]=='eval':
 for chunk in re.findall(r'hl.monitor\\(\\{(.*?)\\}\\)',sys.argv[2],re.S):
  name=re.search(r'output = "([^\"]+)"',chunk).group(1);m=next(m for m in ms if m['name']==name)
  pos=re.search(r'position = "(-?\\d+)x(-?\\d+)"',chunk)
  if pos and not os.environ.get('TEST_NO_APPLY'):m['x'],m['y']=map(int,pos.groups())
  m['disabled']='disabled = true' in chunk
  mirror=re.search(r'mirror = "([^\"]*)"',chunk);m['mirrorOf']=mirror.group(1) if mirror and mirror.group(1) else 'none'
 p.write_text(json.dumps(ms));print('ok')
else:sys.exit(99)
''');cli.chmod(0o700)
   env={**os.environ,'PATH':str(root)+':'+os.environ['PATH'],'XDG_RUNTIME_DIR':str(runtime),'TEST_MONITOR_STATE':str(state)}
   payload={'monitors':[{'output':m['name'],'mode':'1000x1000@60','position':str(m['x'])+'x100','scale':1,'transform':0,'disabled':False,'mirror':''} for m in baseline],'changed':['A','B']}
   args=['--action','preview','--payload',json.dumps(payload)];guard=scripts/'rise-display-manager-guard'
   def call(*args):
    z=subprocess.run(['/usr/bin/python3',str(guard),*args],env=env,capture_output=True,text=True,timeout=6);self.assertEqual(z.returncode,0,z.stderr);return json.loads(z.stdout)
   pending=call('--apply',json.dumps(args),'--seconds','1');self.assertEqual([m['y'] for m in json.loads(state.read_text())],[100,100])
   deadline=time.monotonic()+4
   while time.monotonic()<deadline and json.loads(state.read_text())!=baseline:time.sleep(.05)
   self.assertEqual(json.loads(state.read_text()),baseline);self.assertEqual(call('--status',pending['token'])['status'],'reverted')
   pending=call('--apply',json.dumps(args),'--seconds','1');self.assertEqual(call('--confirm',pending['token'])['status'],'confirmed');time.sleep(1.1);self.assertEqual([m['y'] for m in json.loads(state.read_text())],[100,100])
   pending=call('--apply',json.dumps(args),'--seconds','1');self.assertEqual(call('--revert',pending['token'])['status'],'reverted');self.assertEqual([m['y'] for m in json.loads(state.read_text())],[100,100])
if __name__=='__main__':unittest.main()
