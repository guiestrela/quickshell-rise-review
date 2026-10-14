#!/usr/bin/env python3
"""Filtered read-only wake state contract; no real session state mutations."""
import importlib.util
from importlib.machinery import SourceFileLoader
from pathlib import Path
import json
SOURCE=Path(__file__).resolve().parents[1]/'scripts/rise-wallpaper-wake-state'
assert SOURCE.exists(), 'Missing read-only wake bridge helper'
spec=importlib.util.spec_from_loader('wake_reader',SourceFileLoader('wake_reader',str(SOURCE)))
assert spec is not None and spec.loader is not None
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
idle={'screensaverWindows':0,'extra_private_field':'must-not-leave-helper'}
result=module.parse_states(False,idle)
assert result=={'schema':1,'locked':False,'screensaverShowing':False}
assert module.parse_states(True,idle)['locked'] is True
assert module.parse_states(False,{'screensaverWindows':2})['screensaverShowing'] is True
for bad in [{},'false',0,None]:
 try:module.parse_states(bad,idle)
 except ValueError:pass
 else:raise AssertionError('Malformed lock accepted')
for value in [-1,True,1.5,'0']:
 try:module.parse_states(False,{'screensaverWindows':value})
 except ValueError:pass
 else:raise AssertionError('Malformed idle accepted')
commands=[]
def fake(command):
 commands.append(command)
 return json.dumps(False if command[-2]=='lock' else idle)
assert module.read_state(fake)==result
assert commands==[['/usr/bin/omarchy-shell','lock','isLocked'],['/usr/bin/omarchy-shell','idle','status']]
print('PASS: primitive lock IPC, filtered idle booleans, exact readonly argv, malformed schemas fail closed; no authentication status requested')
