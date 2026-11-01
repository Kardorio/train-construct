
local function emit(label,data) log("CT_LIFECYCLE "..label.." "..helpers.table_to_json(data)) end
local function has_request()
 return (storage.a and storage.a.valid and storage.a_enabled) or (storage.b and storage.b.valid and storage.b_enabled) or false
end
local function reconcile()
 if storage.target and storage.target.valid then storage.target.force=has_request() and storage.reserved_force or game.forces.player end
end
local function ghost(x)
 return game.surfaces[1].create_entity{name="entity-ghost",inner_name="straight-rail",position={x,28},direction=defines.direction.north,force="player"}
end
local function verify_local_recovery()
 local s=game.surfaces[1]
 for x=-40,40,2 do s.create_entity{name="straight-rail",position={x,-30},direction=defines.direction.east,force="player"} end
 local a=s.create_entity{name="locomotive",position={-7,-30},direction=defines.direction.west,force="player"}
 local w=s.create_entity{name="cargo-wagon",position={0,-30},direction=defines.direction.east,force="player"}
 local b=s.create_entity{name="locomotive",position={7,-30},direction=defines.direction.east,force="player"}
 assert(a and w and b and #a.train.carriages==3)
 a.get_fuel_inventory().insert{name="coal",count=50}
 b.get_fuel_inventory().insert{name="coal",count=50}
 local cargo=w.get_inventory(defines.inventory.cargo_wagon)
 cargo.insert{name="rail",count=100};cargo.insert{name="rail-signal",count=23};cargo.insert{name="rail-chain-signal",count=17}
 local expected={}
 local function drop_inventory(inv,position)
  if not inv then return end
  for i=1,#inv do
   local stack=inv[i]
   if stack.valid_for_read then
    local count=stack.count
    local key=stack.name.."|"..stack.quality.name
    expected[key]=(expected[key] or 0)+count
    local dropped=s.spill_item_stack{position=position,stack=stack,allow_belts=false,enable_looted=false,use_start_position_on_failure=true}
    local actual=0
    for _,entity in ipairs(dropped) do actual=actual+entity.stack.count end
    assert(actual==count,"Local spill lost items")
    stack.clear()
   end
  end
 end
 a.train.manual_mode=true
 for _,entity in ipairs{a,w,b} do
  drop_inventory(entity.get_inventory(defines.inventory.cargo_wagon),entity.position)
  drop_inventory(entity.get_fuel_inventory(),entity.position)
  drop_inventory(entity.get_burnt_result_inventory(),entity.position)
 end
 for _,entity in ipairs{a,w,b} do assert(entity.destroy{raise_destroy=true}) end
 assert(not a.valid and not w.valid and not b.valid)
 local actual={}
 for _,entity in pairs(s.find_entities_filtered{area={{-50,-45},{50,-15}},type="item-entity"}) do
  local stack=entity.stack
  local key=stack.name.."|"..stack.quality.name
  actual[key]=(actual[key] or 0)+stack.count
 end
 for key,count in pairs(expected) do assert(actual[key]==count,"Recovery accounting mismatch: "..key) end
 for key,count in pairs(actual) do assert(expected[key]==count,"Unexpected duplicate recovery item: "..key) end
 emit("local_recovery",{expected=expected,actual=actual,vehicles_removed=3})
end
script.on_init(function()
 local s=game.surfaces[1]
 s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests()
 for _,entity in pairs(s.find_entities_filtered{area={{-80,-80},{80,80}}}) do if entity.type~="character" then entity.destroy() end end
 local tiles={};for x=-75,75 do for y=-75,75 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;s.set_tiles(tiles)
 local rp=s.create_entity{name="roboport",position={0,0},force="player"}
 rp.energy=100000000
 rp.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=10}
 local provider=s.create_entity{name="passive-provider-chest",position={0,8},force="player"}
 provider.insert{name="rail",count=100}
 game.forces.player.technologies["construction-robotics"].researched=true
 storage.roboport=rp
 storage.reserved_force=game.create_force("ct-lifecycle-reserved")
 if FRIENDLY then
  game.forces.player.set_friend(storage.reserved_force,true)
  storage.reserved_force.set_friend(game.forces.player,true)
 end
 storage.baseline=ghost(0)
 emit("init",{version=script.active_mods.base,buildings=0})
end)
script.on_event(defines.events.on_tick,function(e)
 storage.roboport.energy=100000000
 if e.tick==1200 then
  assert(not storage.baseline.valid,"No-building baseline was not built")
  storage.a=game.surfaces[1].create_entity{name="steel-chest",position={20,0},force="player"}
  storage.a_enabled=true
  storage.target=ghost(8);storage.target.tags={probe=42}
  reconcile()
  emit("enabled",{reserved_force=storage.target.force.name})
 elseif e.tick==2400 then
  assert(storage.target.valid and storage.target.force==storage.reserved_force,"A new robot built the reserved ghost")
  assert(storage.target.tags.probe==42)
  storage.b=game.surfaces[1].create_entity{name="steel-chest",position={24,0},force="player"}
  storage.b_enabled=true
  storage.a_enabled=false
  reconcile()
  emit("one_request_remains",{force=storage.target.force.name})
 elseif e.tick==3600 then
  assert(storage.target.valid and storage.target.force==storage.reserved_force,"Disabling one of two buildings released the ghost")
  storage.b.destroy();storage.b_enabled=false
  reconcile()
  assert(storage.target.force==game.forces.player)
  emit("released",{force=storage.target.force.name})
 elseif e.tick==4800 then
  assert(not storage.target.valid,"Robot did not build ghost after release")
  assert(not has_request())
  storage.disabled_baseline=ghost(16)
  emit("release_built",{ok=true})
 elseif e.tick==6000 then
  assert(not storage.disabled_baseline.valid,"Disabled building still prevented robots")
  storage.a.destroy();storage.a_enabled=false
  storage.final_baseline=ghost(24)
 elseif e.tick==7200 then
  assert(not storage.final_baseline.valid,"No-building final baseline was not built")
  assert(not has_request())
  verify_local_recovery()
  storage.done=true
  emit("success",{friendly=FRIENDLY,baseline=true,reservation=true,remaining_request=true,last_request_released=true,disabled_building=true,no_buildings=true,recovery=true})
 end
end)
