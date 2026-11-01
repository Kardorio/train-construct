#!/usr/bin/env python3
"""Replay a player's save in a temporary profile without modifying the original."""
import hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BINARY=Path(os.environ.get("FACTORIO_BIN",Path.home()/".steam/steam/steamapps/common/Factorio/bin/x64/factorio"))
def main():
    save=Path(sys.argv[1]).resolve()
    original=hashlib.sha256(save.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="ct-debug-save-") as directory:
        work=Path(directory);mods=work/"mods";mods.mkdir();write=work/"write";write.mkdir()
        installed=Path.home()/".factorio/mods"
        for item in installed.iterdir():
            if item.name=="construction-train" or item.name.startswith("construction-train_"):continue
            if item.name in ("mod-list.json","mod-settings.dat"):
                shutil.copy2(item,mods/item.name)
            elif item.is_dir() or item.suffix==".zip":(mods/item.name).symlink_to(item.resolve(),target_is_directory=item.is_dir())
        mod=mods/"construction-train";mod.mkdir()
        for name in ("info.json","data.lua","control.lua"):shutil.copy2(ROOT/name,mod/name)
        for name in ("scripts","prototypes","locale"):shutil.copytree(ROOT/name,mod/name)
        if "--baseline" in sys.argv:
            p=mod/"prototypes/entities.lua";p.write_text(p.read_text().replace('locomotive.max_power = "2400kW"','locomotive.max_power = "600kW"').replace('locomotive.braking_force = 40','locomotive.braking_force = 10'))
        with (mod/"control.lua").open("a") as stream:stream.write("\nlocal CT_IGNORE_SIGNALS="+str("--without-signals" in sys.argv).lower()+"\n"+(ROOT/"tools/probes/debug-save.lua").read_text())
        config=work/"config.ini";config.write_text(f"[path]\nread-data={BINARY.parents[2]/'data'}\nwrite-data={write}\n[other]\ncheck-updates=false\n")
        ticks=next((arg.split("=",1)[1] for arg in sys.argv if arg.startswith("--ticks=")),"9000")
        result=subprocess.run([str(BINARY),"--config",str(config),"--mod-directory",str(mods),"--disable-audio","--benchmark",str(save),"--benchmark-ticks",ticks,"--benchmark-runs","1"],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180)
        report=next((arg.split("=",1)[1] for arg in sys.argv if arg.startswith("--report=")),"debug-save-results.txt")
        assert Path(report).name==report
        target=ROOT/"docs"/report;target.write_text(result.stdout)
        print("\n".join(line for line in result.stdout.splitlines() if "CT_DEBUG" in line and ("PROGRESS" in line or "HOME" in line or "SIGNALS" in line))[-6000:],flush=True)
        if result.returncode:raise RuntimeError(result.stdout[-8000:])
        assert hashlib.sha256(save.read_bytes()).hexdigest()==original,"Original save was modified"
        if "--verify" in sys.argv:
            states=[json.loads(line.split("CT_DEBUG STATE ",1)[1]) for line in result.stdout.splitlines() if "CT_DEBUG STATE " in line]
            assert states and states[-1]["built"]>=states[0]["built"]+100,"Construction did not resume sufficiently"
            loading=[s for s in states if s["state"]=="loading" and s.get("arrival")=="refill"]
            assert loading and states[-1]["built"]>loading[0]["built"],"No actual refill and resumed construction"
            print("CT_DEBUG VERIFIED: progress, real refill, resumed construction, original save unchanged")
        print(target)
if __name__=="__main__":main()
