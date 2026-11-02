-- 001-AC19 / 001-AC12: exercise actual recovery and retry modules with API doubles.
package.path="./?.lua;"..package.path
defines={inventory={cargo_wagon=1}}
local C=require("scripts.constants")
local Geometry=require("scripts.geometry")
assert(Geometry.same({x=1,y=2},{1,2}),"MapPosition must accept named and array coordinates")
assert(not Geometry.same({1,2},{x=2,y=2}))
local drops
local function reset()
 drops=0
 storage={ct={depots={},claims={[77]=1},components={}}}
 game={tick=100,surfaces={[1]={spill_item_stack=function(spec)
  if spec.stack.name==C.depot then drops=drops+spec.stack.count end
  return {}
 end}}}
end
package.loaded["scripts.registry"]={policy=function() end,frontier_ids=function() return storage.ct.frontier_order,storage.ct.frontier_revision or 0 end}
package.loaded["scripts.inventory"]={spill=function() return true end}
package.loaded["scripts.geometry"]=Geometry
local F=require("scripts.factory")
local function machine()
 local function vehicle(id,t)
  local e={valid=true,unit_number=id,position={x=0,y=0},train=t}
  e.get_inventory=function() end;e.get_fuel_inventory=function() end;e.get_burnt_result_inventory=function() end
  e.destroy=function() e.valid=false;return true end
  return e
 end
 local front={id=1,passengers={},speed=0}
 local back={id=2,passengers={},speed=0}
 local d={id=1,head=vehicle(1,front),wagon=vehicle(2,front),rear=vehicle(3,back),position={x=0,y=0},surface_index=1,force_index=1,
 recovery={valid=true,destroy=function() end},entity={valid=false}}
 storage.ct.depots[1]=d
 return d,front,back
end
reset()
local d,front,back=machine()
back.passengers={{}}
assert(not F.withdraw(d,true),"Occupied detached rear must prevent withdrawal")
assert(d.head.valid and d.wagon.valid and d.rear.valid)
back.passengers={};back.speed=.1
assert(not F.withdraw(d,true),"Moving detached rear must prevent withdrawal")
assert(d.head.valid and d.rear.valid)
back.speed=0
assert(F.withdraw(d,true))
assert(drops==1 and not d.rear.valid)
reset()
d,front,back=machine();back.passengers={{}}
assert(not F.withdraw(d,true))
assert(d.refund)
assert(not F.withdraw(d,false,"mined"))
assert(not d.refund)
back.passengers={}
assert(F.withdraw(d,false))
assert(drops==0,"Native mining must suppress the queued scripted refund")
defines={rail_direction={front=0,back=1},rail_connection_direction={straight=0,left=1,right=2}}
package.loaded["scripts.factory"]={conflict=function() return false end,home_goals=function() return {} end,valid=function() return true end,release_claims=function(depot)
 for id,owner in pairs(storage.ct.claims) do if owner==depot.id then storage.ct.claims[id]=nil end end
end}
package.loaded["scripts.worker"]=nil
local W=require("scripts.worker")
for _,state in ipairs{"obstacle","no-path","contact"} do
 reset()
 local t={id=1,passengers={},speed=0,manual_mode=false}
 local worker={id=1,head={valid=true,train=t},enabled=true,state=state,task=77}
 W.tick(worker)
 assert(storage.ct.claims[77]==nil,"Blocked worker kept its claim")
 assert(worker.retry_at>game.tick,"Blocked worker has no retry deadline")
 game.tick=worker.retry_at
 W.tick(worker)
 assert(worker.state=="idle" and worker.task==nil,"Blocked worker never resumed")
end
print("CT_UNIT SUCCESS: detached occupants/movement, one refund, bounded retry")

reset()
storage.ct.frontier_order={};storage.ct.frontiers={};storage.ct.ghosts={};storage.ct.path_budget=1;storage.ct.dirty={};storage.ct.dirty_head=1
for id=1,65 do storage.ct.frontier_order[id]=id end
local rail={valid=true}
storage.ct.ghosts[65]={entity={valid=true},owner=1,surface=1}
storage.ct.frontiers[65]={anchors={{rail=rail,direction=0}}}
local calls=0
game.train_manager={request_train_path=function() calls=calls+1;return {found_path=false} end}
local d={id=1,head={valid=true,train={id=1,passengers={},speed=0}},enabled=true,state="idle",force_index=1,surface_index=1,frontier_cursor=1,frontier_revision=0,visited={},pending={[99]={}}}
for _=1,2 do storage.ct.path_budget=1;W.tick(d);assert(d.state=="idle" and calls==0,"Accessories started before all frontier pages were scanned") end
storage.ct.path_budget=1;W.tick(d)
assert(calls==1 and d.state=="accessories","Later frontier page was never queried")
d.frontier_checked=0;d.frontier_cursor=1;d.path_retry=nil
for _=1,2 do storage.ct.path_budget=1;W.tick(d);assert(calls==1,"Accessory phase skipped rail priority sweep") end
storage.ct.path_budget=1;W.tick(d)
assert(calls==2,"Accessory phase never reconsidered remaining rails")
print("CT_UNIT SUCCESS: paged rail search keeps priority before accessories")

