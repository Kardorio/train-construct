#!/usr/bin/env python3
"""Exercise the packaged mod; never change the player's active profile."""
import json
import os
from pathlib import Path
import subprocess
import socket
import time
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[1]
BINARY=Path(os.environ.get("FACTORIO_BIN",Path.home()/".steam/steam/steamapps/common/Factorio/bin/x64/factorio"))
def main():
    subprocess.run([str(ROOT/"build.sh"),"package"],check=True,stdout=subprocess.PIPE)
    info=json.loads((ROOT/"info.json").read_text())
    logs=[]
    with tempfile.TemporaryDirectory(prefix="construction-train-engine-") as directory:
        work=Path(directory);mods=work/"mods";mods.mkdir();write=work/"write";write.mkdir()
        with zipfile.ZipFile(ROOT/"dist"/f"{info['name']}_{info['version']}.zip") as archive:archive.extractall(mods)
        mod=mods/f"{info['name']}_{info['version']}"
        test_info=json.loads((mod/"info.json").read_text())
        test_info["spoiling_required"]=True
        (mod/"info.json").write_text(json.dumps(test_info))
        with (mod/"control.lua").open("a") as stream:stream.write("\n"+(ROOT/"tests/engine.lua").read_text())
        with (mod/"data.lua").open("a") as stream:
            stream.write('\ndata:extend{{type="item",name="ct-test-perishable-fuel",icon="__base__/graphics/icons/solid-fuel.png",icon_size=64,stack_size=100,fuel_categories={"chemical"},fuel_value="20MJ",spoil_ticks=360000,spoil_result="wood"}}\n')
        (mods/"mod-list.json").write_text(json.dumps({"mods":[{"name":"base","enabled":True},{"name":info["name"],"enabled":True},{"name":"quality","enabled":True},{"name":"recycler","enabled":True}]+[{"name":n,"enabled":False} for n in ("space-age","elevated-rails")]}))
        config=work/"config.ini";config.write_text(f"[path]\nread-data={BINARY.parents[2]/'data'}\nwrite-data={write}\n[other]\ncheck-updates=false\n")
        base=[str(BINARY),"--config",str(config),"--mod-directory",str(mods),"--disable-audio"]
        try:
            created=subprocess.run(base+["--create",str(work/"test.zip")],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=55)
            logs.append(created.stdout)
            if created.returncode:raise RuntimeError(created.stdout[-8000:])
            settings=work/"server-settings.json"
            settings.write_text(json.dumps({"name":"CT isolated runtime","description":"Local test only","visibility":{"public":False,"lan":False},"require_user_verification":False,"auto_pause":False,"autosave_interval":0}))
            with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as listener:
                listener.bind(("127.0.0.1",0))
                port=listener.getsockname()[1]
            live_log=work/"live.log"
            marker=write/"script-output/ct-engine-result.txt"
            with live_log.open("w") as output:
                process=subprocess.Popen(base+["--start-server",str(work/"test.zip"),"--server-settings",str(settings),"--bind","127.0.0.1","--port",str(port)],stdout=output,stderr=subprocess.STDOUT)
                try:
                    deadline=time.monotonic()+55
                    while time.monotonic()<deadline:
                        if marker.exists() or process.poll() is not None:break
                        if "Error while running event" in live_log.read_text():break
                        time.sleep(.2)
                finally:
                    if process.poll() is None:
                        process.terminate()
                        try:process.wait(timeout=5)
                        except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)
            output=live_log.read_text();logs.append(output)
            print("\n".join(l for l in output.splitlines() if "CT_TEST" in l),flush=True)
            assert marker.exists(),output[-8000:]
            assert "CT_TEST SUCCESS" in output,"Missing runtime completion marker"
            checkpoints=list(write.rglob("*ct-midmission*.zip"))
            assert checkpoints,"No actual mid-mission save produced"
            result=subprocess.run(base+["--benchmark",str(checkpoints[0]),"--benchmark-ticks","30001","--benchmark-runs","1"],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=55)
            logs.append(result.stdout)
            if result.returncode:raise RuntimeError(result.stdout[-8000:])
            assert "CT_TEST SUCCESS lifecycle" in result.stdout,"Reloaded mission did not finish"
            print("CT_TEST SUCCESS mid-mission reload",flush=True)
        finally:(ROOT/"tests/last-engine.log").write_text("".join(logs))
if __name__=="__main__":main()
