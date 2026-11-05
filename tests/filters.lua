local C=require("scripts.constants")
local I=require("scripts.inventory")
local Fixture=require("test-fixtures.rail_loop")
local W=Runtime.worker
local F=Runtime.factory
local function toggle(d,name,enabled) W.set_category(d,name,enabled) end
local function remaining(state,force)
 for _,node in ipairs(state.route) do
  if node.ghost.valid then assert(node.ghost.force==force,"Rail reservation disagrees with category filter") end
 end
end
script.on_init(function()
 Runtime.initialize();game.speed=10
 local s=game.surfaces[1]
 s.request_to_generate_chunks({0,0},8);s.force_generate_chunk_requests()
 for _,e in pairs(s.find_entities_filtered{area={{-245,-245},{245,245}}}) do e.destroy() end
 local tiles={};for x=-230,230 do for y=-230,230 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;s.set_tiles(tiles)
 local first,last
 for y=-70,60,2 do local rail=s.create_entity{name="straight-rail",position={0,y},direction=0,force="player"};first=first or rail;last=rail end
 local entity=s.create_entity{name=C.depot,position={6,0},force="player"}
 local d=assert(Runtime.on_built{entity=entity})
 d.targets={rail=400,["rail-signal"]=5,["rail-chain-signal"]=5,["train-stop"]=5};d.fuel_target=10
 for name,count in pairs{rail=500,coal=100,["rail-signal"]=5,["rail-chain-signal"]=5,["train-stop"]=5} do I.stock(d).insert{name=name,count=count} end
 local route,accessories=Fixture.loop(s,last,Fixture.outward(last,defines.direction.south),1)
 local stop=s.create_entity{name="entity-ghost",inner_name="train-stop",position={3,31},direction=0,force="player"}
 accessories[#accessories+1]={name="train-stop",ghost=assert(stop)}
 for _,node in ipairs(route) do Runtime.on_built{entity=node.ghost} end
 for _,node in ipairs(accessories) do Runtime.on_built{entity=node.ghost} end
 for name in pairs(C.targets) do toggle(d,name,false) end
 storage.ct_filter_test={id=d.id,phase="empty",since=game.tick,route=route,accessories=accessories,first=first,train=d.head.train.id}
end)
script.on_event(defines.events.on_tick,function(event)
 local state=storage.ct_filter_test
 if not state or state.done or event.tick%30~=0 then return end
 assert(event.tick<18000,"Filtered construction did not finish")
 local d=assert(storage.ct.depots[state.id])
 assert(d.head.train.id==state.train and F.valid(d),"Filtering replaced or damaged the machine")
 if state.phase=="empty" and event.tick>=state.since+60 then
  assert(d.state=="no-categories" and d.built==0,"Empty categories still accepted a job")
  remaining(state,game.forces.player)
  for _,a in ipairs(state.accessories) do assert(a.ghost.valid and a.ghost.force==game.forces.player) end
  I.load(d)
  for name in pairs(C.targets) do assert(I.cargo(d).get_item_count(name)==0,"Excluded item loaded") end
  assert(I.ready(d),"Excluded material still blocks loading")
  toggle(d,"rail",true);state.phase="rails"
 elseif state.phase=="rails" then
  assert(not d.categories["rail-signal"] and not d.categories["rail-chain-signal"] and not d.categories["train-stop"],"Category settings lost on reload")
  if d.built>0 and not state.toggled then
   state.toggled=true;state.count=d.built;state.since=event.tick
   toggle(d,"rail",false);state.phase="change"
   for _,owner in pairs(storage.ct.claims) do assert(owner~=d.id,"Disabled category retained a claim") end
  elseif state.toggled and d.built>state.count+1 and not state.checkpoint then
   state.checkpoint=true;game.auto_save("ct-midmission")
  elseif d.built==52 and F.at_home(d) then
   assert(state.checkpoint,"Filtered mission has no persistence checkpoint")
   for _,a in ipairs(state.accessories) do
    assert(a.ghost.valid and a.ghost.force==game.forces.player,"Excluded accessory was built or reserved")
    assert(I.cargo(d).get_item_count(a.name)==0 and I.stock(d).get_item_count(a.name)==5,"Excluded accessory consumed or loaded")
   end
   assert(I.cargo(d).get_item_count("rail")+I.stock(d).get_item_count("rail")==416,"Filtered rails were not paid exactly")
   toggle(d,"rail-signal",true);state.phase="signals"
  end
 elseif state.phase=="change" and event.tick>=state.since+60 and d.head.train.speed==0 then
  assert(d.built==state.count and d.targets.rail==400,"Changing a filter built more rails or lost its target")
  remaining(state,game.forces.player)
  toggle(d,"rail",true);state.phase="rails"
 elseif state.phase=="signals" then
  for _,a in ipairs(state.accessories) do if a.name=="rail-chain-signal" then assert(a.ghost.valid and a.ghost.force==game.forces.player,"Excluded chain signal was used") end end
  if d.built==53 and F.at_home(d) then
   for _,a in ipairs(state.accessories) do if a.name=="rail-signal" then assert(not a.ghost.valid,"Enabled rail signal remains a ghost") end end
   toggle(d,"rail",false);toggle(d,"rail-signal",false);toggle(d,"train-stop",true)
   local s=d.entity.surface
   local rail=s.find_entity("straight-rail",{1,31})
   for _,a in ipairs(state.accessories) do if a.name=="train-stop" then state.stop=a.ghost end end
   assert(state.stop);Runtime.on_built{entity=state.stop}
   local ext
   local direction=Fixture.outward(state.first,defines.direction.north)
   for _,candidate in ipairs(state.first.get_rail_end(direction).get_rail_extensions("rail")) do if candidate.name=="straight-rail" and candidate.goal.direction==defines.direction.north then ext=candidate;break end end
   assert(ext)
   state.excluded=s.create_entity{name="entity-ghost",inner_name=ext.name,position=ext.position,direction=ext.direction,force="player"}
   Runtime.on_built{entity=state.excluded};state.phase="stops"
  end
 elseif state.phase=="stops" then
  if d.built==54 and F.at_home(d) then
   assert(not state.stop.valid and d.entity.surface.find_entity("train-stop",{3,31}),"Accessory-only mode did not build its real stop")
   assert(state.excluded.valid and state.excluded.force==game.forces.player,"Accessory-only mode built or reserved a rail")
   for name,count in pairs{rail=416,["rail-signal"]=4,["rail-chain-signal"]=5,["train-stop"]=4} do
    assert(I.stock(d).get_item_count(name)+I.cargo(d).get_item_count(name)==count,"Filtered inventory mismatch: "..name)
   end
   local amount=d.targets["rail-chain-signal"]
   toggle(d,"rail-chain-signal",true);toggle(d,"rail-chain-signal",false)
   assert(d.targets["rail-chain-signal"]==amount,"Filter reset a saved load target")
   state.done=true
   log("CT_TEST SUCCESS lifecycle filters: rails, ordinary signals, accessory-only, changes, robot release and exact stocks")
   helpers.write_file("ct-engine-result.txt","CT FILTERS OK\n",false)
  end
 end
 if event.tick%1800==0 then log("CT_TEST filters-progress "..helpers.table_to_json{tick=event.tick,phase=state.phase,built=d.built,state=d.state}) end
end)
