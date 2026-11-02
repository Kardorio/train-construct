"""Resolve test engines without starting the player's Steam game."""
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def isolated_environment():
    environment = dict(os.environ)
    for name in ("SteamAppId", "SteamGameId", "SteamOverlayGameId"):
        environment.pop(name, None)
    return environment


def executable(graphical=False):
    variable = "FACTORIO_GUI_BIN" if graphical else "FACTORIO_BIN"
    edition = "factorio-standalone" if graphical else "factorio-headless"
    candidate = os.environ.get(variable) or (os.environ.get("FACTORIO_BIN") if graphical else None)
    binary = Path(candidate) if candidate else ROOT / ".tools" / edition / "bin/x64/factorio"
    binary = binary.expanduser().resolve()
    if any(part.lower() in ("steamapps", ".steam") for part in binary.parts) or (binary.parent / "libsteam_api.so").exists():
        raise SystemExit("Lancement Steam refusé pour les tests. Utiliser le moteur serveur officiel ou une version autonome de Factorio.")
    if not binary.is_file():
        raise SystemExit(f"Moteur de test absent : {binary}. Installer la version {'autonome graphique' if graphical else 'serveur sans Steam'} ou définir {variable}.")
    version = subprocess.run([str(binary), "--version"], env=isolated_environment(), capture_output=True, text=True, check=True, timeout=10).stdout.lower()
    if "steam" in version or not version.startswith("version: "):
        raise SystemExit("Moteur Steam ou non reconnu : lancement du test refusé.")
    if graphical and "headless" in version:
        raise SystemExit("Les tests graphiques exigent une version autonome avec graphismes ; définir FACTORIO_GUI_BIN. Aucun jeu Steam n'a été lancé.")
    return binary
