#!/usr/bin/env python3
"""Exercise the packaged mod; never change the player's active profile."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import shutil
import socket
import sys
import time
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from factorio_test_engine import executable
BINARY=executable()
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--scenario",choices=("engine","engine-north","engine-stop","singleton","concurrency","concurrency-keep"),default="engine")
    parser.add_argument("--mutation",choices=("unpaired-signal","wrong-signal-pair"))
    args=parser.parse_args()
    scenario=args.scenario
    if args.mutation and scenario!="engine-stop":parser.error("The signal mutation requires the stopped control scenario")
    subprocess.run([str(ROOT/"build.sh"),"package"],check=True,stdout=subprocess.PIPE)
    info=json.loads((ROOT/"info.json").read_text())
    logs=[]
    with tempfile.TemporaryDirectory(prefix="construction-train-engine-") as directory:
        work=Path(directory);mods=work/"mods";mods.mkdir();write=work/"write";write.mkdir()
        with zipfile.ZipFile(ROOT/"dist"/f"{info['name']}_{info['version']}.zip") as archive:archive.extractall(mods)
        mod=mods/f"{info['name']}_{info['version']}"
        if args.mutation=="unpaired-signal":
            worker=mod/"scripts/worker.lua"
            source=worker.read_text()
            guard="  if not paired then return false end"
            assert guard in source,"Signal guard not found"
            worker.write_text(source.replace(guard,""))
        elif args.mutation=="wrong-signal-pair":
            geometry=mod/"scripts/geometry.lua"
            source=geometry.read_text()
            guard="local incoming={ending.in_signal_location,ending.alternative_in_signal_location}"
            assert guard in source,"Pair location lookup not found"
            geometry.write_text(source.replace(guard,"local other=rail.get_rail_end(1-direction);local incoming={other.out_signal_location,other.alternative_out_signal_location}"))
        test_info=json.loads((mod/"info.json").read_text())
        test_info["spoiling_required"]=True
        (mod/"info.json").write_text(json.dumps(test_info))
        fixtures=mod/"test-fixtures";fixtures.mkdir()
        shutil.copy2(ROOT/"tests/fixtures/rail_loop.lua",fixtures/"rail_loop.lua")
        source=(ROOT/"tests"/("engine.lua" if scenario.startswith("engine") else "singleton.lua" if scenario=="singleton" else "concurrency.lua")).read_text()
        if scenario.startswith("engine"):source="local north="+str(scenario=="engine-north").lower()+";local stopped="+str(scenario=="engine-stop").lower()+"\n"+source
        if scenario.startswith("concurrency"):source="local keep_both="+str(scenario=="concurrency-keep").lower()+"\n"+source
        with (mod/"control.lua").open("a") as stream:stream.write("\n"+source)
        with (mod/"data.lua").open("a") as stream:
            stream.write('\ndata:extend{{type="item",name="ct-test-perishable-fuel",icon="__base__/graphics/icons/solid-fuel.png",icon_size=64,stack_size=100,fuel_categories={"chemical"},fuel_value="20MJ",spoil_ticks=360000,spoil_result="wood"}}\n')
        (mods/"mod-list.json").write_text(json.dumps({"mods":[{"name":"base","enabled":True},{"name":info["name"],"enabled":True},{"name":"quality","enabled":True},{"name":"recycler","enabled":True}]+[{"name":n,"enabled":False} for n in ("space-age","elevated-rails")]}))
        config=work/"config.ini";config.write_text(f"[path]\nread-data={BINARY.parents[2]/'data'}\nwrite-data={write}\n[other]\ncheck-updates=false\n")
        base=[str(BINARY),"--config",str(config),"--mod-directory",str(mods)]
        try:
            created=subprocess.run(base+["--create",str(work/"test.zip")],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=55)
            logs.append(created.stdout)
            if args.mutation=="wrong-signal-pair":
                assert created.returncode!=0 and "Other end was mistaken for a paired signal" in created.stdout,created.stdout[-8000:]
                print("CT_MUTATION rejected wrong-signal-pair",flush=True)
                return
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
            if args.mutation:
                assert "Unpaired signal built before rail frontiers completed" in output,output[-8000:]
                assert not marker.exists(),"Signal mutation was not rejected"
                print("CT_MUTATION rejected unpaired-signal",flush=True)
                return
            assert marker.exists(),output[-8000:]
            assert "CT_TEST SUCCESS" in output,"Missing runtime completion marker"
            checkpoints=list(write.rglob("*ct-midmission*.zip"))
            assert checkpoints,"No actual mid-mission save produced"
            result=subprocess.run(base+["--benchmark",str(checkpoints[0]),"--benchmark-ticks","6001","--benchmark-runs","1"],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=55)
            logs.append(result.stdout)
            if result.returncode:raise RuntimeError(result.stdout[-8000:])
            assert "CT_TEST SUCCESS lifecycle" in result.stdout,"Reloaded mission did not finish"
            print("CT_TEST SUCCESS mid-mission reload",flush=True)
        finally:(ROOT/"tests"/f"last-{scenario}{'-'+args.mutation if args.mutation else ''}.log").write_text("".join(logs))
if __name__=="__main__":main()
