#!/usr/bin/env python3
"""PROTOTYPE — throwaway. Expands a round's manifest (round-N.json: candidates,
each with alternatives and a chosen one) into the capture/render list
(round-N.tsv, every alternative, chosen flagged) and the viewer's data
(viewer/data.js).   usage: manifest.py round-2.json
"""
import json, sys
path = sys.argv[1]
m = json.load(open(path))
round_name = path.rsplit('/', 1)[-1].replace('.json', '')
rows = ['# id\tname\tpalette\tinner\touter\taccent\tidea\tchosen']
for c in m['candidates']:
    for a in c['alternatives']:
        f = a['flags']
        chosen = '1' if a['id'] == c.get('chosen') else '0'
        idea = ' '.join(f"{c['title']}: {a['rationale']}".split())   # one line, no tabs
        rows.append('\t'.join([a['id'], a['name'], f['palette'], f['inner'], f['outer'], f['accent'], idea, chosen]))
open(path.replace('.json', '.tsv'), 'w').write('\n'.join(rows) + '\n')
m['round'] = round_name
open('viewer/data.js', 'w').write('window.THEMES = ' + json.dumps(m, indent=1, ensure_ascii=False) + ';\n')
print(f"{round_name}: {len(m['candidates'])} candidates, {len(rows) - 1} alternatives")
