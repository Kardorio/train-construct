local C=require("scripts.constants")
local G=require("scripts.geometry")
local I=require("scripts.inventory")
local F=Runtime.factory
local Fixture=require("test-fixtures.rail_loop")
local CircuitTest=require("test-fixtures.circuit_stock")
local frame=assert(G.frame(heading))
local function offset(center,along,across) return G.offset(center,frame,along,across) end
local function native_drive(d,rail,direction)
 d.head.train.schedule={current=1,records={{rail=rail,rail_direction=direction,wait_conditions={{type="time",compare_type="and",ticks=100000}}}}}
 d.head.train.manual_mode=false
end
local function damage_trial(test,surface,kind)
 for _,item in pairs(surface.find_entities_filtered{type="item-entity"}) do item.destroy() end
 local building=surface.create_entity{name=C.module,position=test.site,direction=heading,force="player"}
 local d,reason=Runtime.on_built{entity=building}
 assert(d,"Damage trial "..kind.." placement failed: "..tostring(reason))
 d.enabled=false
 for _,loco in ipairs{d.head,d.rear} do loco.get_fuel_inventory().insert{name="coal",count=20} end
 test.id=d.id;test.train=d.head.train.id;test.phase="damage-away";test.damage_kind=kind
 local rail=surface.find_entity("straight-rail",offset(test.center,40))
 native_drive(d,rail,Fixture.outward(rail,heading))
end
local revive=I.revive
I.revive=function(d,ghost)
 local joint=d.anchor.get_rail_end(d.direction).location.position
 assert(G.rail_contact(d.head,joint) or G.rail_contact(d.rear,joint),"Module rail construction missed contact")
 local moving=d.head.train.speed~=0
 local real,reason=revive(d,ghost)
 if real and moving then storage.ct_module_test.moving=storage.ct_module_test.moving+1 end
 return real,reason
