#!/usr/bin/env python3
import contextlib,io,runpy,unittest
from pathlib import Path
from unittest.mock import patch
repo=Path(__file__).resolve().parents[1]
class WorkspaceContract(unittest.TestCase):
 def test_workspace_assignment_is_validated_and_not_a_monitor_action(self):
  api=runpy.run_path(str(repo/'scripts/rise-display-manager-apply'))
  self.assertIn('workspace_command',api,'Per-monitor workspace selection needs a working backend')
  monitors=[dict(name='DP-1',disabled=False,mirrorOf='none'),dict(name='DP-2',disabled=False,mirrorOf='none')]
  code=api['workspace_command']([{'workspace':3,'monitor':'DP-2'}],monitors,[{'workspaceString':'3','enabled':True}])
  self.assertIn('hl.workspace_rule',code);self.assertIn('monitor = "DP-2"',code);self.assertNotIn('hl.monitor(',code);self.assertNotIn('hl.config(',code)
  for value in [True,0,11,'3']:
   with self.assertRaises(ValueError):api['workspace_command']([{'workspace':value,'monitor':'DP-1'}],monitors,[])
  with self.assertRaises(ValueError):api['workspace_command']([{'workspace':3,'monitor':'unknown'}],monitors,[])
  with self.assertRaises(ValueError):api['workspace_command']([{'workspace':3,'monitor':'DP-1'},{'workspace':3,'monitor':'DP-2'}],monitors,[])
  with self.assertRaises(ValueError):api['workspace_command']([{'workspace':3,'monitor':'DP-2'}],[monitors[0],{**monitors[1],'disabled':True}],[])
  with self.assertRaises(ValueError):api['workspace_command']([{'workspace':3,'monitor':'DP-1'}],monitors,[{'workspaceString':'3','gapsIn':[0,0,0,0]}])
  with patch.object(api['Path'], 'is_file', return_value=True):
   self.assertTrue(api['has_native_per_monitor_workspaces']())
  self.assertNotIn('hl.workspace_rule', api['build_block']({'monitors':[{'output':'DP-1'},{'output':'DP-2'}], 'manageWorkspaces':True, 'workspaces':[{'workspace':2,'monitor':'DP-2'}]}, native_per_monitor_workspaces=True))
if __name__=='__main__':unittest.main()
