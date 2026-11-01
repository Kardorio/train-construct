#!/usr/bin/env python3
"""Isolated engine probe for the LLD assumptions; does not load the final mod."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BINARY = Path(os.environ.get("FACTORIO_BIN", Path.home()/".steam/steam/steamapps/common/Factorio/bin/x64/factorio"))
CONTROL = '\nlocal function emit(label,data) log("CT_PROBE "..label.." "..helpers.table_to_json(data)) end\nlocal function p(v) return {x=v.x,y=v.y} end\nlocal function straight_extension(rail)\n for _,d in ipairs{defines.rail_direction.front,defines.rail_direction.back} do\n  local e=rail.get_rail_end(d)\n  for _,x in ipairs(e.get_rail_extensions("rail")) do\n   if x.name=="straight-rail" and (x.position.y-rail.position.y)*SENSE>0 then return e,x end\n  end\n end\nend\nscript.on_init(function()\n local s=game.surfaces[1]\n s.request_to_generate_chunks({0,0},4);s.force_generate_chunk_requests()\n for _,e in pairs(s.find_entities_filtered{area={{-115,-115},{115,115}}}) do if e.type~="character" then e.destroy() end end\n local tiles={}; for x=-110,110 do for y=-110,110 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;s.set_tiles(tiles)\n local last;for y=-70,60,2 do last=s.create_entity{name="straight-rail",position={0,y*SENSE},direction=defines.direction.north,force="player"} end\n local head=s.create_entity{name="locomotive",position={0,14*SENSE},direction=(SENSE==1 and defines.direction.south or defines.direction.north),force="player"}\n local cargo=s.create_entity{name="cargo-wagon",position={0,7*SENSE},direction=(SENSE==1 and defines.direction.south or defines.direction.north),force="player"}\n local loco=head\n local rear=s.create_entity{name="locomotive",position={0,0},direction=(SENSE==1 and defines.direction.north or defines.direction.south),force="player"}\n loco.get_fuel_inventory().insert{name="coal",count=50};rear.get_fuel_inventory().insert{name="coal",count=50}\n cargo.get_inventory(defines.inventory.cargo_wagon).insert{name="rail",count=100}\n storage.head=head;storage.cargo=cargo;storage.loco=loco;storage.last=last;storage.poses=0;storage.previous_y=head.position.y\n emit("init",{sense=SENSE,carriages=#loco.train.carriages,version=script.active_mods.base})\n loco.train.schedule={current=1,records={{rail=last,temporary=false,wait_conditions={{type="time",compare_type="and",ticks=100000}}}}};loco.train.manual_mode=false\n local re,ext=straight_extension(last)\n local sl=re.out_signal_location\n local sg=s.create_entity{name="entity-ghost",inner_name="rail-signal",position=sl.position,direction=sl.direction,force="player"}\n local ok,res=pcall(function() return #sg.get_connected_rails() end);emit("ghost_signal_connection",{ok=ok,result=tostring(res)});sg.destroy()\n local rg=s.create_entity{name="entity-ghost",inner_name=ext.name,position=ext.position,direction=ext.direction,force="player"}\n ok,res=pcall(function() return rg.get_rail_end(defines.rail_direction.front).location end);emit("ghost_rail_end",{ok=ok,result=res});rg.destroy()\n local rp=s.create_entity{name="roboport",position={40,0},force="player"}\n rp.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=10}\n rp.energy=100000000;storage.roboport=rp\n local chest=s.create_entity{name="passive-provider-chest",position={40,8},force="player"};chest.insert{name="rail",count=100}\n game.forces.player.technologies["construction-robotics"].researched=true\n local f=game.create_force("ct-probe-reserved")\n storage.shared=s.create_entity{name="entity-ghost",inner_name="straight-rail",position={40,30},direction=defines.direction.north,force="player"}\n storage.reserved=s.create_entity{name="entity-ghost",inner_name="straight-rail",position={44,30},direction=defines.direction.north,force="player"}\n storage.reserved.tags={probe=42};storage.reserved.force=f\n emit("ghost_force",{force=storage.reserved.force.name,tags=storage.reserved.tags})\nend)\nscript.on_event(defines.events.on_tick,function(e)\n storage.roboport.energy=100000000\n local t=storage.loco.train\n if e.tick%60==0 and e.tick>=300 and storage.poses<10 and t.speed==0 then\n  local re,ext=straight_extension(storage.last)\n  local head=storage.head\n  local tool={x=head.position.x,y=head.position.y+4*SENSE}\n  local joint=re.location.position\n  local contact=math.abs(tool.x-joint.x)<1/256 and math.abs(tool.y-joint.y)<1/256\n  assert(contact,"Straight tool does not touch joint")\n  assert((head.position.y-storage.previous_y)*SENSE>0,"No movement between poses")\n  local g=head.surface.create_entity{name="entity-ghost",inner_name=ext.name,position=ext.position,direction=ext.direction,force="player"}\n  local cost=g.ghost_prototype.items_to_place_this[1]\n  local inventory=storage.cargo.get_inventory(defines.inventory.cargo_wagon)\n  assert(inventory.remove{name=cost.name,count=cost.count,quality=g.quality}==cost.count)\n  local items,real=g.revive{raise_revive=true};assert(real and real.valid)\n  storage.poses=storage.poses+1;storage.previous_y=head.position.y;storage.last=real\n  emit("pose",{n=storage.poses,head=p(head.position),tool=tool,joint=p(joint),cost=cost,rail=p(real.position)})\n  t.schedule={current=1,records={{rail=real,temporary=false,wait_conditions={{type="time",compare_type="and",ticks=100000}}}}};t.manual_mode=false\n end\n if e.tick==3600 then\n  local reserved=storage.reserved\n  assert(storage.cargo.get_inventory(defines.inventory.cargo_wagon).get_item_count("rail")==90,"Material accounting mismatch")\n  assert(storage.poses==10,"Ten poses did not finish")\n  assert(not storage.shared.valid,"Baseline bot did not construct shared ghost")\n  assert(reserved.valid and reserved.type=="entity-ghost","Reserved ghost was built")\n  emit("robots",{shared_ghost_valid=storage.shared.valid,reserved_ghost_valid=reserved.valid,reserved_force=reserved.force.name})\n  emit("success",{poses=storage.poses,remaining_rails=storage.cargo.get_inventory(defines.inventory.cargo_wagon).get_item_count("rail")})\n end\nend)\n'

def main():
    messages = []
    for sense in (1, -1):
        with tempfile.TemporaryDirectory(prefix="ct-api-probe-") as directory:
            work = Path(directory)
            mod = work/"mods"/"ct-api-probe_0.0.1"
            mod.mkdir(parents=True)
            write = work/"write"
            write.mkdir()
            (mod/"info.json").write_text(json.dumps({"name":"ct-api-probe","version":"0.0.1","title":"CT API probe","author":"kardagan","factorio_version":"2.1","dependencies":["base >= 2.1.0"]}))
            (mod/"control.lua").write_text("local SENSE = "+str(sense)+"\n"+CONTROL)
            (work/"mods"/"mod-list.json").write_text(json.dumps({"mods":[{"name":"base","enabled":True},{"name":"ct-api-probe","enabled":True}]+[{"name":name,"enabled":False} for name in ["space-age","quality","elevated-rails","recycler"]]}))
            config = work/"config.ini"
            config.write_text("[path]\nread-data="+str(BINARY.parents[2]/"data")+"\nwrite-data="+str(write)+"\n[other]\ncheck-updates=false\n")
            base = [str(BINARY),"--config",str(config),"--mod-directory",str(work/"mods"),"--disable-audio"]
            for arguments in [["--create",str(work/"probe.zip")],["--benchmark",str(work/"probe.zip"),"--benchmark-ticks","3601","--benchmark-runs","1"]]:
                run = subprocess.run(base+arguments,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=55)
                messages.append(run.stdout)
                for line in run.stdout.splitlines():
                    if "CT_PROBE" in line or "Error" in line:
                        print(line,flush=True)
                if run.returncode:
                    print(run.stdout[-6000:])
                    raise RuntimeError("La sonde Factorio a échoué.")
    output = ROOT/"docs"/"api-probe-results.txt"
    output.write_text("".join(messages))
    assert "".join(messages).count("CT_PROBE success ") == 2, "Un sens de déplacement n’a pas terminé"
    print("Résultats : "+str(output))

if __name__ == "__main__":
    main()
