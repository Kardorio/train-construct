local Fixture=require("test-fixtures.rail_loop")
local loop_plan,outward=Fixture.loop,Fixture.outward
local C=require("scripts.constants")
local I=require("scripts.inventory")
local original_revive=I.revive
I.revive=function(d,ghost)
 local state=storage.ct_concurrency
 local id=ghost.unit_number
 local cost=ghost.ghost_prototype.items_to_place_this[1]
 assert(cost.name=="rail","Unexpected construction in concurrent rail scenario")
 assert(storage.ct.claims[id]==d.id,"Construction attempted without ownership")
 assert(not state.paid[id],"Ghost was paid twice")
 -- Withdraw after the real worker claims its next ghost, before any debit.
 if not keep_both and state.checkpoint and not state.withdrawn and d.id==state.first and game.tick>=state.checkpoint+60 then
  assert(d.head.train.speed==0,"Withdrawal boundary was not stationary")
  state.retired_built=d.built;state.released_task=id
  assert(Runtime.factory.withdraw(d,true),"Concurrent withdrawal did not complete")
  for _,owner in pairs(storage.ct.claims) do assert(owner~=state.first,"Withdrawn worker retained a claim") end
  assert(not storage.ct.depots[state.first] and not d.head.valid)
  assert(storage.ct.policies[d.force_index..":"..d.surface_index]==1,"Withdrawal disabled the other depot policy")
  assert(ghost.force~=game.forces[d.force_index],"Withdrawal released the other worker's reserved plan")
  state.withdrawn=true
  log("CT_TEST concurrency-withdraw "..helpers.table_to_json{tick=game.tick,built=state.retired_built,task=id})
  return nil,"obstacle"
 end
 local before=I.cargo(d).get_item_count("rail")
 local entity,reason=original_revive(d,ghost)
 local debit=before-I.cargo(d).get_item_count("rail")
 if entity then
  assert(debit==cost.count,"Concurrent construction used the wrong quantity")
  state.paid[id]={owner=d.id,cost=debit}
 else assert(debit==0,"Failed concurrent construction consumed materials") end
 return entity,reason
