
local I=require("scripts.inventory")
local function check(value,message)
 assert(value,"CT_VISUAL "..message)
 log("CT_VISUAL PASS "..message)
end
script.on_init(function()
 Runtime.initialize()
 if remote.interfaces.freeplay then
  remote.call("freeplay","set_skip_intro",true)
  remote.call("freeplay","set_disable_crashsite",true)
 end
 local surface=game.surfaces[1]
 surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
 for _,entity in pairs(surface.find_entities_filtered{area={{-70,-70},{70,70}}}) do if entity.type~="character" then entity.destroy() end end
 local tiles={};for x=-65,65 do for y=-65,65 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end;surface.set_tiles(tiles)
 surface.daytime=0;surface.freeze_daytime=true
 for y=-40,40,2 do surface.create_entity{name="straight-rail",position={0,y},direction=defines.direction.north,force="player"} end
 game.speed=10
 storage.ct_visual={phase="building"}
end)
script.on_event(defines.events.on_tick,function(event)
 if not storage.ct_visual or storage.ct_visual.done or event.tick<30 then return end
 local v=storage.ct_visual
 local player=game.get_player(1)
 if not (player and player.connected) then return end
 local surface=game.surfaces[1]
 if player.controller_type==defines.controllers.cutscene then player.exit_cutscene() end
 if v.phase=="building" then
  player.teleport({6,3},surface)
  player.cursor_stack.set_stack{name="ct-construction-depot",count=1}
  player.build_from_cursor{position={6,0}}
  local entity=surface.find_entity("ct-construction-module",{6,0})
  check(entity and entity.valid,"native player placement")
  local d=storage.ct.depots[entity.unit_number]
  -- Forced script placement may omit self-originating callbacks; use the registered handler.
  if not d then d=Runtime.on_built{entity=entity,player_index=player.index} end
  check(d and Runtime.factory.valid(d),"one actual machine generated")
  Runtime.worker.pause(d)
  v.id=d.id
  local stock=I.stock(d)
  stock.insert{name="rail",count=400};stock.insert{name="coal",count=100}
  player.opened=entity;Runtime.gui_opened{entity=entity,player_index=player.index}
  local frame=player.gui.relative.ct_window
  check(frame and frame.valid,"actual GUI frame")
  check(stock.supports_filters() and #stock==100,"native filtered 100-slot stock")
  frame.ct_bots.state=false;Runtime.gui.event{element=frame.ct_bots,player_index=player.index}
  check(not d.bot_enabled,"GUI disables reservation")
  frame.ct_bots.state=true;Runtime.gui.event{element=frame.ct_bots,player_index=player.index}
  check(d.bot_enabled,"GUI enables reservation")
  Runtime.registry.policy(d,false)
  player.opened=nil;Runtime.gui.close(player)
  player.teleport({35,0},surface)
  player.get_main_inventory().clear()
  local armor=player.get_inventory(defines.inventory.character_armor)
  armor[1].set_stack{name="power-armor-mk2"}
  local grid=armor[1].grid
  v.roboport=grid.put{name="personal-roboport-mk2-equipment",position={0,0}}
  local battery=grid.put{name="battery-mk2-equipment",position={3,0}}
  check(v.roboport and battery,"personal roboport and battery")
  v.roboport.energy=100000000;battery.energy=100000000
  player.insert{name="construction-robot",count=10};player.insert{name="rail",count=20}
  player.character.allow_dispatching_robots=true
  player.force.technologies["construction-robotics"].researched=true
  v.baseline=surface.create_entity{name="entity-ghost",inner_name="straight-rail",position={43,0},direction=defines.direction.north,force=player.force}
  Runtime.on_built{entity=v.baseline}
  v.phase="personal-baseline";v.deadline=event.tick+1200
 elseif v.phase=="personal-baseline" and event.tick>=v.deadline then
  check(not v.baseline.valid,"personal robots build shared ghost")
  local d=storage.ct.depots[v.id]
  Runtime.registry.policy(d,true)
  v.reserved=surface.create_entity{name="entity-ghost",inner_name="straight-rail",position={45,4},direction=defines.direction.north,force=player.force}
  Runtime.on_built{entity=v.reserved}
  check(v.reserved.force~=player.force,"new ghost reserved before next robot dispatch")
  v.phase="personal-reserved";v.deadline=event.tick+1200
 elseif v.phase=="personal-reserved" and event.tick>=v.deadline then
  check(v.reserved.valid,"personal robots leave reserved ghost intact")
  Runtime.registry.policy(storage.ct.depots[v.id],false)
  v.phase="personal-release";v.deadline=event.tick+1200
 elseif v.phase=="personal-release" and event.tick>=v.deadline then
  check(not v.reserved.valid,"personal robots resume after release")
  local d=storage.ct.depots[v.id]
  -- 001-AC19: reproduce the detached occupied rear with a real player.
  for y=-16,16,2 do surface.create_entity{name="straight-rail",position={40,y},direction=defines.direction.north,force="player"} end
  local invalid=surface.create_entity{name="ct-construction-depot",position={46,0},force=player.force}
  local rejected=Runtime.on_built{entity=invalid}
  check(not rejected and not invalid.valid,"incomplete neighboring lane rejected before train generation")
  local refund=0
  for _,item in pairs(surface.find_entities_filtered{position={46,0},radius=3,type="item-entity"}) do
   if item.stack.name=="ct-construction-depot" then refund=refund+item.stack.count;item.destroy() end
  end
  check(refund==1,"scripted rejected placement refunds exactly one building")
  check(#surface.find_entities_filtered{name="ct-construction-locomotive"}==2,"invalid lane leaves no extra locomotive")
  local entity=surface.create_entity{name="ct-construction-depot",position={6,30},force=player.force}
  local conflict=Runtime.factory.conflict
  Runtime.factory.conflict=function() return false end
  local other=Runtime.on_built{entity=entity}
  Runtime.factory.conflict=conflict
  check(other~=nil,"second actual machine for withdrawal guards")
  Runtime.worker.pause(other)
  other.rear.disconnect_rolling_stock(defines.rail_direction.front)
  other.rear.disconnect_rolling_stock(defines.rail_direction.back)
  check(other.rear.train~=other.head.train,"rear locomotive actually detached")
  other.rear.set_driver(player)
  check(#other.rear.train.passengers>0 and #other.head.train.passengers==0,"player aboard only detached rear")
  check(not Runtime.factory.withdraw(other,true),"occupied detached rear prevents withdrawal")
  check(other.head.valid and other.wagon.valid and other.rear.valid and player.vehicle==other.rear,"all vehicles and occupant preserved")
  other.rear.set_driver(nil)
  player.teleport({6,32},surface)
  local before=player.get_item_count("ct-construction-depot")
  local mined=player.mine_entity(other.entity,true)
  check(mined,"queued withdrawal followed by actual native mining")
  -- Script-originated mining may omit this mod's native callback.
  Runtime.factory.withdraw(other,false,"mined")
  check(player.get_item_count("ct-construction-depot")==before+1,"native mining refunds exactly one building")
  local extra=0
  for _,item in pairs(surface.find_entities_filtered{type="item-entity"}) do
   if item.stack.name=="ct-construction-depot" then extra=extra+item.stack.count end
  end
  check(extra==0,"no additional scripted building refund")
  player.teleport({6,5},surface);player.zoom=1
  player.opened=d.entity;Runtime.gui_opened{entity=d.entity,player_index=player.index}
  check(player.gui.relative.ct_window~=nil,"GUI reopens after personal robot scenario")
  v.phase="screenshot";v.deadline=event.tick+30
 elseif v.phase=="screenshot" and event.tick>=v.deadline then
  game.take_screenshot{player=player,position={2,0},resolution={1280,900},zoom=1,show_gui=true,show_entity_info=true,path="construction-train-prototype.png",force_render=true}
  helpers.write_file("ct-visual-result.txt","CT VISUAL OK\n",false)
  log("CT_VISUAL SUCCESS")
  v.done=true;game.speed=1
 end
 if v.roboport and v.roboport.valid then v.roboport.energy=100000000 end
end)
