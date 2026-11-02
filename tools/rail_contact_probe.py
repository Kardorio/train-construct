#!/usr/bin/env python3
"""Require bounded articulated-tool contact before every revival, on both train heads.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
from factorio_test_engine import executable
BINARY = executable()

def main():
    logs = []
    cases = [(heading, turn) for heading in (0, 4, 8, 12) for turn in (-1, 1)]
    if os.environ.get("CT_CONTACT_QUICK"):
        cases = [(8, 1)]
    for heading, turn in cases:
        print(f"Scénario orientation={heading}, virage={turn}", flush=True)
        with tempfile.TemporaryDirectory(prefix="ct-contact-") as directory:
            work = Path(directory)
            mod = work/"mods"/"ct-contact-probe_0.0.1"
            mod.mkdir(parents=True)
            write = work/"write"
            write.mkdir()
            (mod/"info.json").write_text(json.dumps({"name":"ct-contact-probe","version":"0.0.1","title":"CT contact probe","author":"kardagan","factorio_version":"2.1","dependencies":["base >= 2.1.0"]}))
            lua = (ROOT/"tools/probes/rail_contact.lua").read_text()
            (mod/"control.lua").write_text(f"local HEADING={heading}\nlocal TURN={turn}\n"+lua)
            (work/"mods"/"mod-list.json").write_text(json.dumps({"mods":[{"name":"base","enabled":True},{"name":"ct-contact-probe","enabled":True}]+[{"name":n,"enabled":False} for n in ("space-age","quality","elevated-rails","recycler")]}))
            config = work/"config.ini"
            config.write_text(f"[path]\nread-data={BINARY.parents[2]/'data'}\nwrite-data={write}\n[other]\ncheck-updates=false\n")
            base = [str(BINARY),"--config",str(config),"--mod-directory",str(work/"mods")]
            case_logs = []
            try:
                for arguments in (["--create",str(work/"probe.zip")],["--benchmark",str(work/"probe.zip"),"--benchmark-ticks","18001","--benchmark-runs","1"]):
                    result = subprocess.run(base+arguments,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=55)
                    logs.append(result.stdout)
                    case_logs.append(result.stdout)
                    if result.returncode:
                        raise RuntimeError(result.stdout[-7000:])
                combined = "".join(case_logs)
                assert "CT_CONTACT success " in combined, combined[-7000:]
                for line in combined.splitlines():
                    if "CT_CONTACT success " in line or "CT_CONTACT reverse_reached " in line:
                        print(line,flush=True)
            finally:
                (ROOT/"docs/rail-contact-results.txt").write_text("".join(logs))
    print(f"{len(cases)} scénarios de pose avec contact terminés ; mesures dans docs/rail-contact-results.txt.",flush=True)

if __name__ == "__main__":
    main()
