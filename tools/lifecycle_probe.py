#!/usr/bin/env python3
"""Check robot-reservation reversal and local inventory recovery in the engine."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BINARY = Path(os.environ.get("FACTORIO_BIN", Path.home()/".steam/steam/steamapps/common/Factorio/bin/x64/factorio"))

def main():
    logs = []
    friendly = bool(os.environ.get("CT_FRIENDLY"))
    cases = [(0, 1)]
    if os.environ.get("CT_LIFECYCLE_QUICK"):
        cases = [(8, 1)]
    for heading, turn in cases:
        print(f"Scénario robots et récupération locale", flush=True)
        with tempfile.TemporaryDirectory(prefix="ct-lifecycle-") as directory:
            work = Path(directory)
            mod = work/"mods"/"ct-lifecycle-probe_0.0.1"
            mod.mkdir(parents=True)
            write = work/"write"
            write.mkdir()
            (mod/"info.json").write_text(json.dumps({"name":"ct-lifecycle-probe","version":"0.0.1","title":"CT lifecycle probe","author":"kardagan","factorio_version":"2.1","dependencies":["base >= 2.1.0"]}))
            lua = (ROOT/"tools/probes/lifecycle.lua").read_text()
            (mod/"control.lua").write_text(f"local FRIENDLY={str(friendly).lower()}\nlocal HEADING={heading}\nlocal TURN={turn}\n"+lua)
            (work/"mods"/"mod-list.json").write_text(json.dumps({"mods":[{"name":"base","enabled":True},{"name":"ct-lifecycle-probe","enabled":True}]+[{"name":n,"enabled":False} for n in ("space-age","quality","elevated-rails","recycler")]}))
            config = work/"config.ini"
            config.write_text(f"[path]\nread-data={BINARY.parents[2]/'data'}\nwrite-data={write}\n[other]\ncheck-updates=false\n")
            base = [str(BINARY),"--config",str(config),"--mod-directory",str(work/"mods"),"--disable-audio"]
            case_logs = []
            try:
                for arguments in (["--create",str(work/"probe.zip")],["--benchmark",str(work/"probe.zip"),"--benchmark-ticks","7201","--benchmark-runs","1"]):
                    result = subprocess.run(base+arguments,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=55)
                    logs.append(result.stdout)
                    case_logs.append(result.stdout)
                    if result.returncode:
                        raise RuntimeError(result.stdout[-7000:])
                combined = "".join(case_logs)
                assert "CT_LIFECYCLE success " in combined, combined[-7000:]
                for line in combined.splitlines():
                    if "CT_LIFECYCLE success " in line or "CT_LIFECYCLE reverse_reached " in line:
                        print(line,flush=True)
            finally:
                (ROOT/("docs/lifecycle-friendly-results.txt" if friendly else "docs/lifecycle-results.txt")).write_text("".join(logs))
    print(f"{len(cases)} scénario de cycle de vie terminé ; résultats dans docs/lifecycle-friendly-results.txt si CT_FRIENDLY=1, sinon docs/lifecycle-results.txt.",flush=True)

if __name__ == "__main__":
    main()
