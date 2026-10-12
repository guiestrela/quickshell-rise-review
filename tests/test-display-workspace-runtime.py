#!/usr/bin/env python3
"""Real QML Process + real detached guard, private fake compositor. No live display actions."""
import os,json,re,subprocess,tempfile,shutil
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
assert os.environ.get('WAYLAND_DISPLAY') and os.environ.get('XDG_RUNTIME_DIR')
with tempfile.TemporaryDirectory(prefix='explicit-apply-',dir=os.environ['TMPDIR']) as directory:
 root=Path(directory);scripts=root/'scripts';scripts.mkdir();runtime=root/'runtime';runtime.mkdir(mode=0o700);home=root/'home';(home/'.cache/quickshell-rise').mkdir(parents=True);(home/'.config/hypr').mkdir(parents=True)
 for name in ['rise-display-manager-apply','rise-display-manager-guard']:shutil.copy2(repo/'scripts'/name,scripts/name)
 shutil.copy2(repo/'versions/V1/modules/DisplayManagerController.qml',root/'Controller.qml')
 baseline=[dict(id=i,name=name,width=1000,height=1000,refreshRate=60,x=i*1000,y=0,scale=1,transform=0,disabled=False,mirrorOf='none') for i,name in enumerate(['A','B'])]
 (root/'rules.json').write_text(json.dumps([{'workspaceString':'1','enabled':True,'monitor':'A'},{'workspaceString':'2','enabled':True,'monitor':'B'}]));(root/'state.json').write_text(json.dumps(baseline));(root/'effects.json').write_text(json.dumps({'eval':0,'brightness':0,'font':0,'workspace':0,'percent':70}))
 cli=root/'hyprctl';cli.write_text('''#!/usr/bin/python3
import os,json,re,sys
from pathlib import Path
r=Path(os.environ['TEST_FIXTURE_ROOT']);s=r/'state.json';e=r/'effects.json';ms=json.loads(s.read_text());effects=json.loads(e.read_text())
if sys.argv[1]=='monitors':print(json.dumps(ms))
elif sys.argv[1]=='workspacerules':print((r/'rules.json').read_text())
elif sys.argv[1]=='workspaces':print(json.dumps([dict(id=1,monitor='A'),dict(id=2,monitor='B')]))
elif sys.argv[1]=='reload':print('ok')
elif sys.argv[1]=='configerrors':print('')
elif sys.argv[1]=='eval':
 for chunk in re.findall(r'hl.monitor\\(\\{(.*?)\\}\\)',sys.argv[2],re.S):
  name=re.search(r'output = "([^\"]+)"',chunk).group(1);m=next(m for m in ms if m['name']==name)
  pos=re.search(r'position = "(-?\\d+)x(-?\\d+)"',chunk)
  if pos:m['x'],m['y']=map(int,pos.groups())
  m['disabled']='disabled = true' in chunk
 s.write_text(json.dumps(ms));effects['eval']+=int('hl.monitor' in sys.argv[2])
 if 'hl.workspace_rule' in sys.argv[2]:
  rules=json.loads((r/'rules.json').read_text())
  for chunk in re.findall(r'hl.workspace_rule\\(\\{(.*?)\\}\\)',sys.argv[2],re.S):
   number=re.search(r'workspace = "([0-9]+)"',chunk).group(1);target=re.search(r'monitor = "([^"]+)"',chunk).group(1);rules=[rule for rule in rules if rule['workspaceString']!=number];rules.append(dict(workspaceString=number,enabled=True,monitor=target))
  (r/'rules.json').write_text(json.dumps(rules));effects['workspace']+=1
 e.write_text(json.dumps(effects));print('ok')
else:sys.exit(99)
''');cli.chmod(0o700)
 brightness=root/'omarchy-brightness-display';brightness.write_text('''#!/usr/bin/python3
import os,json,sys
from pathlib import Path
p=Path(os.environ['TEST_FIXTURE_ROOT'])/'effects.json';data=json.loads(p.read_text())
if sys.argv[-1].endswith('%'):data['brightness']+=1;data['percent']=int(sys.argv[-1][:-1]);p.write_text(json.dumps(data))
print(data['percent'])
''');brightness.chmod(0o700)
 font=root/'omarchy-display-text-size';font.write_text('''#!/usr/bin/python3
import os,json
from pathlib import Path
p=Path(os.environ['TEST_FIXTURE_ROOT'])/'effects.json';data=json.loads(p.read_text());data['font']+=1;p.write_text(json.dumps(data))
''');font.chmod(0o700)
 for name in ['guard','helper']:
  wrapper=root/name;target=scripts/('rise-display-manager-'+('guard' if name=='guard' else 'apply'))
  wrapper.write_text('#!/usr/bin/python3\nimport os,sys\nos.environ["XDG_RUNTIME_DIR"]='+repr(str(runtime))+'\nos.execv(sys.executable,[sys.executable,'+repr(str(target))+',*sys.argv[1:]])\n');wrapper.chmod(0o700)
 (root/'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
 id: test
 property int phase: 0
 property int ticks: 0
 QtObject { id: theme; property bool displayManagerAutoWorkspaces: true }
 Controller { id: c; theme: theme }
 FileView { id: effects; path: Quickshell.env("TEST_FIXTURE_ROOT")+"/effects.json"; printErrors: false; blockLoading:true; blockAllReads:true }
 function fail(message) { console.error("EXPLICIT_RUNTIME_FAIL "+message); Qt.quit() }
 FileView { id: layout; path: Quickshell.env("HOME")+"/.config/hypr/monitors.lua"; printErrors:false;blockAllReads:true }
 Component.onCompleted: {c.refresh();c.refreshWorkspaces()}
 Timer {
  interval:25; running:true; repeat:true
  onTriggered: {
   test.ticks++
   if(test.ticks>240) { test.fail("bounded phase "+test.phase+" "+c.error);return }
   if(test.phase===0 && !c.loading && c.displayStateReady && c.workspaceStateReady && !c.workspaceLoading) {
    if(c.monitors.length!==2) { test.fail("initial query "+c.error);return }
    c.stageMonitor("A",{y:100});c.stageMonitor("B",{y:100});c.stageWorkspace(3,"B");c.setBrightness(75)
    test.ticks=0;test.phase=10
   } else if(test.phase===10 && !c.busy && !c.loading) {
    if(!c.setTextSize(4)) { test.fail("immediate font rejected");return }
    test.phase=11
   } else if(test.phase===11 && !c.busy && !c.loading) {
    test.ticks=0;test.phase=1
   } else if(test.phase===1 && test.ticks>=12) {
    effects.reload();var data=JSON.parse(effects.text())
    if(data.eval!==0 || data.brightness!==1 || data.font!==1 || data.workspace!==0 || c.rollbackPending || c.rollbackSeconds!==0 || c.monitors[0].y!==0) { test.fail("edit mutated before Apply");return }
    if(!c.applyDrafts()) { test.fail("Apply rejected "+c.error);return }
    test.phase=2
   } else if(test.phase===2 && c.rollbackPending && !c.busy) {
    effects.reload();var applied=JSON.parse(effects.text())
    if(applied.eval!==1 || applied.brightness!==1 || applied.font!==1 || applied.workspace!==0 || c.rollbackSeconds!==5) { test.fail("single batch, immediate settings or five-second timer "+JSON.stringify(applied)+" seconds="+c.rollbackSeconds);return }
    c.confirmChanges();test.phase=3
   } else if(test.phase===3 && !c.rollbackPending && !c.confirmationBusy && !c.busy && !c.loading && !c.extraQueue.length && !c.workspaceLoading && !c.workspaceCommitPending) {
    effects.reload();var final=JSON.parse(effects.text())
    if(final.eval!==1 || final.brightness!==1 || final.font!==1 || final.workspace!==1 || c.workspaceOverrides["3"]!=="B" || c.hasDrafts || c.monitors[0].y!==100 || c.monitors[1].y!==100 || c.textSizeIndex!==4) { test.fail("Keep must commit extras and preserve batch "+JSON.stringify(final)+" "+c.error);return }
    if(!c.saveLayout()) {test.fail("Save rejected "+c.error);return}
    test.phase=4
   } else if(test.phase===4 && !c.busy && !c.loading && !c.workspaceLoading) {
    layout.reload();if(layout.text().indexOf("3, monitor:B")<0) {test.fail("Manual workspace override not saved "+c.error);return}
    console.log("EXPLICIT_RUNTIME_PASS workspace3 assigned toB only after Keep; fresh readback; Save real monitors.lua preserves manual assignment over Auto-bind; all compositor calls private/inert")
    Qt.quit()
   }
  }
 }
}
''')
 env={**os.environ,'HOME':str(home),'QT_QPA_PLATFORM':'wayland','TEST_FIXTURE_ROOT':str(root),'RISE_DISPLAY_MANAGER_APPLY':str(root/'helper'),'RISE_DISPLAY_MANAGER_GUARD':str(root/'guard'),'PATH':str(root)+':'+os.environ['PATH']};env.pop('DISPLAY',None)
 z=subprocess.run(['qs','-n','-p',str(root/'shell.qml')],env=env,capture_output=True,text=True,timeout=9);output=z.stdout+z.stderr
 assert z.returncode==0 and 'EXPLICIT_RUNTIME_PASS' in output and 'EXPLICIT_RUNTIME_FAIL' not in output,output
 assert not any(k in output for k in ['ReferenceError','TypeError','Cannot assign']),output
 print(next(l[l.index('EXPLICIT_RUNTIME_PASS'):] for l in output.splitlines() if 'EXPLICIT_RUNTIME_PASS' in l))
