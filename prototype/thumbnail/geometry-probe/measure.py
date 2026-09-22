#!/usr/bin/env python3
"""Measure the known calibration card; optionally fail on nonuniform scaling."""
import argparse, json
from pathlib import Path
from PIL import Image

p=argparse.ArgumentParser()
p.add_argument('image',type=Path)
p.add_argument('--settings',action='store_true',help='Exclude saver catalog tiles below the live image')
p.add_argument('--verify-uniform',action='store_true')
args=p.parse_args()
image=Image.open(args.image).convert('RGB')
w,h=image.size
limit=h//4 if args.settings else h
points=set()
for y in range(limit):
    for x in range(w):
        r,g,b=image.getpixel((x,y))
        if r<100 and g>170 and b>170: points.add((x,y))
components=[]
while points:
    seed=points.pop(); stack=[seed]; component=[seed]
    while stack:
        x,y=stack.pop()
        for other in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
            if other in points:
                points.remove(other); stack.append(other); component.append(other)
    if len(component)>=8:
        xs,ys=zip(*component)
        components.append(dict(center=[(min(xs)+max(xs)+1)/2,(min(ys)+max(ys)+1)/2],bounds=[min(xs),min(ys),max(xs)+1,max(ys)+1]))
assert len(components)==4, f'Expected four corner markers, found {len(components)}'
components.sort(key=lambda c:c['center'][1])
top=sorted(components[:2],key=lambda c:c['center'][0])
bottom=sorted(components[2:],key=lambda c:c['center'][0])
sx=sum(row[1]['center'][0]-row[0]['center'][0] for row in [top,bottom])/2/1660
sy=sum(bottom[i]['center'][1]-top[i]['center'][1] for i in range(2))/2/820
left=sum(row[0]['center'][0] for row in [top,bottom])/2-130*sx
upper=sum(c['center'][1] for c in top)/2-130*sy
ratio=sx/sy
result=dict(image=args.image.name,screenshot_size=[w,h],corner_markers=top+bottom,source_size=[1920,1080],scale_x=sx,scale_y=sy,horizontal_to_vertical_scale=ratio,inferred_content_rect=[left,upper,1920*sx,1080*sy],uniform_within_2_percent=abs(ratio-1)<=.02)
print(json.dumps(result,indent=2))
if args.verify_uniform and not result['uniform_within_2_percent']:
    p.exit(1,f'FAIL: horizontal scale is {ratio:.3f} of vertical scale (expected 1.000 ± 0.020)\n')