end
script.on_init(function()
 Runtime.initialize()
 game.speed=10
 local surface=game.surfaces[1]
 surface.request_to_generate_chunks({0,0},8);surface.force_generate_chunk_requests()
 for _,entity in pairs(surface.find_entities_filtered{area={{-245,-245},{245,245}}}) do if entity.type~="character" then entity.destroy() end end
 local tiles={}
 for x=-230,230 do for y=-230,230 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
 surface.set_tiles(tiles)
 local first,last
 for y=-70,70,2 do
  local rail=surface.create_entity{name="straight-rail",position={0,y},direction=defines.direction.north,force="player"}
  first=first or rail;last=rail
 end
 local workers={}
 for _,y in ipairs{-20,20} do
  local entity=surface.create_entity{name=C.depot,position={6,y},force="player"}
  local d,reason=Runtime.on_built{entity=entity}
  assert(d,"Concurrent depot placement failed: "..tostring(reason))
  d.targets={rail=200,["rail-signal"]=0,["rail-chain-signal"]=0,["train-stop"]=0};d.fuel_target=20
  local stock=entity.get_inventory(defines.inventory.chest)
  assert(stock.insert{name="rail",count=500}==500)
  stock.insert{name="coal",count=100}
  workers[#workers+1]=d
 end
 local routes={}
 local total_cost=0
 for _,pair in ipairs{{first,defines.direction.north},{last,defines.direction.south}} do
  local route,accessories=loop_plan(surface,pair[1],outward(pair[1],pair[2]),1)
  for _,a in ipairs(accessories) do a.ghost.destroy() end
  for _,node in ipairs(route) do
   local cost=node.ghost.ghost_prototype.items_to_place_this[1]
   assert(cost.name=="rail")
   total_cost=total_cost+cost.count
   routes[#routes+1]=node
   Runtime.on_built{entity=node.ghost}
  end
 end
 assert(#routes==104 and total_cost==168)
 storage.ct_concurrency={first=workers[1].id,second=workers[2].id,routes=routes,expected_cost=total_cost,paid={},first_train=workers[1].head.train.id,second_train=workers[2].head.train.id}
 log("CT_TEST concurrency-generated "..helpers.table_to_json{workers={workers[1].id,workers[2].id},rails=#routes})
end)
script.on_event(defines.events.on_tick,function(event)
 if game.speed~=10 then game.speed=10 end
 local state=storage.ct_concurrency
 if not state or state.done or event.tick%10~=0 then return end
 local first=storage.ct.depots[state.first]
 local second=storage.ct.depots[state.second]
 assert(second and Runtime.factory.valid(second),"Surviving train was damaged")
 assert(second.head.train.id==state.second_train,"Surviving train was replaced")
 if first then assert(Runtime.factory.valid(first) and first.head.train.id==state.first_train,"First train was damaged or replaced") end
 if not state.checkpoint and first.built>=3 and second.built>=3 then
  state.checkpoint=event.tick
  game.auto_save("ct-midmission")
  log("CT_TEST concurrency-checkpoint "..event.tick)
 end
 local remaining=0
 for _,node in ipairs(state.routes) do if node.ghost.valid then remaining=remaining+1 end end
 if (keep_both or state.withdrawn) and remaining==0 and Runtime.factory.at_home(second) and (not keep_both or Runtime.factory.at_home(first)) then
  local paid,cost=0,0
  for _,entry in pairs(state.paid) do paid=paid+1;cost=cost+entry.cost end
  assert(paid==#state.routes and cost==state.expected_cost,"Concurrent construction ledger does not match the plan")
  assert(state.checkpoint,"Both workers did not participate before completion")
  if state.withdrawn then assert(state.paid[state.released_task].owner==state.second,"Survivor did not reclaim the withdrawn worker's task") end
  assert((first and first.built or state.retired_built)+second.built==#state.routes,"Concurrent construction count is incorrect")
  local total=second.entity.get_inventory(defines.inventory.chest).get_item_count("rail")+I.cargo(second).get_item_count("rail")+second.recovery.get_item_count("rail")
  if keep_both then total=total+first.entity.get_inventory(defines.inventory.chest).get_item_count("rail")+I.cargo(first).get_item_count("rail")+first.recovery.get_item_count("rail") end
  local refunds=0
  for _,entity in pairs(second.entity.surface.find_entities_filtered{type="item-entity"}) do
   if entity.stack.name=="rail" then total=total+entity.stack.count end
   if entity.stack.name==C.depot then refunds=refunds+entity.stack.count end
  end
  assert(total==1000-state.expected_cost,"Rails lost or duplicated across concurrent withdrawal")
  assert(refunds==(keep_both and 0 or 1),"Withdrawn building was not refunded exactly once")
  for _,node in ipairs(state.routes) do assert(second.entity.surface.find_entity(node.name,node.position),"Concurrent rail was not really built") end
  assert(next(storage.ct.claims)==nil,"Completed concurrent work retained claims")
  Runtime.worker.pause(second);if keep_both then Runtime.worker.pause(first) end;state.done=true
  helpers.write_file("ct-engine-result.txt","CT ENGINE OK\n",false)
  log("CT_TEST SUCCESS lifecycle concurrency "..helpers.table_to_json{mode=keep_both and "both" or "withdraw",tick=event.tick,built=paid,spent=cost,remaining=total,retired_built=state.retired_built,first_built=first and first.built,survivor_built=second.built})
 end
 if event.tick%1200==0 then log("CT_TEST concurrency-progress "..helpers.table_to_json{tick=event.tick,remaining=remaining,first=first and first.state,second=second.state,built=second.built}) end
end)
