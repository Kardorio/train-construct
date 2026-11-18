#!/usr/bin/env python3
"""Install the portal identity for local tests, keeping the released ZIP as backup."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[1]


def main():
    info=json.loads((ROOT/'info.json').read_text())
    name='train-construct'
    mods=Path(os.environ.get('MODS_DIR',Path.home()/'.factorio/mods'))
    target=mods/name
    stages=ROOT/'.tools/beta-dev'
    if target.is_symlink():
        if not target.resolve().is_relative_to(stages.resolve()):
            raise SystemExit(f'Unrelated existing link: {target}')
    elif target.exists():
        raise SystemExit(f'Unrelated existing installation: {target}')
    subprocess.run([str(ROOT/'build.sh'),'package','portal'],check=True)
    stages.mkdir(parents=True,exist_ok=True)
    work=Path(tempfile.mkdtemp(prefix='local-',dir=stages))
    with zipfile.ZipFile(ROOT/f"dist/{name}_{info['version']}.zip") as archive:
        archive.extractall(work)
    stage=work/f"{name}_{info['version']}"
    # Only the asset namespace adapters and identity are generated copies.
    for folder in ('graphics','scripts','locale'):
        shutil.rmtree(stage/folder)
        (stage/folder).symlink_to(ROOT/folder,target_is_directory=True)
    for source in ROOT.glob('*.lua'):
        installed=stage/source.name
        if installed.exists():installed.unlink()
        installed.symlink_to(source)
    for source in (ROOT/'prototypes').rglob('*.lua'):
        if '__construction-train__' not in source.read_text():
            installed=stage/source.relative_to(ROOT)
            installed.unlink()
            installed.symlink_to(source)
    (stage/'tools').mkdir()
    shutil.copy2(ROOT/'tools/build.py',stage/'tools/build.py')
    shutil.copy2(ROOT/'build.sh',stage/'build.sh')
    mods.mkdir(parents=True,exist_ok=True)
    shadows=list(mods.glob(name+'_*.zip'))
    if shadows:
        backup=Path(tempfile.mkdtemp(prefix='released-backup-',dir=stages))
        for archive in shadows:
            shutil.move(str(archive),backup/archive.name)
        print(f'Released ZIP backup: {backup}',flush=True)
    if target.is_symlink():target.unlink()
    subprocess.run([str(stage/'build.sh'),'devlink'],check=True,env={**os.environ,'MODS_DIR':str(mods)})


if __name__=='__main__':main()
