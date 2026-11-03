#!/usr/bin/env python3
"""Draw new coordinate diagrams for sprite generation, without editing artwork."""
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
FRAMES={
    'north':(1200,1920,480,960,(0,-1),(1,0),(6.5,.5)),
    'east':(1920,1200,960,480,(1,0),(0,1),(.5,6.5)),
    'south':(1200,1920,720,960,(0,1),(-1,0),(-5.5,.5)),
    'west':(1920,1200,960,720,(-1,0),(0,-1),(.5,-5.5)),
}

def main():
    output=ROOT/'.tools/art-output/guides'
    output.mkdir(parents=True,exist_ok=True)
    for name,(width,height,ax,ay,forward,right,stock) in FRAMES.items():
        def point(along,across):
            return (ax+48*(along*forward[0]+across*right[0]),ay+48*(along*forward[1]+across*right[1]))
        def rect(along0,across0,along1,across1,fill,stroke):
            a,b=point(along0,across0),point(along1,across1)
            return f'<rect x="{min(a[0],b[0])}" y="{min(a[1],b[1])}" width="{abs(a[0]-b[0])}" height="{abs(a[1]-b[1])}" fill="{fill}" stroke="{stroke}" stroke-width="3"/>'
        svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',f'<rect width="{width}" height="{height}" fill="white"/>']
        svg.append(rect(-15,2,15,8.5,'#b9b4a5','#55564f'))
        svg.append(rect(-15,-3,15,-2,'#b9b4a5','#55564f'))
        svg.append(rect(-20,-1.65,20,1.65,'#d1e7f4','#39728e'))
        x,y=ax+48*stock[0],ay+48*stock[1]
        svg.append(f'<rect x="{x-75}" y="{y-75}" width="150" height="150" fill="white" stroke="#39728e" stroke-width="3"/>')
        svg.append(f'<circle cx="{ax}" cy="{ay}" r="6" fill="#39728e"/>')
        svg.append('</svg>')
        source=output/f'{name}.svg'
        source.write_text('\n'.join(svg))
        subprocess.run(['convert',str(source),str(output/f'{name}.png')],check=True)
        print(output/f'{name}.png')

if __name__=='__main__':main()
