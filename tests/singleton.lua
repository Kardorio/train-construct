local C=require("scripts.constants")
local F=Runtime.factory
local I=require("scripts.inventory")
script.on_init(function()
 Runtime.initialize()
 game.speed=10
 local surface=game.surfaces[1]
 surface.request_to_generate_chunks({0,0},4);surface.force_generate_chunk_requests()
 for _,entity in pairs(surface.find_entities_filtered{area={{-100,-100},{100,100}}}) do entity.destroy() end
 local tiles={}
 for x=-100,100 do for y=-100,100 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
 surface.set_tiles(tiles)
 for y=-90,90,2 do surface.create_entity{name="straight-rail",position={0,y},direction=0,force="player"} end
 local first=assert(Runtime.on_built{entity=surface.create_entity{name=C.depot,position={6,-60},force="player"}})
 local robot=surface.create_entity{name="construction-robot",position={40,0},force="player"}
 local denied=surface.create_entity{name=C.depot,position={46,0},force="player",quality="rare"}
 local result,reason=Runtime.on_built{entity=denied,robot=robot}
 assert(not result and reason=="fleet-limit" and not denied.valid,"Second depot was not rejected")
 assert(robot.get_inventory(defines.inventory.robot_cargo).get_item_count{name=C.depot,quality="rare"}==1,"Rejected depot refund lost quantity or quality")
 robot.destroy()
 assert(#surface.find_entities_filtered{name=C.locomotive}==2,"Rejected depot created a train")
 local function independent(target,force,x)
  for y=-16,16,2 do target.create_entity{name="straight-rail",position={x,y},direction=0,force=force} end
  local d=assert(Runtime.on_built{entity=target.create_entity{name=C.depot,position={x+6,0},force=force}})
  assert(not F.conflict(d),"Independent domain incorrectly limited")
  assert(F.withdraw(d,false))
 end
 local other_force=game.create_force("ct-test-other")
 independent(surface,other_force,40)
 local planet=game.create_surface("ct-test-other-surface",{width=64,height=64})
 planet.request_to_generate_chunks({0,0},1);planet.force_generate_chunk_requests()
 local ground={};for x=-20,20 do for y=-20,20 do ground[#ground+1]={name="grass-1",position={x,y}} end end;planet.set_tiles(ground)
 for _,entity in pairs(planet.find_entities_filtered{}) do entity.destroy() end
 independent(planet,game.forces.player,0)
 -- Seed the shape of an old save without adding a production bypass.
 local conflict=F.conflict
 F.conflict=function() return false end
 local ids={first.id}
 for _,y in ipairs{-20,20,60} do ids[#ids+1]=assert(Runtime.on_built{entity=surface.create_entity{name=C.depot,position={6,y},force="player"}}).id end
 F.conflict=conflict
 for _,id in ipairs(ids) do
  local d=storage.ct.depots[id]
  d.entity.get_inventory(defines.inventory.chest).insert{name="rail",count=100}
  I.cargo(d).insert{name="rail-signal",count=10}
  storage.ct.claims[id+100000]=id
 end
 storage.ct_singleton={ids=ids}
end)
script.on_event(defines.events.on_tick,function(event)
 local state=storage.ct_singleton
 if not state or state.done or event.tick<30 or event.tick%30~=0 then return end
 if not state.checkpoint then
  for _,id in ipairs(state.ids) do
   local d=storage.ct.depots[id]
   assert(d.state=="fleet-limit" and not d.enabled and d.head.train.manual_mode and d.head.train.speed==0,"Legacy fleet did not stop")
   Runtime.worker.start(d)
   assert(d.state=="fleet-limit" and not d.enabled,"Start bypassed the fleet limit")
   Runtime.worker.home(d,"home")
   assert(d.state=="fleet-limit" and not d.enabled,"Recall bypassed the fleet limit")
   assert(d.entity.get_inventory(defines.inventory.chest).get_item_count("rail")==100)
   assert(I.cargo(d).get_item_count("rail-signal")==10)
  end
  assert(next(storage.ct.claims)==nil,"Legacy conflict retained claims")
  state.checkpoint=event.tick;game.auto_save("ct-midmission")
  log("CT_TEST singleton legacy fleet suspended with stocks intact")
  return
 end
 if event.tick<state.checkpoint+60 then return end
 for i=2,4 do assert(F.withdraw(storage.ct.depots[state.ids[i]],true)) end
 local first=storage.ct.depots[state.ids[1]]
 Runtime.worker.start(first)
 assert(first.enabled and first.state=="loading","Single remaining worker cannot resume")
 Runtime.worker.pause(first)
 local rails,signals,refunds=0,0,0
 for _,entity in pairs(first.entity.surface.find_entities_filtered{type="item-entity"}) do
  local stack=entity.stack
  if stack.name=="rail" then rails=rails+stack.count end
  if stack.name=="rail-signal" then signals=signals+stack.count end
  if stack.name==C.depot then refunds=refunds+stack.count end
 end
 assert(rails==300 and signals==30 and refunds==3,"Legacy recovery lost or duplicated items")
 assert(#first.entity.surface.find_entities_filtered{name=C.locomotive}==2)
 state.done=true
 helpers.write_file("ct-engine-result.txt","CT ENGINE OK\n",false)
 log("CT_TEST SUCCESS lifecycle singleton: rejected placement, independent domains, legacy recovery and resumption")
end)
