#!/usr/bin/env python3
"""Build a standalone SVG inspection page from the tested sprite contract."""
import hashlib
import json
from pathlib import Path

import prepare_sprites as prepare

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/depot-sprite-preview.html"


def main():
    contract = prepare.preview(prepare.metadata())
    assert prepare.OUTPUT.read_text() == prepare.content(), "Lua layout is stale"
    for spec in contract["depot"].values():
        assert hashlib.sha256((ROOT/spec["source"]).read_bytes()).hexdigest() == spec["sha256"]
    payload = json.dumps(contract, ensure_ascii=False).replace("<", "\\u003c")
    page = '''<!doctype html>
<html lang="fr"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dépôt — aperçu des sprites natifs</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#201d19;color:#e9dfcd;font:15px system-ui,sans-serif}
header{padding:24px 28px 12px;max-width:1200px;margin:auto}h1{font-size:24px;margin:0 0 12px}
p{line-height:1.5;margin:8px 0}.muted{color:#c4b8a4}nav{display:flex;gap:22px;flex-wrap:wrap;margin:18px 0}
label{cursor:pointer}main{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px;padding:16px 28px 28px;max-width:1400px;margin:auto}
figure{margin:0;border:1px solid #65533f;background:#30271e;border-radius:8px;overflow:hidden}
figcaption{padding:12px 16px;background:#29231d}h2{font-size:18px;margin:0 0 4px}
svg.world{display:block;width:100%;height:auto}.guides{pointer-events:none}.off{display:none}
.corridor{stroke:#9fc9a5}.crop{stroke:#76c9ee}.nominal{stroke:#e8d4aa}
@media(max-width:760px){main{grid-template-columns:1fr;padding:12px}header{padding:20px}}
</style>
<header><h1>Aperçu hors jeu des sprites réellement branchés au mod</h1>
<p>Recomposition des PNG sources par les rectangles, échelles et décalages du contrat Lua testé.
Ce document n’est pas une capture de Factorio ; les rails sont des repères schématiques.</p>
<p class="muted">Chaque vue couvre 40 × 40 cases. Grille : 1 case. Origine du module : (0, 0) ;
centre de voie : (1, 1). Longueur calibrée : 32 cases ; couloir libre : ±1,5 case.
Les toitures peuvent déborder de la sélection nominale de 12 × 32 cases.</p>
<p>Le bâtiment représente le stock intégré. Les poutres et les dalles restent complètes ;
un sol métallique relie les deux côtés sous les vrais rails.</p>
<nav><label><input id="guides" type="checkbox" checked> Repères</label>
<label><input id="crops" type="checkbox"> Rectangles natifs</label></nav>
<p class="muted">Vert : couloir du train ; beige : sélection nominale ; bleu : rectangles sources.</p></header>
<main id="views"></main>
<script id="sprite-contract" type="application/json">__CONTRACT__</script>
<script>
const model=JSON.parse(document.getElementById('sprite-contract').textContent);
const ns='http://www.w3.org/2000/svg';
function node(tag,attrs={},parent){const el=document.createElementNS(ns,tag);
  for(const [k,v] of Object.entries(attrs))el.setAttribute(k,v);if(parent)parent.append(el);return el;}
function rect(parent,x,y,width,height,attrs={}){return node('rect',{x,y,width,height,...attrs},parent);}
function line(parent,x1,y1,x2,y2,attrs={}){return node('line',{x1,y1,x2,y2,...attrs},parent);}
function sprite(parent,spec,picture,center=[0,0]){
  const unit=picture.scale/32,w=picture.width*unit,h=picture.height*unit;
  const x=center[0]+picture.shift[0]-w/2,y=center[1]+picture.shift[1]-h/2;
  const frame=node('svg',{x,y,width:w,height:h,viewBox:[picture.x,picture.y,picture.width,picture.height].join(' '),
    preserveAspectRatio:'none',overflow:'hidden'},parent);
  node('image',{href:'../'+spec.source,x:0,y:0,width:spec.size[0],height:spec.size[1]},frame);
  return [x,y,w,h];
}
const labels={north:'Nord — atelier à l’est',east:'Est — atelier au sud',south:'Sud — atelier à l’ouest',west:'Ouest — atelier au nord'};
const footprints={north:[-3,-16,12,32],east:[-16,-3,32,12],south:[-9,-16,12,32],west:[-16,-9,32,12]};
for(const direction of ['north','east','south','west']){
  const spec=model.depot[direction],horizontal=['east','west'].includes(direction);
  const figure=document.createElement('figure'),caption=document.createElement('figcaption');
  const heading=document.createElement('h2');heading.textContent=labels[direction];caption.append(heading);
  caption.append(`Stock intégré au bâtiment · ${spec.layers.length} rectangles natifs`);
  figure.append(caption);document.getElementById('views').append(figure);
  const svg=node('svg',{class:'world',viewBox:'-20 -20 40 40',role:'img','aria-label':labels[direction]},figure);
  node('title',{},svg).textContent=labels[direction]+' — aperçu hors jeu';
  rect(svg,-20,-20,40,40,{fill:'#594533'});
  const grid=node('g',{stroke:'#a78b65','stroke-width':.025,opacity:.28},svg);
  for(let i=-20;i<=20;i++){line(grid,i,-20,i,20);line(grid,-20,i,20,i);}
  const floor=model.floor[direction];for(const layer of floor.layers)sprite(svg,floor,layer);
  const rails=node('g',{stroke:'#b9b4a7','stroke-width':.08},svg);
  for(let i=-16;i<=16;i++){
    if(horizontal)line(rails,i+1,0,i+1,2,{stroke:'#32291e','stroke-width':.17});
    else line(rails,0,i+1,2,i+1,{stroke:'#32291e','stroke-width':.17});
  }
  for(const offset of [-.5,.5]){
    if(horizontal)line(rails,-15,1+offset,17,1+offset);else line(rails,1+offset,-15,1+offset,17);
  }
  const crops=[];for(const layer of spec.layers)crops.push(sprite(svg,spec,layer));
  const guides=node('g',{class:'guides',fill:'none','stroke-width':.065},svg);
  rect(guides,...footprints[direction],{class:'nominal','stroke-dasharray':'.3 .2'});
  rect(guides,...(horizontal?[-15,-.5,32,3]:[-.5,-15,3,32]),{class:'corridor'});
  for(const [x,y,color] of [[0,0,'#fff1cd'],[1,1,'#b2ecb2']]){
    line(guides,x-.3,y,x+.3,y,{stroke:color});line(guides,x,y-.3,x,y+.3,{stroke:color});
  }
  const outlines=node('g',{class:'crops off',fill:'none','stroke-width':.045},svg);
  for(const crop of crops)rect(outlines,...crop,{class:'crop'});
}
for(const name of ['guides','crops'])document.getElementById(name).addEventListener('change',event=>{
  document.querySelectorAll('svg .'+name).forEach(el=>el.classList.toggle('off',!event.target.checked));
});
</script></html>
'''
    OUTPUT.write_text(page.replace("__CONTRACT__", payload))
    print(OUTPUT)


if __name__ == "__main__":
    main()