end
script.on_init(Runtime.initialize)
local function setup()
 game.speed=10
 local surface=game.surfaces[1]
 surface.request_to_generate_chunks({0,0},8);surface.force_generate_chunk_requests()
 for _,entity in pairs(surface.find_entities_filtered{area={{-245,-245},{245,245}}}) do entity.destroy() end
 local tiles={};for x=-230,230 do for y=-230,230 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;surface.set_tiles(tiles)
 local player=native_player and assert(game.get_player(1),"Native test player is missing") or nil
 if player then
  if player.controller_type==defines.controllers.cutscene then player.exit_cutscene() end
  if not player.character then player.set_controller{type=defines.controllers.god};player.create_character() end
  player.teleport({35,35},surface)
  player.force.character_build_distance_bonus=1000
  player.force.chart(surface,{{-230,-230},{230,230}})
 end
 -- 002-AC3: a late stop obstruction must roll back newly generated track and stock.
 local bad_center={x=101,y=101}
 local blocking_stop=surface.create_entity{name="train-stop",position=offset(bad_center,10,2),direction=heading,force="player"}
 assert(blocking_stop)
 local borrowed_rollback={}
 for along=-2,2,2 do borrowed_rollback[#borrowed_rollback+1]=surface.create_entity{name="straight-rail",position=offset(bad_center,along),direction=heading,force="player"} end
 local bad=surface.create_entity{name=C.module,position={100,100},direction=heading,quality="rare",force="player"}
 local robot=surface.create_entity{name="construction-robot",position={120,120},force="player"}
 local rejected,reason=Runtime.on_built{entity=bad,robot=robot}
 log("CT_TEST module-obstruction "..helpers.table_to_json{accepted=rejected~=nil,reason=reason,existing=blocking_stop.position,planned=offset(bad_center,10,2),created=rejected and rejected.stop.position})
 assert(not rejected and not bad.valid,"Obstructed module was accepted")
 assert(robot.get_inventory(defines.inventory.robot_cargo).get_item_count{name=C.depot,quality="rare"}==1,"Rejected module refund lost quality")
 assert(#surface.find_entities_filtered{name={C.rail,C.connector,C.stock,C.locomotive,C.wagon,C.stop}}==0,"Rejected module left partial components")
 assert(blocking_stop.valid,"Module rollback destroyed the player's obstruction")
 for _,rail in ipairs(borrowed_rollback) do assert(rail.valid,"Module rollback destroyed a borrowed rail");rail.destroy() end
 blocking_stop.destroy();robot.destroy()
 local wet_site={x=-100,y=100};local wet_center={x=-99,y=101}
 local wet=offset(wet_center,12)
 surface.set_tiles{{name="water",position={wet.x,wet.y}}}
 local water_module=surface.create_entity{name=C.module,position=wet_site,direction=heading,quality="rare",force="player"}
 local carrier=surface.create_entity{name="construction-robot",position={-120,120},force="player"}
 local water_result,water_reason=Runtime.on_built{entity=water_module,robot=carrier}
 assert(not water_result and water_reason=="placement" and not water_module.valid,"Module was built across water")
 assert(carrier.get_inventory(defines.inventory.robot_cargo).get_item_count{name=C.depot,quality="rare"}==1,"Water rejection lost the module")
 carrier.destroy()
 local occupied_site={x=-100,y=-100};local occupied_center={x=-99,y=-99};local old_track={}
 for along=-6,6,2 do old_track[#old_track+1]=surface.create_entity{name="straight-rail",position=offset(occupied_center,along),direction=heading,force="player"} end
 local foreign=surface.create_entity{name="locomotive",position=occupied_center,direction=heading,force="player"}
 assert(foreign)
 local occupied_module=surface.create_entity{name=C.module,position=occupied_site,direction=heading,force="player"}
 local occupied_result,occupied_reason=Runtime.on_built{entity=occupied_module}
 assert(not occupied_result and occupied_reason=="occupied" and not occupied_module.valid,"Module was built over an occupied track")
 assert(foreign.valid,"Rejected module removed the existing train")
 for _,rail in ipairs(old_track) do assert(rail.valid);rail.destroy() end
 foreign.destroy()
 for _,name in ipairs{"stone-furnace","train-stop"} do
  local obstructing=assert(surface.create_entity{name=name,position=offset({x=151,y=151},0,3),direction=heading,force="player"})
  local blocked_module=surface.create_entity{name=C.module,position={150,150},direction=heading,force="player"}
  local blocked_result=Runtime.on_built{entity=blocked_module}
  assert(not blocked_result and not blocked_module.valid and obstructing.valid,"Module overlapped or removed an existing workshop obstruction: "..name)
  obstructing.destroy()
 end
 for _,item in pairs(surface.find_entities_filtered{type="item-entity"}) do item.destroy() end
 assert(#surface.find_entities_filtered{name={C.rail,C.connector,C.stock,C.locomotive,C.wagon,C.stop}}==0,"Rejected terrain or occupancy left module components")
 -- 002-AC8: the principal is naturally rotatable before its components are generated.
 local probe=surface.create_entity{name=C.module,position={150,150},direction=0,force="player"}
 assert(probe.rotatable and probe.rotate(),"Module principal cannot rotate before placement")
 probe.destroy()
 if player then
  player.cursor_stack.set_stack{name=C.depot,count=1}
  player.build_from_cursor{position={0,0},direction=heading}
 else surface.create_entity{name=C.module,position={0,0},direction=heading,force="player"} end
 local entity=surface.find_entities_filtered{name=C.module,area={{-2,-2},{2,2}}}[1]
 assert(entity and entity.direction==heading,"Native item placement lost its orientation")
 local d=storage.ct.depots[entity.unit_number] or Runtime.on_built{entity=entity,player_index=player and player.index}
 assert(d and F.valid(d) and #d.head.train.carriages==3,"Module did not generate one complete train")
 assert(#d.rails==15 and #d.track==15,"Module did not generate its complete track on bare land")
 assert(not entity.rotatable and not entity.rotate(),"Placed module rotated without its components")
 assert(d.head.orientation==heading/16 and d.rear.orientation==((heading+8)%16)/16)
 assert(d.stop.direction==heading and d.stock.valid and F.at_home(d))
 assert(#d.barriers==2,"Workshop collision barriers are missing")
 for _,along in ipairs{-15,-8,8,15} do for _,across in ipairs{-2.5,2.5} do
  assert(not surface.can_place_entity{name="stone-furnace",position=offset(d.wagon.position,along,across),force="player"},"Machine can be placed over the workshop or walkway")
 end end
 assert(entity.proxy_target_entity==d.stock and entity.proxy_target_inventory==defines.inventory.chest,"Module proxy does not target its stock")
 assert(entity.get_inventory(defines.inventory.proxy_main)==I.stock(d) and #entity.get_inventory(defines.inventory.proxy_main)==100,"Module principal does not expose the real stock")
 assert(not d.stock.prototype.selectable_in_game,"Integrated stock remains separately selectable")
 assert(#d.decor==0,"New module still creates prototype floor decorations")
 local stock=d.stock;local train_id=d.head.train.id
 I.stock(d).insert{name="iron-plate",count=17}
 local floor=rendering.draw_rectangle{color={r=0.15,g=0.16,b=0.18,a=0.35},filled=true,left_top={-3,-16},right_bottom={9,16},surface=surface}
 local border=rendering.draw_rectangle{color={r=1,g=0.7,b=0.1},filled=false,left_top={-3,-16},right_bottom={9,16},surface=surface}
 d.decor={floor,border}
 d.categories=nil
 for _,barrier in ipairs(d.barriers) do barrier.destroy() end
 d.barriers=nil
 local existing=assert(surface.create_entity{name="stone-furnace",position=offset(d.wagon.position,-8,2.5),force="player"})
 existing.get_fuel_inventory().insert{name="coal",count=7}
 d.stock.direction=0
 Runtime.initialize();Runtime.initialize()
 for name in pairs(C.targets) do assert(d.categories[name]==true,"Existing depot did not enable all construction categories") end
 assert(#d.barriers==2 and d.barriers[1].valid and d.barriers[2].valid,"Existing module did not receive its collision barriers")
 assert(existing.valid and existing.get_fuel_inventory().get_item_count("coal")==7,"Collision migration removed an existing player machine")
 existing.destroy()
 assert(d.stock.direction==heading,"Existing stock did not follow its module orientation")
 assert(not floor.valid and not border.valid and #d.decor==0,"Existing module retained obsolete floor decorations")
 assert(d.stock==stock and d.head.train.id==train_id and I.stock(d).get_item_count("iron-plate")==17,"Visual migration replaced the machine or lost stock")
 assert(#F.home_goals(d)==2,"Module has no mirrored docking goal")
 if player then
  player.opened=entity;Runtime.gui_opened{entity=entity,player_index=player.index}
  assert(player.gui.relative.ct_window and player.gui.relative.ct_window.anchor.gui==defines.relative_gui_type.proxy_container_gui and #I.stock(d)==100,"Module did not select its stock GUI anchor")
  local targets=player.gui.relative.ct_window.ct_targets
  local checkbox=targets["ct_category_rail-chain-signal"]
  assert(checkbox.state and targets["ct_target_rail-chain-signal"].enabled,"Category controls are not initialized")
  local count=d.targets["rail-chain-signal"]
  checkbox.state=false;Runtime.gui.event{element=checkbox,player_index=player.index};Runtime.gui.update(player)
  assert(d.categories["rail-chain-signal"]==false and not targets["ct_target_rail-chain-signal"].enabled and d.targets["rail-chain-signal"]==count,"Native category checkbox changed or retained its loading demand")
  checkbox.state=true;Runtime.gui.event{element=checkbox,player_index=player.index};Runtime.gui.update(player)
  assert(d.categories["rail-chain-signal"] and targets["ct_target_rail-chain-signal"].enabled,"Native category reactivation failed")
  local old=player.gui.relative.ct_window
  old.ct_targets.destroy();Runtime.gui.update(player)
  assert(not old.valid and player.gui.relative.ct_window.ct_targets and player.gui.relative.ct_window.ct_targets["ct_category_rail-chain-signal"].state,"Old native GUI was not rebuilt after a layout change")
  Runtime.gui.close(player);player.opened=nil
 end
 local center=d.wagon.position
 local backbone={}
 for _,sign in ipairs{-1,1} do
  local connector=d.track[sign<0 and 1 or #d.track]
  assert(connector.name==C.connector and connector.prototype.selectable_in_game,"End rail cannot be selected for extension")
  assert(not connector.minable_flag,"Internal connector can be mined for free rails")
  if player then assert(not player.mine_entity(connector,true),"Native mining recovered an internal connector") end
  local direction=Fixture.outward(connector,(heading+(sign<0 and 8 or 0))%16)
  local extension
  for _,candidate in ipairs(connector.get_rail_end(direction).get_rail_extensions("rail")) do
   if candidate.name=="straight-rail" and candidate.goal.direction==(heading+(sign<0 and 8 or 0))%16 then extension=candidate;break end
  end
  assert(extension,"No native rail extension at the module end")
  if player then
   player.cursor_stack.set_stack{name="rail",count=10}
   player.build_from_cursor{position=extension.position,direction=extension.direction}
  else surface.create_entity{name="straight-rail",position=extension.position,direction=extension.direction,force="player"} end
  local real=surface.find_entity("straight-rail",extension.position)
  assert(real and connector.get_connected_rail{rail_direction=direction,rail_connection_direction=defines.rail_connection_direction.straight}==real,"Native player extension did not connect to the end")
  backbone[#backbone+1]=real;Runtime.on_built{entity=real}
 end
 local last
 for along=-70,60,2 do
  local position=offset(center,along)
  if math.abs(along)>14 then
   local real=surface.find_entity("straight-rail",position) or surface.create_entity{name="straight-rail",position=position,direction=heading,force="player"}
   backbone[#backbone+1]=real;last=real
  end
 end
 local route,accessories=Fixture.loop(surface,last,Fixture.outward(last,heading),1)
 for _,a in ipairs(accessories) do a.ghost.destroy() end
 for _,node in ipairs(route) do Runtime.on_built{entity=node.ghost} end
 d.targets={rail=7,["rail-signal"]=0,["rail-chain-signal"]=0,["train-stop"]=0};d.fuel_target=10
 I.stock(d).insert{name="rail",count=500};I.stock(d).insert{name="coal",count=100}
 local inputs={}
 for _,along in ipairs{-10,10} do
  local source=assert(surface.create_entity{name="steel-chest",position=offset(d.stock.position,along,3),force="player"})
  local placement={name="burner-inserter",position=offset(d.stock.position,along,2),direction=(heading+4)%16,force="player"}
  assert(surface.can_place_entity(placement),"Loading inserter collides with the workshop stock")
  local inserter=assert(surface.create_entity(placement))
  inputs[#inputs+1]={source=source,inserter=inserter}
 end
 Runtime.worker.pause(d)
 local circuit=CircuitTest.setup(d)
 storage.ct_module_test={id=d.id,train=d.head.train.id,route=route,backbone=backbone,center=center,player=player and player.index,moving=0,phase="circuit",circuit=circuit,inputs=inputs,input_deadline=game.tick+600}
 log("CT_TEST module-generated "..helpers.table_to_json{heading=heading,rails=#d.rails,train=d.head.train.id,stock=d.stock.position})
end
script.on_event(defines.events.on_tick,function(event)
 if not storage.ct_module_test then setup() end
 local test=storage.ct_module_test
 if not test or test.done or event.tick%30~=0 then return end
 local d=assert(storage.ct.depots[test.id])
 assert(d.head.valid and d.head.train.id==test.train,"Module machine changed across the mission")
 if test.phase~="damage-stop" then assert(F.valid(d),"Module components disappeared before the damage test") end
 local t=d.head.train
 if test.circuit and test.circuit.phase=="done" and test.circuit.entity.valid then CircuitTest.persisted(d,test.circuit) end
 if test.phase=="circuit" then
  if CircuitTest.check(d,test.circuit) then
   for _,input in ipairs(test.inputs) do
    input.source.insert{name="iron-plate",count=1}
    input.inserter.get_fuel_inventory().insert{name="coal",count=5}
   end
   test.phase="stock-input";test.input_deadline=game.tick+600
  end
 elseif test.phase=="stock-input" then
  assert(game.tick<test.input_deadline,"Inserters cannot supply the stock along the building perimeter")
  local supplied=true
  for _,input in ipairs(test.inputs) do
   if input.source.get_item_count("iron-plate")>0 or input.inserter.held_stack.valid_for_read then supplied=false end
  end
  if supplied and I.stock(d).get_item_count("iron-plate")==19 then
   for _,input in ipairs(test.inputs) do input.source.destroy();input.inserter.destroy() end
   test.inputs=nil
   Runtime.worker.start(d);test.phase="mission"
  end
 elseif test.phase=="mission" then
  if d.arrival=="refill" and not test.expanded then test.expanded=true;d.targets.rail=200 end
  if (d.refills or 0)>0 and not test.checkpoint then test.checkpoint=true;game.auto_save("ct-midmission") end
  local remaining=0;for _,node in ipairs(test.route) do if node.ghost.valid then remaining=remaining+1 end end
  if remaining==0 and d.built==52 and F.at_home(d) then
   assert(test.checkpoint and d.refills>0 and test.moving==52,"Module mission did not refill and build in motion")
   assert(I.stock(d).get_item_count("rail")+I.cargo(d).get_item_count("rail")==416,"Module stock lost or duplicated rails")
   for _,node in ipairs(test.route) do assert(d.entity.surface.find_entity(node.name,node.position)) end
   Runtime.worker.pause(d)
   test.phase="away";test.dock=2
   local rail=d.entity.surface.find_entity("straight-rail",offset(test.center,40))
   native_drive(d,rail,Fixture.outward(rail,heading))
  end
 elseif test.phase=="away" and t.speed==0 and t.state==defines.train_state.wait_station then
  local goal=F.home_goals(d)[test.dock]
  native_drive(d,goal.rail,goal.direction);test.phase="dock"
 elseif test.phase=="dock" and t.speed==0 and t.state==defines.train_state.wait_station then
  assert(F.at_home(d),"Oriented home goal did not center the wagon")
  if test.dock==2 then
   test.dock=1;test.phase="away"
   local rail=d.entity.surface.find_entity("straight-rail",offset(test.center,-40))
   native_drive(d,rail,Fixture.outward(rail,(heading+8)%16))
  else test.phase="recover" end
 elseif test.phase=="recover" then
  test.refills=d.refills
  local surface=d.entity.surface
  local other=surface.create_entity{name="cargo-wagon",position=offset(test.center,16),direction=heading,force="player"}
  assert(other and not F.withdraw(d,true) and d.state=="occupied-track","Foreign train did not defer module recovery")
  assert(d.head.valid and d.stock.valid and #d.rails==15,"Deferred recovery removed module components")
  other.destroy()
  local expected={}
  local function count(inv)
   if not inv then return end
   for i=1,#inv do local stack=inv[i];if stack.valid_for_read then local key=stack.name.."|"..stack.quality.name;expected[key]=(expected[key] or 0)+stack.count end end
  end
  count(I.stock(d));count(I.cargo(d));count(d.recovery)
  for _,loco in ipairs{d.head,d.rear} do count(loco.get_fuel_inventory());count(loco.get_burnt_result_inventory()) end
  expected[C.depot.."|normal"]=1
  local owned=d.rails;local stock=d.stock;local module=d.entity;local site=module.position;test.site=site
  local barriers=d.barriers
  assert(F.withdraw(d,true),"Module recovery never completed")
  assert(not stock.valid and not module.valid and not d.head.valid and not d.rear.valid and not d.stop.valid)
  for _,barrier in ipairs(barriers) do assert(not barrier.valid,"Module recovery left a collision barrier") end
  for _,rail in ipairs(owned) do assert(not rail.valid,"Module recovery left an owned rail") end
  for _,rail in ipairs(test.backbone) do assert(rail.valid,"Module recovery destroyed the player's connection") end
  local actual={}
  for _,item in pairs(surface.find_entities_filtered{type="item-entity"}) do local key=item.stack.name.."|"..item.stack.quality.name;actual[key]=(actual[key] or 0)+item.stack.count;item.destroy() end
  for key,value in pairs(expected) do assert(actual[key]==value,"Module recovery inventory mismatch: "..key) end
  for key,value in pairs(actual) do assert(expected[key]==value,"Unexpected recovery item: "..key) end
  -- 002-AC4: pre-existing rails remain unowned and survive native module mining.
  local borrowed={}
  for along=10,14,2 do borrowed[#borrowed+1]=surface.create_entity{name="straight-rail",position=offset(test.center,along),direction=heading,force="player"} end
  local building=surface.create_entity{name=C.module,position=site,direction=heading,quality="rare",force="player"}
  local reused=assert(Runtime.on_built{entity=building})
  assert(#reused.rails==12,"Module claimed the player's existing rails")
  I.stock(reused).insert{name="rail",quality="rare",count=37}
  local visitor=surface.create_entity{name="cargo-wagon",position=offset(test.center,16),direction=heading,force="player"}
  assert(visitor and not F.withdraw(reused,true) and reused.state=="occupied-track","Foreign traffic on borrowed rails did not defer recovery")
  assert(reused.head.valid and I.stock(reused).get_item_count{name="rail",quality="rare"}==37)
  visitor.destroy()
  local player=test.player and game.get_player(test.player)
  if player then
   player.get_main_inventory().clear()
   assert(player.mine_entity(building,true),"Native module mining failed")
   F.withdraw(reused,false,"mined")
   assert(player.get_item_count{name=C.depot,quality="rare"}==1,"Native module mining duplicated or degraded the building")
  else assert(F.withdraw(reused,true),"Reused-track module recovery failed") end
  for _,rail in ipairs(borrowed) do assert(rail.valid,"Module mining removed borrowed rails") end
  local recovered,refunds=0,0
  for _,item in pairs(surface.find_entities_filtered{type="item-entity"}) do
   if item.stack.name==C.depot then refunds=refunds+item.stack.count end
   if item.stack.name=="rail" and item.stack.quality.name=="rare" then recovered=recovered+item.stack.count end
  end
  assert(recovered==37,"Native mining lost the child stock")
  assert(refunds==(player and 0 or 1),"Module recovery duplicated the building")
  damage_trial(test,surface,"stock")
 elseif test.phase=="damage-away" and t.speed~=0 and G.distance(d.wagon.position,test.center)>256 then
  test.damage_at=event.tick
  if test.damage_kind=="stock" then d.stock.destroy{raise_destroy=true}
  else
   local rail=d.track[#d.track]
   assert(rail.name=="straight-rail","Damage test did not select a borrowed rail")
   rail.destroy{raise_destroy=true}
  end
  test.phase="damage-stop"
 elseif test.phase=="damage-stop" then
  assert(d.state=="damaged" and not d.enabled and not d.auto_controlled and t.manual_mode,"Damaged module left its native train running automatically")
  assert(event.tick-test.damage_at<=300,"Damaged train did not stop within its native braking budget")
  if t.speed==0 then
   local surface=d.entity.surface
   assert(F.withdraw(d,true),"Damaged module could not be recovered")
   if test.damage_kind=="stock" then damage_trial(test,surface,"borrowed")
   else
    test.done=true
    helpers.write_file("ct-engine-result.txt","CT ENGINE OK\n",false)
    log("CT_TEST SUCCESS lifecycle integrated-module "..helpers.table_to_json{heading=heading,tick=event.tick,moving=test.moving,paid=84,refills=test.refills,both_ends=true,foreign_guard=true,borrowed_preserved=true,damage_stopped=true,native_player=test.player~=nil})
    script.finish_test(true)
   end
  end
 end
 if event.tick%1800==0 then log("CT_TEST module-progress "..helpers.table_to_json{heading=heading,tick=event.tick,phase=test.phase,state=d.state,built=d.built}) end
end)
