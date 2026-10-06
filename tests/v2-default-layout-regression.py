#!/usr/bin/env python3
"""Verify V2 startup and reset defaults against the approved bar snapshot."""
import json
from pathlib import Path
import re
import subprocess
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'versions/V1/variants/V2/BarSlot.qml'
EXPECTED = 'B:G1,B:G2,B:G3,B:_,B:G5,B:G6,B:G4,B:G7,B:_,B:_|B:G8|B:G9,B:G10,B:G20,B:G14,B:G12,B:G13,B:G11,E:G18,E:G19,E:G16,E:G17,E:G15,E:G21'

def function(source, name):
    start = re.search(r'function ' + name + r'\([^)]*\)\s*\{', source)
    assert start, name
    depth = 1
    index = start.end()
    while depth:
        depth += (source[index] == '{') - (source[index] == '}')
        index += 1
    return source[start.start():index]

class V2DefaultLayoutTest(unittest.TestCase):
    def test_startup_models_match_approved_snapshot(self):
        source = SOURCE.read_text()
        regions = []
        for name in ['leftModel', 'centerModel', 'rightModel']:
            start = re.search(r'ListModel\s*\{\s*id: ' + name + r'\b', source)
            assert start
            index, depth = start.end(), 1
            while depth:
                depth += (source[index] == '{') - (source[index] == '}')
                index += 1
            rows = re.findall(r'ListElement\s*\{\s*gid:\s*"([^"]*)";\s*extra:\s*(true|false)', source[start.end():index])
            regions.append(','.join(('E:' if extra == 'true' else 'B:') + (gid or '_') for gid, extra in rows))
        self.assertEqual('|'.join(regions), EXPECTED)

    def test_default_layout_reset_matches_approved_snapshot(self):
        source = SOURCE.read_text()
        program = '''
const model = () => ({rows:[],clear(){this.rows=[]},append(row){this.rows.push(row)}});
const leftModel=model(), centerModel=model(), rightModel=model();
const leftBaseSlotCount=10, centerBaseSlotCount=1, rightBaseSlotCount=7;
const _orderLoaded=true; let saved=0; function saveOrder(){saved++}
'''
        program += function(source, 'resetModel') + '\n' + function(source, 'resetOrder')
        program += '''
resetOrder();
console.log(JSON.stringify({order:[leftModel,centerModel,rightModel].map(m=>m.rows.map(r=>(r.extra?'E:':'B:')+(r.gid||'_')).join(',')).join('|'),saved}));
'''
        result = subprocess.run(['node', '-e', program], check=True, capture_output=True, text=True)
        actual = json.loads(result.stdout)
        self.assertEqual(actual['order'], EXPECTED)
        self.assertEqual(actual['saved'], 1)

if __name__ == '__main__':
    unittest.main()
