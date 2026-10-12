#!/usr/bin/env python3
"""Reproductions for stale unchanged baseline and hotplug rollback; no compositor calls."""
import json,os,runpy,tempfile,unittest
from pathlib import Path
from unittest import mock
repo=Path(__file__).resolve().parents[1]
class ReviewRegressions(unittest.TestCase):
 def test_unchanged_display_disabled_after_draft_rejects_before_mutation(self):
  api=runpy.run_path(str(repo/'scripts/rise-display-manager-apply'))
  live=[dict(name=n,width=1000,height=1000,x=i*1000,y=0,scale=1,transform=0,refreshRate=60,disabled=False,mirrorOf='none') for i,n in enumerate(['A','B'])]
  entries=api['layout_snapshot'](live);entries[0]['disabled']=True;live[1]['disabled']=True
  with self.assertRaisesRegex(ValueError,'changed|baseline|refresh'):
   api['preview_command']({'monitors':entries,'changed':['A']},live)
 def test_unchanged_display_repositioned_after_draft_rejects(self):
  api=runpy.run_path(str(repo/'scripts/rise-display-manager-apply'))
  live=[dict(name=n,width=1000,height=1000,x=i*1000,y=0,scale=1,transform=0,refreshRate=60,disabled=False,mirrorOf='none') for i,n in enumerate(['A','B'])]
  entries=api['layout_snapshot'](live);entries[0]['position']='0x100';live[1]['x']=1200
  with self.assertRaises(ValueError):api['preview_command']({'monitors':entries,'changed':['A']},live)
 def test_disconnected_output_does_not_abandon_surviving_output(self):
  guard=runpy.run_path(str(repo/'scripts/rise-display-manager-guard'));api=guard['api']
  original=[dict(name=n,width=1000,height=1000,x=i*1000,y=0,scale=1,transform=0,refreshRate=60,disabled=False,mirrorOf='none') for i,n in enumerate(['A','B'])]
  current=[{**original[0],'y':100}];data={'before':original,'status':'pending'};calls=[]
  def run(argv,**kwargs):
   calls.append(argv);current[0]['y']=0;return mock.Mock(stdout='ok')
  with mock.patch.dict(guard['restore'].__globals__,monitors=lambda:current,write_state=lambda *args:None),mock.patch.dict(api,run=run):guard['restore'](0,data)
  self.assertEqual(current[0]['y'],0);self.assertEqual(len(calls),1,'Surviving output must receive rollback');self.assertNotIn('output = "B"',calls[0][2]);self.assertNotEqual(data['status'],'reverted','Disconnected output cannot be declared restored');self.assertIn('B',data.get('error',''))
if __name__=='__main__':unittest.main()
