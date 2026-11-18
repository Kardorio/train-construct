#!/usr/bin/env python3
"""Prove the focused regression tests fail when each reviewed defect is restored."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
def main():
    for defect in ("force-scoped-fleet","detached-occupant","double-refund","blocked-worker","premature-accessories","lost-anchor","single-docking","lost-return","historical-frontiers","accessory-id-order","accessory-contact-trip","foreign-frontier-revision","sleeping-accessory","merged-frontier-cache","manual-takeover","building-quality"):
        with tempfile.TemporaryDirectory(prefix="ct-regression-") as directory:
            work=Path(directory)
            shutil.copytree(ROOT/"scripts",work/"scripts")
            factory=work/"scripts/factory.lua"
            worker=work/"scripts/worker.lua"
            if defect=="force-scoped-fleet":
                source=factory.read_text()
                old="if id~=depot.id and other.surface_index==depot.surface_index then"
                assert source.count(old)==1,"Planet limit mutation hook changed"
                factory.write_text(source.replace(old,"if id~=depot.id and other.force_index==depot.force_index and other.surface_index==depot.surface_index then"))
            elif defect=="manual-takeover":
                worker.write_text(worker.read_text().replace(' if d.auto_controlled and t.manual_mode then W.pause(d);return end',''))
            elif defect=="building-quality":
                factory.write_text(factory.read_text().replace('stack={name=C.depot,count=1,quality=depot.quality}','stack={name=C.depot,count=1}'))
            elif defect=="merged-frontier-cache":
                registry=work/"scripts/registry.lua"
                source=registry.read_text()
                start=source.index("function R.change_domain")
                end=source.index("function R.track",start)
                registry.write_text(source[:start]+source[start:end].replace("frontier_changed(record)","")+source[end:])
            elif defect=="foreign-frontier-revision":
                registry=work/"scripts/registry.lua"
                registry.write_text(registry.read_text().replace("state.frontier_domains[key]={revision=state.frontier_sequence}","state.frontier_domains={};state.frontier_domains[key]={revision=state.frontier_sequence}"))
            elif defect=="sleeping-accessory":
                worker.write_text(worker.read_text().replace("local function accessory(d)\n","local function accessory(d)\n if game.tick<(d.accessory_wait or 0) then return nil end\n"))
            elif defect=="historical-frontiers":
                registry=work/"scripts/registry.lua"
                registry.write_text(registry.read_text().replace("return cache.ids,cache.revision","return state.frontier_order,cache.revision"))
            elif defect=="accessory-id-order":
                worker.write_text(worker.read_text().replace("if a.distance~=b.distance then return a.distance<b.distance end",""))
            elif defect=="accessory-contact-trip":
                worker.write_text(worker.read_text().replace("if first.contact and train(d).speed==0 and claim(d,first.id) then","if false then"))
            elif defect=="detached-occupant":
                s=factory.read_text()
                start=s.index(" local trains={}",s.index("function F.withdraw"))
                end=s.index(" local surface=",start)
                s=s[:start]+""" local t=depot.head.train
 if #t.passengers>0 then return false end
 t.manual_mode=true
 if t.speed~=0 then return false end
"""+s[end:]
                factory.write_text(s)
            elif defect=="double-refund":
                s=factory.read_text()
                start=s.index(' if origin=="mined"')
                end=s.index(" R.policy(depot,false)",start)
                factory.write_text(s[:start]+" depot.refund=depot.refund or refund\n"+s[end:])
            elif defect=="lost-return":
                s=worker.read_text()
                worker.write_text(s.replace(' or d.arrival=="retreat"',''))
            elif defect=="lost-anchor":
                s=worker.read_text()
                worker.write_text(s.replace("if not eligible or index>#frontier.anchors then","if not eligible or index>#frontier.anchors or #goals>=16 then"))
            elif defect=="single-docking":
                s=factory.read_text()
                factory.write_text(s.replace(" return goals\nend\nfunction F.at_home"," return {goals[1]}\nend\nfunction F.at_home"))
            elif defect=="premature-accessories":
                s=worker.read_text()
                start=s.index(" if #goals==0 then\n",s.index("local function dispatch(d)"))
                end=s.index(" storage.ct.path_budget=",start)
                block=s[start:end]
                old="  return nil\n end\n"
                assert block.count(old)==1,"Incomplete frontier page mutation hook changed"
                worker.write_text(s[:start]+block.replace(old,"  return false\n end\n")+s[end:])
            else:
                s=worker.read_text()
                start=s.index(" if blocked_states[d.state] then")
                end=s.index(' if d.state=="travelling" then',start)
                worker.write_text(s[:start]+s[end:])
            run=subprocess.run([sys.executable,str(ROOT/"tests/run.py"),"--lint"],cwd=work,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
            assert run.returncode!=0,f"Regression test accepted {defect}"
            expected={"force-scoped-fleet":"Other force bypassed the planet limit","detached-occupant":"Occupied detached rear must prevent withdrawal","double-refund":"tests/unit.lua","blocked-worker":"Blocked worker kept its claim","premature-accessories":"Accessories started before all frontier pages were scanned","lost-anchor":"Partial frontier was marked complete at the goal limit","single-docking":"Depot must support both docking directions","lost-return":"Failed reversing maneuver lost the pending refill","historical-frontiers":"Historical rail entries delayed accessory selection","accessory-id-order":"Accessory choice followed IDs instead of proximity","accessory-contact-trip":"Accessory already in contact caused a new train journey","foreign-frontier-revision":"Other domain restarted the current rail search","sleeping-accessory":"Released accessory slept until an unrelated retry deadline","merged-frontier-cache":"Merged frontier remains invisible in destination cache","manual-takeover":"Manual takeover was ignored before new work","building-quality":"Building recovery degraded its quality"}[defect]
            assert expected in run.stdout,run.stdout
            print("CT_REGRESSION rejected "+defect,flush=True)
if __name__=="__main__":main()
