#!/usr/bin/env python3
"""Package/install this mod without touching unrelated installations."""
import json
import os
from pathlib import Path
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
def main():
    info=json.loads((ROOT/"info.json").read_text())
    name,version=info["name"],info["version"]
    action=sys.argv[1]
    beta=len(sys.argv)>2 and sys.argv[2]=="beta"
    if len(sys.argv)>3 or (len(sys.argv)>2 and (not beta or action!="package")):
        raise SystemExit("Usage: build.py package [beta]")
    original_name=name
    if beta:
        name="train-construct"
        info.update(name=name,title="Construction Train (Beta)",description="Beta, do not download")
    dist=ROOT/"dist"
    if action=="clean":
        shutil.rmtree(dist,ignore_errors=True)
    elif action=="package":
        dist.mkdir(exist_ok=True)
        target=dist/f"{name}_{version}.zip"
        with zipfile.ZipFile(target,"w",zipfile.ZIP_DEFLATED) as archive:
            paths=[ROOT/p for p in ("info.json","data.lua","data-updates.lua","data-final-fixes.lua","control.lua","README.md","LICENSE") if (ROOT/p).exists()]
            for directory in ("prototypes","scripts","locale","graphics"):
                paths.extend(p for p in (ROOT/directory).rglob("*") if p.is_file() and p.suffix in (".lua",".cfg",".png"))
            for p in sorted(paths):
                member=f"{name}_{version}/{p.relative_to(ROOT)}"
                if beta and p.name=="info.json":
                    archive.writestr(member,json.dumps(info,indent=2)+"\n")
                elif beta and p.suffix==".lua":
                    archive.writestr(member,p.read_text().replace(f"__{original_name}__",f"__{name}__"))
                else:
                    archive.write(p,member)
        print(target)
    else:
        mods=Path(os.environ.get("MODS_DIR",Path.home()/".factorio/mods"))
        mods.mkdir(parents=True,exist_ok=True)
        target=mods/name
        if target.is_symlink() and target.resolve()!=ROOT:
            raise SystemExit("Unrelated existing link: "+str(target))
        if target.exists() and not target.is_symlink():
            raise SystemExit("Unrelated existing installation: "+str(target))
        if action=="unlink":
            if target.is_symlink():target.unlink()
        else:
            shadows=list(mods.glob(name+"_*.zip"))
            if shadows:
                raise SystemExit("Remove or move shadowing archives explicitly first: "+", ".join(map(str,shadows)))
            if not target.is_symlink():target.symlink_to(ROOT,target_is_directory=True)
            print(str(target)+" -> "+str(ROOT))
if __name__=="__main__":main()
