#!/usr/bin/env python3
"""Keep each generated view's complete instructions beside the source assets."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
VIEWS={
    'north':"Orientation NORD : couloir VERTICAL, atelier principal à DROITE, bordure basse à GAUCHE. En haut de l'atelier : faisceaux de rails et rack à signaux ; en bas : portique de manutention. Le cadre final est vertical, au même rapport 1200 × 1920 que le diagramme.",
    'east':"Orientation EST : couloir HORIZONTAL, atelier principal EN BAS, bordure basse EN HAUT. À droite de l'atelier : faisceaux de rails et rack à signaux ; à gauche : portique de manutention. Le cadre final est horizontal, au même rapport 1920 × 1200 que le diagramme. Montrer le même atelier ouvert depuis ce côté, sans inventer une grande paroi aveugle.",
    'south':"Orientation SUD : couloir VERTICAL, atelier principal à GAUCHE, bordure basse à DROITE. En bas de l'atelier : faisceaux de rails et rack à signaux ; en haut : portique de manutention. Le cadre final est vertical, au même rapport 1200 × 1920 que le diagramme.",
    'west':"Orientation OUEST : couloir HORIZONTAL, atelier principal EN HAUT, bordure basse EN BAS, comme la référence artistique. À gauche de l'atelier : faisceaux de rails et rack à signaux ; à droite : portique de manutention. Le cadre final est horizontal, au même rapport 1920 × 1200 que le diagramme.",
}

def main():
    base=(ROOT/'tools/art/depot-sprite-base.prompt.txt').read_text()
    output=ROOT/'tools/art/prompts'
    output.mkdir(exist_ok=True)
    for direction,detail in VIEWS.items():
        (output/f'depot-{direction}.prompt.txt').write_text(base+'\n'+detail+'\n')

if __name__=='__main__':main()
