#!/usr/bin/env python3
"""Run a real local player, GUI and personal robots on an isolated offscreen profile."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from factorio_test_engine import executable, isolated_environment
BINARY=executable(graphical=True)
def main():
    subprocess.run([str(ROOT/"build.sh"),"package"],check=True,stdout=subprocess.PIPE)
    info=json.loads((ROOT/"info.json").read_text())
    with tempfile.TemporaryDirectory(prefix="ct-visual-") as directory:
        work=Path(directory);mods=work/"mods";mods.mkdir();write=work/"write";write.mkdir()
        with zipfile.ZipFile(ROOT/"dist"/f"{info['name']}_{info['version']}.zip") as archive:archive.extractall(mods)
        mod=mods/f"{info['name']}_{info['version']}"
        with (mod/"control.lua").open("a") as f:f.write("\n"+(ROOT/"tests/visual.lua").read_text())
        (mods/"mod-list.json").write_text(json.dumps({"mods":[{"name":"base","enabled":True},{"name":info["name"],"enabled":True}]+[{"name":n,"enabled":False} for n in ("space-age","quality","elevated-rails","recycler")]}))
        config=work/"config.ini"
        config.write_text(f"[path]\nread-data={BINARY.parents[2]/'data'}\nwrite-data={write}\n[general]\nlocale=fr\n[other]\ncheck-updates=false\n[graphics]\nfull-screen=false\ngraphics-quality=normal\nmax-threads=4\n")
        env={**isolated_environment(),"SDL_VIDEODRIVER":"offscreen"}
        env.pop("DISPLAY",None);env.pop("WAYLAND_DISPLAY",None)
        base=[str(BINARY),"--config",str(config),"--mod-directory",str(mods),"--disable-audio"]
        created=subprocess.run(base+["--create",str(work/"test.zip")],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=55)
        if created.returncode:raise RuntimeError(created.stdout[-8000:])
        marker=write/"script-output/ct-visual-result.txt"
        preview=write/"script-output/construction-train-prototype.png"
        log_path=work/"visual.log"
        with log_path.open("w") as stream:
            process=subprocess.Popen(base+["--window-size","1280x900","--force-graphics-preset","very-low","--load-game",str(work/"test.zip")],env=env,stdout=stream,stderr=subprocess.STDOUT)
            deadline=time.monotonic()+55
            try:
                while time.monotonic()<deadline:
                    if marker.exists() and preview.exists() and preview.stat().st_size>1000:break
                    if process.poll() is not None or any(token in log_path.read_text() for token in ("non-recoverable error","Error while running event")):break
                    time.sleep(.2)
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:process.wait(timeout=5)
                    except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)
        log=log_path.read_text()
        (ROOT/"tests/last-visual.log").write_text(created.stdout+log)
        print("\n".join(l for l in log.splitlines() if "CT_VISUAL" in l),flush=True)
        if not(marker.exists() and marker.read_text()=="CT VISUAL OK\n" and preview.exists()):
            raise RuntimeError(log[-9000:])
        destination=ROOT/".tools/visual-output/prototype-preview.png"
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(preview,destination)
        print(str(destination),flush=True)
if __name__=="__main__":main()
