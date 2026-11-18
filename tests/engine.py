#!/usr/bin/env python3
"""Exercise the packaged mod; never change the player's active profile."""
import argparse
import fcntl
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
    parser.add_argument("--variant",choices=("prototype","portal","beta"),default="prototype")
    parser.add_argument("--scenario",choices=("engine","engine-north","engine-stop","singleton","filters","concurrency","concurrency-keep","module-north","module-east","module-south","module-west"),default="engine")
    parser.add_argument("--mutation",choices=("unpaired-signal","wrong-signal-pair","module-rollback","module-rollback-borrowed","module-rotation","module-foreign-traffic","module-foreign-borrowed","module-borrowed-rails","module-home-axis","module-damage-stop","filters-reservation","filters-load"))
    args=parser.parse_args()
    scenario=args.scenario
    if args.mutation in ("unpaired-signal","wrong-signal-pair") and scenario!="engine-stop":parser.error("The signal mutation requires the stopped control scenario")
    if args.mutation and args.mutation.startswith("module-") and scenario!="module-east":parser.error("Module mutations require the east-facing module scenario")
    if args.mutation and args.mutation.startswith("filters-") and scenario!="filters":parser.error("Filter mutations require the filters scenario")
    info=json.loads((ROOT/"info.json").read_text())
    if args.variant in ("portal","beta"):info.update(name="train-construct")
    logs=[]
    (ROOT/".tools").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="construction-train-engine-") as directory:
        work=Path(directory);mods=work/"mods";mods.mkdir();write=work/"write";write.mkdir()
        with (ROOT/".tools/engine-package.lock").open("w") as lock:
            fcntl.flock(lock,fcntl.LOCK_EX)
            subprocess.run([str(ROOT/"build.sh"),"package"]+(["portal"] if args.variant in ("portal","beta") else []),check=True,stdout=subprocess.PIPE)
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
        elif args.mutation and args.mutation.startswith("module-"):
            factory=mod/"scripts/factory.lua"
            changes={
                "module-rollback":("if layout then D.rollback(layout) end",""),
                "module-rotation":("entity.rotatable=false",""),
                "module-foreign-traffic":('if D.foreign_train(depot) then depot.state="occupied-track";return false end',""),
                "module-borrowed-rails":("rails=layout and layout.rails","rails=layout and layout.track"),
                "module-home-axis":("local mirror=G.offset(rail.position,frame,-20)","local mirror={x=rail.position.x,y=rail.position.y+20}"),
                "module-damage-stop":("for _,current in pairs(trains) do if #current.passengers==0 then current.manual_mode=true end end",""),
            }
            if args.mutation=="module-rollback-borrowed":
                factory=mod/"scripts/depot.lua"
                changes[args.mutation]=("function D.rollback(layout)","function D.rollback(layout)\n for _,rail in ipairs(layout.track) do if rail.valid then rail.destroy() end end")
            elif args.mutation=="module-foreign-borrowed":
                factory=mod/"scripts/depot.lua"
                changes[args.mutation]=("local track=depot.track or depot.rails","local track=depot.rails")
            old,new=changes[args.mutation]
            source=factory.read_text();assert old in source,"Module guard not found"
            factory.write_text(source.replace(old,new))
        elif args.mutation and args.mutation.startswith("filters-"):
            if args.mutation=="filters-reservation":
                path=mod/"scripts/registry.lua"
                old="depot.bot_enabled and Categories.allowed(depot,name)"
                new="depot.bot_enabled"
            else:
                path=mod/"scripts/inventory.lua"
                old='if Categories.allowed(depot,name) then I.transfer(source,target,name,"normal",math.max(0,count-target.get_item_count{name=name,quality="normal"})) end'
                new='I.transfer(source,target,name,"normal",math.max(0,count-target.get_item_count{name=name,quality="normal"}))'
            source=path.read_text();assert old in source,"Filter guard not found"
            path.write_text(source.replace(old,new))
        test_info=json.loads((mod/"info.json").read_text())
        test_info["spoiling_required"]=True
        (mod/"info.json").write_text(json.dumps(test_info))
        fixtures=mod/"test-fixtures";fixtures.mkdir()
        shutil.copy2(ROOT/"tests/fixtures/rail_loop.lua",fixtures/"rail_loop.lua")
        shutil.copy2(ROOT/"tests/circuit_stock.lua",fixtures/"circuit_stock.lua")
        source=(ROOT/"tests"/("engine.lua" if scenario.startswith("engine") else "depot_module.lua" if scenario.startswith("module-") else "filters.lua" if scenario=="filters" else "singleton.lua" if scenario=="singleton" else "concurrency.lua")).read_text()
        if scenario.startswith("module-"):source="local native_player=true;local heading="+str({"module-north":0,"module-east":4,"module-south":8,"module-west":12}[scenario])+"\n"+source
        if scenario.startswith("engine"):source="local north="+str(scenario=="engine-north").lower()+";local stopped="+str(scenario=="engine-stop").lower()+"\n"+source
        if scenario.startswith("concurrency"):source="local keep_both="+str(scenario=="concurrency-keep").lower()+"\n"+source
        with (mod/"control.lua").open("a") as stream:stream.write("\n"+source)
        with (mod/"data.lua").open("a") as stream:
            stream.write('\nassert(data.raw.locomotive["ct-construction-locomotive"].wheels,"Construction locomotive lost native bogies and couplers")\nassert(data.raw["cargo-wagon"]["ct-construction-wagon"].wheels,"Construction wagon lost native bogies and couplers")\n')
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
            if scenario.startswith("module-"):
                result=subprocess.run(base+["--test-save",str(work/"test.zip"),"--test-ticks","6001"],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=55)
                logs.append(result.stdout)
                print("\n".join(line for line in result.stdout.splitlines() if "CT_TEST" in line),flush=True)
                if args.mutation:
                    expected={"module-rollback":"Rejected module left partial components","module-rollback-borrowed":"Module rollback destroyed a borrowed rail","module-rotation":"Placed module rotated without its components","module-foreign-traffic":"Foreign train did not defer module recovery","module-foreign-borrowed":"Foreign traffic on borrowed rails did not defer recovery","module-borrowed-rails":"Module claimed the player's existing rails","module-home-axis":"Module has no mirrored docking goal","module-damage-stop":"Damaged module left its native train running automatically"}[args.mutation]
                    assert result.returncode!=0 and expected in result.stdout,result.stdout[-8000:]
                    print("CT_MUTATION rejected "+args.mutation,flush=True)
                    return
                assert result.returncode==0 and "CT_TEST SUCCESS lifecycle" in result.stdout,result.stdout[-8000:]
                marker=write/"script-output/ct-engine-result.txt"
                assert marker.exists(),"Native module test did not complete"
                marker.unlink()
                control=mod/"control.lua"
                control.write_text(control.read_text().replace("local native_player=true;local heading=","local native_player=false;local heading="))
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
                if args.mutation.startswith("filters-"):
                    expected="Rail reservation disagrees with category filter" if args.mutation=="filters-reservation" else "Excluded item loaded"
                    assert expected in output and not marker.exists(),output[-8000:]
                    print("CT_MUTATION rejected "+args.mutation,flush=True)
                    return
                assert "Unpaired signal built before rail frontiers completed" in output,output[-8000:]
                assert not marker.exists(),"Signal mutation was not rejected"
                print("CT_MUTATION rejected unpaired-signal",flush=True)
                return
            assert marker.exists(),output[-8000:]
            assert "CT_TEST SUCCESS" in output,"Missing runtime completion marker"
            checkpoints=list(write.rglob("*ct-midmission*.zip"))
            assert checkpoints,"No actual mid-mission save produced"
            result=subprocess.run(base+["--benchmark",str(checkpoints[0]),"--benchmark-ticks","12001" if scenario=="filters" else "6001","--benchmark-runs","1"],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=55)
            logs.append(result.stdout)
            if result.returncode:raise RuntimeError(result.stdout[-8000:])
            assert "CT_TEST SUCCESS lifecycle" in result.stdout,"Reloaded mission did not finish"
            print("CT_TEST SUCCESS mid-mission reload",flush=True)
        finally:(ROOT/"tests"/f"last-{scenario}{'-'+args.mutation if args.mutation else ''}{'-beta' if args.variant=='beta' else ''}.log").write_text("".join(logs))
if __name__=="__main__":main()
