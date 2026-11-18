-- Appended to control.lua in a disposable packaged mod, never the live mod.
local S=require("scripts.depot-settings")
local C=require("scripts.constants")
local I=require("scripts.inventory")
local R=require("scripts.registry")
local function check(value,message) assert(value,"CT_SETTINGS "..message) end
local function mark(message) log("CT_SETTINGS "..message) end
local function same(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b end
 for k,v in pairs(a) do if not same(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end
 return true
end
local expected={version=1,categories={rail=false,["rail-signal"]=true,["rail-chain-signal"]=false,["train-stop"]=true},
 targets={rail=127,["rail-signal"]=0,["rail-chain-signal"]=99999,["train-stop"]=23},
 fuel_target=73,bot_enabled=true,circuit={read_contents=false,read_empty_slots=true}}
local function assert_settings(d)
 check(same(S.encode(d),expected),"restoration mismatch "..helpers.table_to_json(S.encode(d)))
 check(not d.enabled and d.state=="paused" and not d.auto_controlled and d.head.train.manual_mode,"import did not pause")
end
local function surface(name)
 local s=game.create_surface(name,{width=128,height=128,autoplace_controls={}})
 s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests()
 for _,entity in pairs(s.find_entities()) do entity.destroy() end
 local tiles={}
 for x=-64,63 do for y=-64,63 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
 s.set_tiles(tiles)
 game.forces.player.chart(s,{{-64,-64},{64,64}})
 return s
end
local function get_depot(entity) return storage.ct.depots[entity.unit_number] end
local function module(s,position)
 local entity=s.create_entity{name=C.module,position=position or {0,0},direction=defines.direction.north,
  force="player",raise_built=true}
 check(entity,"module entity not created")
 if entity.valid and not get_depot(entity) then
  -- Factorio suppresses raised events during on_init; dispatch the actual
  -- registered production callback for setup, rather than a test-only helper.
  script.get_event_handler(defines.events.script_raised_built){entity=entity,name=defines.events.script_raised_built}
 end
 check(entity.valid,"module rejected by runtime")
 return entity
end
local function blueprint_ghost(stack,s,position)
 local ghosts=stack.build_blueprint{surface=s,force="player",position=position or {0,0},raise_built=true}
 for _,ghost in pairs(ghosts) do
  if ghost.valid and ghost.type=="entity-ghost" and ghost.ghost_name==C.module then return ghost end
 end
 error("CT_SETTINGS no real blueprint ghost")
end
local function policy(d)
 local s=d.entity.surface
 local owner=game.forces[d.force_index]
 local ghosts={}
 for index,name in ipairs{"straight-rail","rail-signal","rail-chain-signal","train-stop"} do
  local g=assert(s.create_entity{name="entity-ghost",inner_name=name,position={-40+index*4,40},force=owner,raise_built=true})
  if not storage.ct.ghosts[g.unit_number] then
   script.get_event_handler(defines.events.script_raised_built){entity=g,name=defines.events.script_raised_built}
  end
  ghosts[#ghosts+1]=g
 end
 R.tick()
 for _,g in ipairs(ghosts) do
  local allowed=expected.categories[C.rail_types[g.ghost_name] and "rail" or g.ghost_name]
  check((g.force~=owner)==allowed,"excluded category reserved from robots: "..g.ghost_name)
 end
 check(storage.ct.policies[d.force_index..":"..d.surface_index]==1,"reservation count drift")
 return ghosts
end
local handlers={}
for _,name in ipairs{"on_player_setup_blueprint","on_built_entity","on_robot_built_entity",
 "script_raised_revive","on_entity_settings_pasted","on_blueprint_settings_pasted","on_entity_cloned"} do
 local id=defines.events[name]
 handlers[name]=assert(script.get_event_handler(id),"Missing real registration: "..name)
 -- Observe native events while retaining the production handler.
 if name=="on_player_setup_blueprint" or name=="on_robot_built_entity" or name=="on_entity_settings_pasted" or name=="on_built_entity" or name=="on_entity_cloned" then
  local original=handlers[name]
  script.on_event(id,function(event)
   storage.ct_settings_events=storage.ct_settings_events or {}
   storage.ct_settings_events[name]=(storage.ct_settings_events[name] or 0)+1
   original(event)
  end)
 end
end

-- 010-AC1/AC4 H1: a LuaRecord is not a LuaItemStack. This facade delegates
-- blueprint operations to an actual engine stack but rejects undocumented
-- members using the exact local runtime-api.json contract injected by Python.
local function library_contract(player,source)
 local inventory=game.create_inventory(2);inventory[1].set_stack{name="blueprint"}
 local stack=inventory[1]
 local mapping=stack.create_blueprint{surface=source.entity.surface,force=source.entity.force,area={{-20,-20},{20,20}}}
 local index
 for n,e in pairs(mapping) do if e==source.entity then index=n end end
 check(index,"library fixture has no native mapping")
 local function strict(values)
  return setmetatable({},{__index=function(_,key)
   check(record_contract[key],"LuaRecord unsupported member "..key)
   check(values[key]~=nil,"LuaRecord unexpected member "..key)
   return values[key]
  end,__newindex=function() error("CT_SETTINGS LuaRecord unexpected write") end})
 end
 local record=strict{valid=true,type="blueprint",get_blueprint_entities=stack.get_blueprint_entities,
  set_blueprint_entity_tag=stack.set_blueprint_entity_tag}
 stack.set_blueprint_entity_tag(index,"other-mod",{preserved=101})
 local callback=script.get_event_handler(defines.events.on_player_setup_blueprint)
 callback{record=record,player_index=player.index,mapping={get=function() return mapping end}}
 check(same(stack.get_blueprint_entity_tag(index,S.tag),expected),"strict LuaRecord mapping export failed")
 check(stack.get_blueprint_entity_tag(index,"other-mod").preserved==101,"strict LuaRecord lost foreign tags")
 check(inventory[2].import_stack(stack.export_stack())==0 and same(inventory[2].get_blueprint_entity_tag(index,S.tag),expected),
  "strict LuaRecord blueprint roundtrip failed")
 for _,kind in ipairs{"blueprint-book","deconstruction-planner","upgrade-planner"} do
  callback{record=strict{valid=true,type=kind},mapping={get=function() error("Non-blueprint mapping read") end}}
 end
 callback{record=strict{valid=false},stack=stack,mapping={get=function() error("Invalid record mapping read") end}}
 mark("LuaRecord strict API contract + native blueprint export/import SUCCESS")
 -- The documented API can enumerate records but cannot create/import a new
 -- library record. Report native coverage separately from the facade.
 local native_count=0
 for _,records in ipairs{game.blueprints,player.blueprints} do
  for _,native_record in pairs(records) do
   if native_record.valid and native_record.type=="blueprint" and native_record.valid_for_write then
    local map=native_record.create_blueprint{surface=source.entity.surface,force=source.entity.force,area={{-20,-20},{20,20}}}
    callback{record=native_record,player_index=player.index,mapping={get=function() return map end}}
    for n,e in pairs(map) do
     if e==source.entity then check(same(native_record.get_blueprint_entity_tag(n,S.tag),expected),"native library record lost settings") end
    end
    check(inventory[2].import_stack(native_record.export_record())==0,"native library export_record import failed")
    native_count=native_count+1
   end
  end
 end
 if native_count==0 then mark("native LuaRecord unavailable in fresh library; no documented record constructor; strict facade coverage only")
 else mark("native LuaRecord library records SUCCESS count="..native_count) end
 inventory.destroy()
end

-- 010-AC2/AC3 M1: no fabricated clone event; both APIs deliver source and
-- destination through the production on_entity_cloned registration.
local function clones(source)
 local old_stock,old_cargo=I.stock(source),I.cargo(source)
 local stock_count,cargo_count=old_stock.get_item_count("iron-plate"),old_cargo.get_item_count("rail")
 local fuel_count=source.head.get_fuel_inventory().get_item_count("coal")
 local enabled=source.enabled
 local before=storage.ct_settings_events.on_entity_cloned or 0
 for index=1,3 do
  local target=surface("ct-settings-clone-"..index)
  local force=index==3 and game.create_force("ct-settings-clone-owner") or source.entity.force
  if index==1 then
   source.entity.clone{position={0,0},surface=target}
  else
   source.entity.surface.clone_entities{entities={source.entity},destination_offset={0,0},destination_surface=target,destination_force=force}
  end
  check((storage.ct_settings_events.on_entity_cloned or 0)==before+index,"native clone event missing")
  local entities=target.find_entities_filtered{name=C.module}
  check(#entities==1,"native module clone missing")
  local d=assert(get_depot(entities[1]))
  check(d.force_index==force.index and d.surface_index==target.index,"clone kept source force/surface")
  check(same(S.encode(d),expected),"native clone settings mismatch")
  assert_settings(d)
  check(d.stock~=source.stock and d.entity.proxy_target_entity==d.stock,"cloned module kept source stock target")
  check(I.stock(d).is_empty() and I.cargo(d).is_empty() and d.head.get_fuel_inventory().is_empty() and d.rear.get_fuel_inventory().is_empty(),
   "native module clone duplicated source inventory")
  check(d.id~=source.id and d.train_id~=source.train_id and d.built==0 and not next(d.visited) and not next(d.pending),"native clone copied identity/tasks")
  check(not d.train_tools and not d.task,"native clone copied working/render state")
  policy(d)
 end
 local rejected=source.entity.clone{position={40,0}}
 check(not rejected or not rejected.valid,"native clone bypassed fleet limit")
 check(I.stock(source)==old_stock and I.cargo(source)==old_cargo and source.enabled==enabled,"native clone modified source")
 check(old_stock.get_item_count("iron-plate")==stock_count and old_cargo.get_item_count("rail")==cargo_count and
  source.head.get_fuel_inventory().get_item_count("coal")==fuel_count,"native clone consumed source inventory")
 mark("native entity.clone + surface.clone_entities: settings, pause, fresh empty stock, identities, fleet limit SUCCESS")
 -- A legacy depot is an actual container: Factorio natively clones its own
 -- contents. Configuration restoration must neither clear nor re-insert them.
 local function legacy_track(name)
  local s=surface(name)
  for y=-13,15,2 do
   check(s.create_entity{name="straight-rail",position={1,y},direction=defines.direction.north,force="player"},"legacy rail fixture failed")
  end
  return s
 end
 local legacy_surface=legacy_track("ct-settings-clone-legacy-source")
 local legacy=assert(get_depot(assert(legacy_surface.create_entity{name=C.depot,position={6,1},force="player",raise_built=true})))
 check(S.restore(legacy,{[S.tag]=expected}),"legacy source settings failed")
 I.stock(legacy).insert{name="iron-plate",count=31};I.cargo(legacy).insert{name="rail",count=9}
 local target=legacy_track("ct-settings-clone-legacy-target")
 local entity=assert(legacy.entity.clone{position={6,1},surface=target})
 local d=assert(get_depot(entity));assert_settings(d)
 check(I.stock(d).get_item_count("iron-plate")==31 and I.stock(legacy).get_item_count("iron-plate")==31,
  "configuration restoration changed native legacy inventory cloning")
 check(I.cargo(d).is_empty() and I.cargo(legacy).get_item_count("rail")==9,"legacy settings copied train inventory")
 mark("legacy native container clone inventory preserved; no train stock copied SUCCESS")
end

-- 010-AC4: malformed input and hostile extra fields never enter runtime state.
local function sanitize()
 for _,tags in pairs{false,17,"bad",{}, {[S.tag]=false},{[S.tag]="bad"},
  {[S.tag]={version=2}}, {[S.tag]={version="1"}}, {[S.tag]={}}} do
  check(S.decode(tags)==nil,"accepted absent/malformed/unknown version")
 end
 check(S.decode(nil)==nil,"accepted nil")
 for _,bad in pairs{-1,100001,math.huge,-math.huge,0/0,"12",true,{}} do
  local clean=assert(S.decode{[S.tag]={version=1,targets={rail=bad},fuel_target=bad,categories={rail=bad},bot_enabled=bad}})
  check(clean.targets.rail==C.targets.rail and clean.fuel_target==C.fuel_target,"invalid numeric value accepted")
  check(clean.categories.rail==true and clean.bot_enabled==(bad==true),"invalid boolean value accepted")
 end
 local clean=assert(S.decode{[S.tag]={version=1,targets={rail=0,["train-stop"]=100000,["rail-signal"]=2.9,unknown=99},
  fuel_target=0,categories={rail=false,unknown=false},bot_enabled=true,circuit={read_contents=false,read_empty_slots="true",enabled=true},
  enabled=true,id=22,train_id=33,task={id=88},inventory={coal=99}}})
 check(clean.targets.rail==0 and clean.targets["train-stop"]==100000 and clean.targets["rail-signal"]==2,"numeric boundaries")
 check(clean.fuel_target==0 and clean.categories.rail==false and clean.bot_enabled,"false/zero lost")
 check(clean.targets.unknown==nil and clean.categories.unknown==nil and clean.id==nil and clean.task==nil and clean.enabled==nil,"unsafe extra keys")
 check(clean.circuit.read_contents==false and clean.circuit.read_empty_slots==nil and clean.circuit.enabled==nil,"bad circuit flags")
 for _,bad in pairs{true,"bad",4} do
  clean=assert(S.decode{[S.tag]={version=1,categories=bad,targets=bad,circuit=bad}})
  check(clean.targets.rail==400 and clean.categories.rail,"bad nested tables")
 end
 mark("sanitize versions, types, finite bounds, zero, fractions, whitelist SUCCESS")
end

script.on_init(function()
 Runtime.initialize();sanitize()
 local source=assert(get_depot(module(surface("ct-settings-source"))))
 for name,value in pairs(expected.categories) do source.categories[name]=value end
 for name,value in pairs(expected.targets) do source.targets[name]=value end
 source.fuel_target=73;R.policy(source,true)
 local control=source.entity.get_control_behavior();control.read_contents=false;control.read_empty_slots=true
 I.stock(source).insert{name="iron-plate",count=47}
 I.cargo(source).insert{name="rail",count=13}
 source.head.get_fuel_inventory().insert{name="coal",count=7}
 source.built=123;source.visited={fixture=true};source.pending={fixture=true}
 local inventory=game.create_inventory(2);inventory[1].set_stack{name="blueprint"}
 local stack=inventory[1]
 local mapping=stack.create_blueprint{surface=source.entity.surface,force="player",area={{-20,-20},{20,20}}}
 local index
 for n,entity in pairs(mapping) do if entity==source.entity then index=n end end
 check(index,"module absent from native blueprint mapping")
 stack.set_blueprint_entity_tag(index,"other-mod",{preserved=42})
 check(not storage.ct_settings_events or not storage.ct_settings_events.on_player_setup_blueprint,
  "create_blueprint unexpectedly fired setup event; update fixture")
 -- create_blueprint does not raise the player selection event. Only its event
 -- envelope/LuaLazyLoadedValue is simulated; mapping and stack are engine-made.
 handlers.on_player_setup_blueprint{stack=stack,mapping={get=function() return mapping end}}
 check(same(stack.get_blueprint_entity_tag(index,S.tag),expected),"blueprint mapping export failed")
 check(stack.get_blueprint_entity_tag(index,"other-mod").preserved==42,"foreign tags overwritten")
 local exported=stack.export_stack()
 check(inventory[2].import_stack(exported)==0,"blueprint string import failed")
 check(same(inventory[2].get_blueprint_entity_tag(index,S.tag),expected),"blueprint string lost settings")
 local ghost=blueprint_ghost(inventory[2],surface("ct-settings-saved"))
 check(ghost.tags["other-mod"].preserved==42,"ghost lost foreign tags")
 local tags=ghost.tags
 local _,entity=ghost.revive{raise_revive=true}
 if entity and entity.valid and not get_depot(entity) then
  handlers.script_raised_revive{entity=entity,tags=tags,name=defines.events.script_raised_revive}
 end
 local saved=assert(get_depot(assert(entity)))
 assert_settings(saved)
 check(I.stock(saved).is_empty() and I.cargo(saved).is_empty() and saved.head.get_fuel_inventory().is_empty(),"rebuild copied inventories")
 check(saved.id~=source.id and saved.train_id~=source.train_id and saved.built==0 and not next(saved.visited) and not next(saved.pending),"rebuild copied identity/tasks")
 policy(saved)
 storage.ct_settings_test={source=source.id,saved=saved.id,inventory=inventory,index=index,
  saved_entity=saved.entity,saved_train=saved.train_id,source_stock=I.stock(source),phase="native"}
 mark("native mapping export/import + real ghost revival + paused restoration SUCCESS")
end)

local function native(test)
 local saved=storage.ct.depots[test.saved];assert_settings(saved)
 check(saved.entity==test.saved_entity and saved.train_id==test.saved_train,"save/reload changed identities")
 check(I.stock(storage.ct.depots[test.source])==test.source_stock and test.source_stock.get_item_count("iron-plate")==47,"save/reload lost stock")
 Runtime.initialize();assert_settings(saved)
 mark("real save/reload preserves settings, native flags, stock and identities SUCCESS")
 local player=assert(game.get_player(1),"Native --test-save player required")
 if player.controller_type==defines.controllers.cutscene then player.exit_cutscene() end
 player.set_controller{type=defines.controllers.god}
 player.force.character_build_distance_bonus=1000
 local source=storage.ct.depots[test.source]
 library_contract(player,source)
 clones(source)
 local selection_before=storage.ct_settings_events and storage.ct_settings_events.on_player_setup_blueprint or 0
 local mapping=test.inventory[1].create_blueprint{surface=source.entity.surface,force="player",area={{-20,-20},{20,20}}}
 check((storage.ct_settings_events and storage.ct_settings_events.on_player_setup_blueprint or 0)==selection_before,
  "scripted blueprint raised native selection event; update fixture")
 script.get_event_handler(defines.events.on_player_setup_blueprint){stack=test.inventory[1],player_index=player.index,
  mapping={get=function() return mapping end},name=defines.events.on_player_setup_blueprint}
 check(same(test.inventory[1].get_blueprint_entity_tag(test.index,S.tag),expected),"registered setup callback did not export native mapping")
 mark("scripted create_blueprint emits no player selection event; registered handler called with real mapping")
 local s=surface("ct-settings-player");player.teleport({20,20},s)
 local ghost=blueprint_ghost(test.inventory[2],s)
 local position=ghost.position;local direction=ghost.direction
 player.cursor_stack.set_stack{name=C.depot,count=1}
 local before=storage.ct_settings_events and storage.ct_settings_events.on_built_entity or 0
 player.build_from_cursor{position=position,direction=direction}
 check(not ghost.valid,"player did not rebuild native ghost")
 check((storage.ct_settings_events.on_built_entity or 0)>before,"player build event not delivered")
 local entity=s.find_entity(C.module,position);local d=assert(get_depot(assert(entity)))
 assert_settings(d);policy(d)
 mark("native player build event restores imported ghost settings SUCCESS")
 -- 010-AC3: native settings copy changes only the permitted settings, pauses
 -- the destination, and re-evaluates ghosts even when reservation stays true.
 local ghosts=s.find_entities_filtered{type="entity-ghost"}
 d.categories.rail=true;d.categories["rail-signal"]=false;storage.ct.policy_cursor=1;R.tick()
 I.stock(d).insert{name="copper-plate",count=19};I.cargo(d).insert{name="rail",count=3}
 local id,train_id,stock,cargo=d.id,d.train_id,I.stock(d),I.cargo(d)
 d.enabled=true;d.task={fixture=true};storage.ct.claims[999999]=id
 local copy_before=storage.ct_settings_events.on_entity_settings_pasted or 0
 entity.copy_settings(storage.ct.depots[test.source].entity,player)
 check((storage.ct_settings_events.on_entity_settings_pasted or 0)==copy_before+1,"native settings copy event missing")
 assert_settings(d);R.tick()
 check(d.id==id and d.train_id==train_id and I.stock(d)==stock and I.cargo(d)==cargo,"copy replaced identities")
 check(stock.get_item_count("copper-plate")==19 and stock.get_item_count("iron-plate")==0 and cargo.get_item_count("rail")==3,"copy transferred stock")
 check(not d.task and storage.ct.claims[999999]==nil,"copy left old task/claims")
 for _,g in ipairs(ghosts) do
  check((g.force~=game.forces.player)==expected.categories[C.rail_types[g.ghost_name] and "rail" or g.ghost_name],"copy left excluded ghost reserved")
 end
 for _=1,3 do entity.copy_settings(storage.ct.depots[test.source].entity,player) end
 check(storage.ct.policies[d.force_index..":"..d.surface_index]==1,"repeated copy doubled reservation")
 -- Native blueprint paste over an existing building reaches the registered
 -- combined ghost/settings handler too.
 d.targets.rail=5
 test.inventory[2].build_blueprint{surface=s,force="player",position={0,0},by_player=player}
 assert_settings(d)
 -- Missing/unknown tags preserve an existing machine's settings and state.
 for _,tags in pairs{{},{[S.tag]={version=999}},{[S.tag]=false}} do
  handlers.on_blueprint_settings_pasted{entity=entity,tags=tags,name=defines.events.on_blueprint_settings_pasted}
  assert_settings(d)
 end
 local invalid=s.create_entity{name="steel-chest",position={40,0},force="player"}
 handlers.on_entity_settings_pasted{source=invalid,destination=entity,player_index=player.index}
 assert_settings(d);invalid.destroy()
 -- 010-AC4: partial valid payloads use defaults; zero/false are explicit values.
 handlers.on_blueprint_settings_pasted{entity=entity,name=defines.events.on_blueprint_settings_pasted,
  tags={[S.tag]={version=1,categories={rail=false,["rail-signal"]=false,["rail-chain-signal"]=false,["train-stop"]=false},
   targets={rail=0,["train-stop"]=-1},fuel_target=0,bot_enabled=false,circuit={read_contents=true,read_empty_slots=false}}}}
 check(not d.enabled and d.fuel_target==0 and d.targets.rail==0 and d.targets["train-stop"]==C.targets["train-stop"],"partial sanitization on real depot")
 check(not d.bot_enabled and storage.ct.policies[d.force_index..":"..d.surface_index]==0,"reservation disable not counted")
 R.tick()
 for _,g in ipairs(ghosts) do check(g.force==game.forces.player,"disabled reservation kept a ghost") end
 for _,value in pairs(d.categories) do check(value==false,"all-disabled categories lost") end
 entity.copy_settings(storage.ct.depots[test.source].entity,player);assert_settings(d)
 -- Copying into a real ghost preserves its other mods' tags; exporting that
 -- ghost uses the same versioned data, without a runtime depot record.
 local copy_ghost=assert(s.create_entity{name="entity-ghost",inner_name=C.module,position={40,0},force="player"})
 copy_ghost.tags={["other-mod"]={preserved=91}}
 handlers.on_entity_settings_pasted{source=entity,destination=copy_ghost,player_index=player.index}
 check(same(copy_ghost.tags[S.tag],expected) and copy_ghost.tags["other-mod"].preserved==91,"copy into ghost lost tags")
 local scratch=game.create_inventory(1);scratch[1].set_stack{name="blueprint"}
 local map=scratch[1].create_blueprint{surface=s,force="player",area={{32,-18},{48,18}}}
 handlers.on_player_setup_blueprint{stack=scratch[1],mapping={get=function() return map end}}
 local ghost_index
 for n,e in pairs(map) do if e==copy_ghost then ghost_index=n end end
 check(ghost_index and same(scratch[1].get_blueprint_entity_tag(ghost_index,S.tag),expected),"ghost blueprint export lost settings")
 handlers.on_player_setup_blueprint{stack=scratch[1],mapping={get=function() return {[999999]=entity} end}}
 check(same(scratch[1].get_blueprint_entity_tag(ghost_index,S.tag),expected),"stale blueprint mapping changed tags")
 handlers.on_player_setup_blueprint{}
 copy_ghost.destroy();scratch.destroy()
 handlers.on_entity_settings_pasted{source=copy_ghost,destination=entity,player_index=player.index}
 assert_settings(d)
 local plain=assert(get_depot(module(surface("ct-settings-plain"))))
 check(plain.enabled and plain.targets.rail==C.targets.rail and plain.fuel_target==C.fuel_target,"untagged creation changed defaults")
 local plain_enabled=plain.enabled
 handlers.on_blueprint_settings_pasted{entity=plain.entity,name=defines.events.on_blueprint_settings_pasted,tags={[S.tag]={version=2}}}
 check(plain.enabled==plain_enabled,"unknown version paused an untagged machine")
 -- A second machine is still rejected, with a real robot refund path.
 local robot=s.create_entity{name="construction-robot",position={40,40},force="player"}
 local rejected=s.create_entity{name=C.module,position={40,0},force="player"}
 handlers.on_robot_built_entity{entity=rejected,robot=robot,tags={[S.tag]=expected},name=defines.events.on_robot_built_entity}
 check(not rejected.valid and robot.get_inventory(defines.inventory.robot_cargo).get_item_count(C.depot)==1,"fleet limit/refund broken")
 robot.destroy()
 mark("native settings copy, reservations, repeated paste and fleet limit SUCCESS")
 -- Use an actual powered roboport, logistic stock and construction robots.
 local rs=surface("ct-settings-robot")
 test.robot_ghost=blueprint_ghost(test.inventory[2],rs)
 local port=assert(rs.create_entity{name="roboport",position={20,12},force="player"})
 local chest=assert(rs.create_entity{name="passive-provider-chest",position={24,12},force="player"})
 port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=5}
 chest.get_inventory(defines.inventory.chest).insert{name=C.depot,count=1}
 test.port=port;test.robot_surface=rs;test.deadline=game.tick+3600;test.phase="robot"
end

script.on_event(defines.events.on_tick,function(event)
 local test=storage.ct_settings_test
 if not test then return end
 if test.phase=="native" then native(test)
 elseif test.phase=="robot" then
  test.port.energy=100000000
  if not test.robot_ghost.valid then
   local entities=test.robot_surface.find_entities_filtered{name=C.module}
   local d=assert(get_depot(assert(entities[1])))
   assert_settings(d);policy(d)
   check((storage.ct_settings_events.on_robot_built_entity or 0)>0,"native robot event missing")
   test.phase="done";mark("native construction robot rebuilt real blueprint ghost SUCCESS")
   helpers.write_file("ct-settings-success.txt","SUCCESS",false)
   mark("ALL SUCCESS 010-AC1 010-AC2 010-AC3 010-AC4 010-AC5")
  end
  check(game.tick<test.deadline,"robot rebuild timeout")
 end
end)