reset()
storage.ct.frontier_order={};storage.ct.frontiers={};storage.ct.ghosts={};storage.ct.path_budget=1;storage.ct.dirty={};storage.ct.dirty_head=1
for id=1,16 do
 storage.ct.frontier_order[id]=id
 storage.ct.ghosts[id]={entity={valid=true},owner=1,surface=1}
 storage.ct.frontiers[id]={anchors={{rail={valid=true,index=id},direction=0}}}
end
storage.ct.frontiers[16].anchors[2]={rail={valid=true,index=17},direction=0}
local seen={}
game.train_manager={request_train_path=function(spec)
 for _,goal in ipairs(spec.goals) do seen[goal.rail.index]=true end
 return {found_path=false}
end}
local d={id=1,head={valid=true,train={id=1,passengers={},speed=0}},enabled=true,state="idle",force_index=1,surface_index=1,frontier_cursor=1,frontier_revision=0,visited={},pending={[99]={}}}
W.tick(d)
assert(d.state=="idle" and not seen[17],"Partial frontier was marked complete at the goal limit")
storage.ct.path_budget=1;W.tick(d)
assert(seen[17],"Last anchor was skipped across goal batches")
local function ending(direction) return {location={direction=direction==0 and 0 or 8}} end
local mirror={position={x=1,y=10},get_rail_end=ending}
local source={position={x=1,y=-10},force={},get_rail_end=ending,surface={find_entities_filtered=function() return {mirror} end}}
local goals=F.home_goals{stop={valid=true,connected_rail=source,connected_rail_direction=0}}
assert(#goals==2 and goals[1].rail==source and goals[2].rail==mirror and goals[2].direction==1,"Depot must support both docking directions")
print("CT_UNIT SUCCESS: last anchor retained and mirrored docking goal")

reset()
local d={id=1,head={valid=true,train={id=1,passengers={},speed=0}},enabled=true,state="travelling",return_reason="refill"}
W.block(d,"no-path","return")
local original_home=W.home
local retried
W.home=function(_,reason) retried=reason end
game.tick=d.retry_at;W.tick(d)
W.home=original_home
assert(retried=="refill","Blocked return was replaced by a new construction job")
print("CT_UNIT SUCCESS: blocked refill preserves its destination")

reset()
defines.train_state={no_path=0,path_lost=1,wait_station=2}
local rail={valid=true}
package.loaded["scripts.factory"].home_goals=function() return {{rail=rail,direction=0}} end
package.loaded["scripts.factory"].at_home=function() return true end
local t={id=1,speed=0,state=2,passengers={}}
local d={id=1,head={valid=true,train=t},enabled=true,state="return-search",return_reason="refill",refill_mode="rails",return_search={cursor=1,candidates={{rail=rail,direction=1}}}}
storage.ct.path_budget=1
local calls=0
game.train_manager={request_train_path=function() calls=calls+1;return {found_path=true,goal_index=1,total_length=60} end}
W.tick(d)
assert(calls==2 and d.state=="travelling" and d.arrival=="retreat","Reversing point was not scheduled")
game.tick=game.tick+30;W.tick(d)
assert(d.arrival=="refill" and d.state=="travelling","Reversing point lost the pending refill")
game.tick=game.tick+30;W.tick(d)
assert(d.state=="loading" and d.refills==1 and d.refill_mode=="rails","Reversing maneuver did not reach loading")
print("CT_UNIT SUCCESS: reversing point resumes the original refill")

reset()
local t={id=1,speed=0,state=defines.train_state.no_path,passengers={}}
local d={id=1,head={valid=true,train=t},enabled=true,state="travelling",arrival="retreat",return_reason="refill",refill_mode="rails",command_tick=game.tick-30}
W.tick(d)
assert(d.state=="no-path" and d.blocked_return=="refill","Failed reversing maneuver lost the pending refill")
game.train_manager={request_train_path=function() return {found_path=true,goal_index=1} end}
game.tick=d.retry_at;W.tick(d)
assert(d.state=="travelling" and d.arrival=="refill","Failed reversing maneuver resumed construction instead of refilling")
print("CT_UNIT SUCCESS: failed reversing maneuver retains refill on retry")

do
 reset()
 defines.inventory={cargo_wagon=1}
 local d=machine()
 d.quality="rare"
 local spill=game.surfaces[1].spill_item_stack
 game.surfaces[1].spill_item_stack=function(spec)
  if spec.stack.name==C.depot then assert(spec.stack.quality=="rare","Building recovery degraded its quality") end
  return spill(spec)
 end
 assert(F.withdraw(d,true))
 for _,state in ipairs{"travelling","build","accessory","accessories","idle","loading","return-search"} do
  reset()
  local t={id=1,speed=0,passengers={},manual_mode=true}
  local worker={id=1,head={valid=true,train=t},enabled=true,auto_controlled=true,state=state,built=0,command_tick=game.tick}
  W.tick(worker)
  assert(worker.state=="paused" and not worker.enabled and worker.built==0 and t.manual_mode,"Manual takeover was ignored before new work")
 end
 print("CT_UNIT SUCCESS: manual takeover and building quality preserved")
end

do
 reset()
 local Registry=assert(loadfile("scripts/registry.lua"))()
 storage.ct.frontiers={};storage.ct.frontier_order={};storage.ct.ghosts={};storage.ct.index={}
 for id=1,1200 do storage.ct.frontier_order[id]=id end
 local ids=Registry.frontier_ids(1,1)
 assert(#ids==0,"Historical rail entries delayed accessory selection")
 local rail={valid=true}
 local record={id=2001,entity={valid=true},key="rail",owner=1,surface=1}
 storage.ct.ghosts[2001]=record;storage.ct.index.rail=2001
 Registry.frontier(record,rail,0)
 ids=Registry.frontier_ids(1,1)
 assert(#ids==1 and ids[1]==2001,"New rail frontier was hidden by the cache")
 local own_ids,own_revision=Registry.frontier_ids(1,1)
 for id=3001,3040 do
  local foreign={id=id,entity={valid=true},key="foreign"..id,owner=2,surface=2}
  storage.ct.ghosts[id]=foreign
  Registry.frontier(foreign,rail,0)
  Registry.unregister(id)
 end
 local unchanged,revision=Registry.frontier_ids(1,1)
 assert(unchanged==own_ids and revision==own_revision,"Other domain restarted the current rail search")
 Registry.unregister(2001)
 assert(#Registry.frontier_ids(1,1)==0,"Completed rail stayed in the active frontier index")
 local merged={id=4001,entity={valid=true,ghost_name="straight-rail",position={x=5,y=7},direction=0},key="merge",owner=2,surface=1}
 storage.ct.ghosts[4001]=merged;storage.ct.index.merge=4001
 Registry.frontier(merged,rail,0)
 assert(#Registry.frontier_ids(2,1)==1 and #Registry.frontier_ids(1,1)==0)
 storage.ct.force_owner={};storage.ct.forces={}
 local stub=package.loaded["scripts.registry"]
 package.loaded["scripts.registry"]=Registry
 local Runtime=assert(loadfile("scripts/runtime.lua"))()
 package.loaded["scripts.registry"]=stub
 Runtime.forces_merged{source_index=2,destination={index=1}}
 assert(merged.owner==1 and #Registry.frontier_ids(1,1)==1,"Merged frontier remains invisible in destination cache")
 assert(#Registry.frontier_ids(2,1)==0,"Merged frontier stayed visible in source cache")
 print("CT_UNIT SUCCESS: frontier index excludes history and follows rail changes")
end

do
 reset()
 storage.ct.frontier_order={};storage.ct.frontiers={};storage.ct.ghosts={};storage.ct.path_budget=1
 local t={id=1,speed=0,passengers={}}
 local near={valid=true,position={x=20,y=0}}
 local far={valid=true,position={x=200,y=0}}
 storage.ct.ghosts[200]={entity={valid=true,position={x=20,y=0}}}
 storage.ct.ghosts[1]={entity={valid=true,position={x=200,y=0}}}
 local d={id=1,head={valid=true,train=t,position={x=0,y=0},orientation=0},rear={valid=true,position={x=0,y=10},orientation=0},enabled=true,state="accessories",pending={[200]={rail=near},[1]={rail=far}}}
 local query
 game.train_manager={request_train_path=function(spec) query=spec;return {found_path=true,goal_index=1} end}
 W.tick(d)
 assert(d.accessory==200 and d.destination==near,"Accessory choice followed IDs instead of proximity")
 assert(query.shortest_path and #query.goals==4,"Nearby accessories were not compared by native route")
 storage.ct.claims={};storage.ct.ghosts={[300]={entity={valid=true,position={x=1,y=0}}}};storage.ct.path_budget=1
 d.pending={[300]={rail=near}};d.state="accessories";d.accessory=nil;t.schedule=nil
 local inventory=package.loaded["scripts.inventory"]
 inventory.low_fuel=function() return false end
 local revived=false
 inventory.revive=function() revived=true;return {valid=true,type="train-stop",connected_rail=near} end
 package.loaded["scripts.registry"].unregister=function(id) storage.ct.claims[id]=nil;storage.ct.ghosts[id]=nil end
 W.tick(d)
 assert(revived and not d.pending[300] and t.schedule==nil,"Accessory already in contact caused a new train journey")
 storage.ct.ghosts[302]={entity={valid=true,position={x=1,y=0}}};storage.ct.path_budget=1
 d.pending={[302]={rail=near}};d.state="accessories";t.speed=.1;revived=false
 W.tick(d)
 assert(not revived and d.state=="travelling","Immediate accessory pose occurred while the train was moving")
 t.speed=0;storage.ct.claims={};storage.ct.path_budget=1
 d.pending={[301]={rail=near,retry=game.tick+500},[303]={rail=near}}
 storage.ct.ghosts[301]={entity={valid=true,position={x=20,y=0}}}
 storage.ct.ghosts[303]={entity={valid=true,position={x=1,y=0}}}
 storage.ct.claims[303]=999;storage.ct.depots[999]={};d.state="accessories"
 W.tick(d)
 assert(d.state=="accessories" and d.accessory_wait==game.tick+500,"Deferred accessories caused an unnecessary depot trip")
 storage.ct.claims[303]=nil;game.tick=game.tick+1;storage.ct.path_budget=1;revived=false
 W.tick(d)
 assert(revived and not d.pending[303],"Released accessory slept until an unrelated retry deadline")
 print("CT_UNIT SUCCESS: local routes, immediate contact and deferred waiting")
end

do
 reset()
 defines.inventory={cargo_wagon=1}
 local inventory=assert(loadfile("scripts/inventory.lua"))()
 local counts={rail=200}
 local cargo={get_item_count=function(item) return counts[type(item)=="table" and item.name or item] or 0 end}
 prototypes={item={coal={fuel_value=4000000},rail={localised_name="Rail"},["rail-signal"]={localised_name="Signal"}}}
 local loco={valid=true,burner={remaining_burning_fuel=0},get_fuel_inventory=function() return {} end}
 local depot={wagon={valid=true,get_inventory=function() return cargo end},head=loco,rear=loco,fuel_target=0,targets={rail=200,["rail-signal"]=2}}
 assert(not inventory.ready(depot),"Initial loading ignored configured accessories")
 depot.refill_mode="rails"
 assert(inventory.ready(depot),"Rail refill waited for optional accessories")
 depot.refill_mode="accessories";depot.missing={name="rail-signal",quality="normal",count=2}
 assert(not inventory.ready(depot),"Accessory refill ignored its required material")
 counts.rail=0;counts["rail-signal"]=2
 assert(inventory.ready(depot),"Accessory refill waited for unrelated rails")
 for _,state in ipairs{"travelling","build"} do
  local t={id=1,manual_mode=true,passengers={},speed=.1}
  local d={id=1,enabled=true,auto_controlled=true,state=state,arrival="build",head={valid=true,train=t}}
  W.motion(d)
  if state=="travelling" then assert(d.state=="paused" and not d.enabled,"Moving worker ignored manual takeover") end
 end
 print("CT_UNIT SUCCESS: phase-specific refill and manual takeover before moving construction")
end

do
 reset()
 local t={id=1,manual_mode=false,passengers={},speed=.5}
 local head={valid=true,train=t,position={x=0,y=10},orientation=0}
 local rear={valid=true,position={x=0,y=20},orientation=0}
 local anchor={valid=true,get_rail_end=function() return {location={position={x=0,y=0}}} end}
 local d={id=1,enabled=true,auto_controlled=true,state="travelling",arrival="build",head=head,rear=rear,anchor=anchor,direction=0}
 W.motion(d)
 assert(t.speed==C.work_speed,"Forward work speed was not capped")
 t.speed=-.5;W.motion(d)
 assert(t.speed==-C.work_speed,"Backward work speed was not capped")
 t.speed=0;W.motion(d)
 assert(t.speed==0 and t.schedule==nil,"Moving construction restarted a stopped native train")
 head.position.y=100;rear.position.y=110;t.speed=.5;W.motion(d)
 assert(t.speed==.5,"Transit speed was capped away from the work front")
 print("CT_UNIT SUCCESS: work cap only reduces speed and preserves native stops")
end
