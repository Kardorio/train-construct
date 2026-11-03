#!/usr/bin/env python3
"""Measure source art and transparent gaps without changing any pixels."""
from pathlib import Path
from PIL import Image
from collections import Counter

ROOT=Path(__file__).resolve().parents[2]
for path in sorted((ROOT/'graphics/entity/depot').glob('*.png')):
    with Image.open(path) as image:
        alpha=image.getchannel('A')
        solid=alpha.point(lambda value:255 if value>=230 else 0)
        horizontal='east' in path.name or 'west' in path.name
        step=max(1,(image.height if horizontal else image.width)//40)
        density=[]
        for coord in range(0,image.height if horizontal else image.width,step):
            line=solid.crop((0,coord,image.width,coord+1)) if horizontal else solid.crop((coord,0,coord+1,image.height))
            density.append((coord,sum(line.getdata())//255))
        red=[a for r,g,b,a in image.getdata() if r>150 and g<70 and b<70 and a>0]
        colors=Counter((r,g,b) for r,g,b,a in image.getdata() if a>0 and r>150 and g<70 and b<70)
        chroma=[a for r,g,b,a in image.getdata() if r>240 and g<15 and b<15 and a>0]
        print(path.name,image.size,'alpha',alpha.getextrema(),'solid',solid.getbbox(),'density',density,'red_alpha_counts',[(limit,sum(a>=limit for a in red)) for limit in (20,100,200,250)],'red_colors',colors.most_common(6),'pure_red_alpha',[(limit,sum(a>=limit for a in chroma)) for limit in (1,5,20,100,200,250)])
