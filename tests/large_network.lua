local C=require("scripts.constants")
local G=require("scripts.geometry")
local I=require("scripts.inventory")
local R=Runtime.registry
local tick_samples,motion_samples={},{}
local activated=false
local expected_near,rail_items_before,rail_cost={},0,0
local function pending()
 local s=storage.ct
 return s.dirty_head<=#s.dirty or s.scan_head<=#s.scan or s.policy_cursor<=#s.ghost_order
end
local function settle()
 local calls=0
 while pending() do R.tick();calls=calls+1 end
 return calls
end
local function timed(label,callback)
 local profiler=helpers.create_profiler()
 local value=callback()
 profiler.stop();log({"","CT_SCALE_TIME ",label," ",profiler})
 return value
end
script.on_init(function()
 Runtime.initialize()
 local s=game.surfaces[1]
 s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests()
 for _,e in pairs(s.find_entities_filtered{area={{-55,-75},{55,75}}}) do e.destroy() end
 local tiles={};for x=-45,45 do for y=-70,70 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;s.set_tiles(tiles)
 local e=s.create_entity{name=C.module,position={0,0},direction=0,force="player"}
 local d,reason=Runtime.on_built{entity=e};assert(d,tostring(reason))
 Runtime.worker.pause(d);R.policy(d,false)
 d.targets={rail=100,["rail-signal"]=0,["rail-chain-signal"]=0,["train-stop"]=0};d.fuel_target=50
 I.stock(d).insert{name="rail",count=100};I.stock(d).insert{name="coal",count=100}
 local frame=G.frame(0)
 for along=-40,40,2 do
  if math.abs(along)>14 then
   local rail=s.create_entity{name="straight-rail",position=G.offset(d.wagon.position,frame,along),direction=0,force="player"}
   assert(rail);Runtime.on_built{entity=rail}
  end
 end
 local near={}
 for along=42,62,2 do
  local ghost=s.create_entity{name="entity-ghost",inner_name="straight-rail",position=G.offset(d.wagon.position,frame,along),direction=0,force="player"}
  assert(ghost);Runtime.on_built{entity=ghost};near[#near+1]=ghost
 end
 local columns=math.ceil(math.sqrt(SCALE_COUNT))
 timed("terrain",function()
  s.request_to_generate_chunks({128+columns,128+columns},math.ceil(columns/32)+2);s.force_generate_chunk_requests()
 end)
 local ghosts={}
 timed("create_ghosts",function()
  for index=0,SCALE_COUNT-1 do
   local ghost=s.create_entity{name="entity-ghost",inner_name="straight-rail",position={128+(index%columns)*2,128+math.floor(index/columns)*2},direction=0,force="player"}
   assert(ghost and ghost.valid,"Native ghost placement failed at "..index)
   ghosts[#ghosts+1]=ghost
  end
 end)
 timed("register",function() for _,ghost in ipairs(ghosts) do Runtime.on_built{entity=ghost} end end)
 local calls=timed("initial_catchup",settle)
 assert(#storage.ct.ghost_order==SCALE_COUNT+#near,"Incomplete real registry")
 storage.ct_scale={id=d.id,count=SCALE_COUNT,near=near,far_first=ghosts[1],far_last=ghosts[#ghosts],initial_catchup_calls=calls}
 log("CT_SCALE_SETUP "..helpers.table_to_json{count=SCALE_COUNT,registered=#storage.ct.ghost_order,initial_catchup_calls=calls})
end)
script.on_nth_tick(10,function()
 if not activated then return end
 local p=helpers.create_profiler()
 if SCALE_PROFILE~="baseline" then Runtime.tick() end
 p.stop();tick_samples[#tick_samples+1]=p
end)
script.on_nth_tick(1,function()
 if not activated then return end
 local p=helpers.create_profiler()
 if SCALE_PROFILE~="baseline" then Runtime.motion() end
 p.stop();motion_samples[#motion_samples+1]=p
end)
script.on_event(defines.events.on_tick,function(event)
 local v=storage.ct_scale
 if not v then return end
 local d=storage.ct.depots[v.id]
 if not activated then
  rail_items_before=I.stock(d).get_item_count("rail")+I.cargo(d).get_item_count("rail")
  for _,ghost in ipairs(v.near) do
   expected_near[#expected_near+1]={name=ghost.ghost_name,position=ghost.position,direction=ghost.direction,quality=ghost.quality.name}
   local item=ghost.ghost_prototype.items_to_place_this[1]
   assert(item.name=="rail");rail_cost=rail_cost+item.count
  end
  local calls=timed("activation",function()
   R.policy(d,SCALE_PROFILE=="reserved" or SCALE_PROFILE=="working" or SCALE_PROFILE=="catchup")
   return SCALE_PROFILE=="catchup" and 0 or settle()
  end)
  if SCALE_PROFILE=="working" or SCALE_PROFILE=="catchup" then Runtime.worker.start(d) end
  activated=true
  log("CT_SCALE_ACTIVATION "..helpers.table_to_json{profile=SCALE_PROFILE,catchup_calls=calls,pending=pending()})
 end
 if event.tick==SCALE_TICKS then
  assert(not pending() or SCALE_PROFILE=="catchup","Benchmark queue did not settle")
  assert(v.far_first.valid and v.far_last.valid,"Unreachable ghosts were constructed")
  local working=SCALE_PROFILE=="working" or SCALE_PROFILE=="catchup"
  assert(d.built==(working and #v.near or 0),"Unexpected actual constructions: "..d.built)
  if working then
   for _,g in ipairs(v.near) do assert(not g.valid,"Accessible work starved") end
   for _,spec in ipairs(expected_near) do
    local real=d.entity.surface.find_entity(spec.name,spec.position)
    assert(real and real.direction==spec.direction and real.quality.name==spec.quality,"Missing actual accessible rail")
   end
   assert(Runtime.factory.at_home(d),"Construction train did not return home")
  end
  local consumed=rail_items_before-I.stock(d).get_item_count("rail")-I.cargo(d).get_item_count("rail")
  assert(consumed==(working and rail_cost or 0),"Incorrect real material consumption")
  local ghosts=d.entity.surface.count_entities_filtered{type="entity-ghost"}
  assert(ghosts==v.count+(working and 0 or #v.near),"Unreachable ghost count changed")
  for _,p in ipairs(tick_samples) do log({"","CT_SCALE_TICK ",p}) end
  for _,p in ipairs(motion_samples) do log({"","CT_SCALE_MOTION ",p}) end
  log("CT_SCALE_SUCCESS "..helpers.table_to_json{count=v.count,profile=SCALE_PROFILE,built=d.built,far_valid=true,settled=not pending(),
   actual_rails=working and #expected_near or 0,rail_items_consumed=consumed,ghosts_remaining=ghosts,
   dirty_remaining=math.max(0,#storage.ct.dirty-storage.ct.dirty_head+1),scan_remaining=math.max(0,#storage.ct.scan-storage.ct.scan_head+1),
   policy_remaining=math.max(0,#storage.ct.ghost_order-storage.ct.policy_cursor+1),tick_samples=#tick_samples,motion_samples=#motion_samples})
 end
end)
