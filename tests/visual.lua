
local I=require("scripts.inventory")
local Categories=require("scripts.categories")
local category_names={"rail","rail-signal","rail-chain-signal","train-stop"}
local function check(value,message)
 assert(value,"CT_VISUAL "..message)
 log("CT_VISUAL PASS "..message)
end
local function gui_event(player,element,event_name)
 local handler=script.get_event_handler(event_name)
 check(handler==Runtime.gui.event,"real GUI event handler registered")
 handler{name=event_name,tick=game.tick,element=element,player_index=player.index,button=defines.mouse_button_type.left}
end
local function check_gui(player,d)
 local frame=player.gui.relative.ct_window
 check(frame and frame.valid and frame.tags.layout_version==5,"actual v5 GUI frame")
 check(frame.tags.depot_id==d.id and frame.anchor.gui==defines.relative_gui_type.proxy_container_gui and frame.anchor.position==defines.relative_gui_position.left,"native proxy stock anchor")
 local status=frame.ct_status_section
 check(status and status.ct_status and status.ct_built and status.ct_missing,"status section and labels")
 check(status.style.minimal_height==192 and status.style.maximal_height==192 and status.ct_status.style.minimal_height==40 and status.ct_missing.style.minimal_height==60 and status.ct_missing.visible,"stable status and notice space")
 local options=frame.ct_options_section
 check(options and options.ct_bots and not options.ct_requests,"options only contain reservation control")
 check(frame.ct_controls_section~=nil,"commands section")
 check(#frame.ct_controls_section.children==2 and #frame.ct_controls_section.children[2].children==3,"single row of three train commands")
 local build=frame.ct_build_section
 local targets=build and build.ct_targets
 check(targets and targets.type=="table" and targets.column_count==3,"three-column construction targets")
 local buttons=0
 for _,child in pairs(targets.children) do if child.type=="sprite-button" then buttons=buttons+1 end end
 check(buttons==4,"four category sprite buttons")
 for _,name in ipairs(category_names) do
  local button=targets["ct_category_"..name]
  local field=targets["ct_target_"..name]
  local allowed=Categories.allowed(d,name)
  check(button and button.type=="sprite-button" and button.sprite=="item/"..name and not button.auto_toggle,"manual item button "..name)
  check(button.toggled==allowed and button.style.name==(allowed and "ct_category_on" or "ct_category_off"),"category color "..name)
  check(field and field.enabled==allowed and tonumber(field.text)==d.targets[name],"preserved target "..name)
 end
 return frame,targets
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
  local frame,targets=check_gui(player,d)
  check(stock.supports_filters() and #stock==100,"native filtered 100-slot stock")
  local bots=frame.ct_options_section.ct_bots
  bots.state=false;gui_event(player,bots,defines.events.on_gui_checked_state_changed)
  check(not d.bot_enabled,"GUI disables reservation")
  bots.state=true;gui_event(player,bots,defines.events.on_gui_checked_state_changed)
  check(d.bot_enabled,"GUI enables reservation")
  for index,name in ipairs(category_names) do
   local field=targets["ct_target_"..name]
   field.text=tostring(index*25);gui_event(player,field,defines.events.on_gui_text_changed)
   check(d.targets[name]==index*25,"GUI edits loading target "..name)
   local button=targets["ct_category_"..name]
   gui_event(player,button,defines.events.on_gui_click)
   check(not Categories.allowed(d,name),"registered click disables "..name)
   check_gui(player,d)
   gui_event(player,button,defines.events.on_gui_click)
   check(Categories.allowed(d,name),"registered click enables "..name)
   check_gui(player,d)
  end
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
  local _,targets=check_gui(player,d)
  for index,name in ipairs(category_names) do
   local field=targets["ct_target_"..name]
   field.text=tostring(index*25);gui_event(player,field,defines.events.on_gui_text_changed)
   local enabled=name=="rail" or name=="rail-signal"
   if Categories.allowed(d,name)~=enabled then gui_event(player,targets["ct_category_"..name],defines.events.on_gui_click) end
  end
  local _,restored=check_gui(player,d)
  check(d.state=="paused" and not d.enabled,"final screenshot paused")
  check(restored.ct_category_rail.toggled and restored["ct_category_rail-signal"].toggled and not restored["ct_category_rail-chain-signal"].toggled and not restored["ct_category_train-stop"].toggled,"final screenshot two green and two red categories")
  v.phase="screenshot";v.deadline=event.tick+30
 elseif v.phase=="screenshot" and event.tick>=v.deadline then
  local d=storage.ct.depots[v.id]
  check_gui(player,d)
  check(d.state=="paused" and not d.enabled,"capture remains paused")
  for index,name in ipairs(category_names) do
   check(d.targets[name]==index*25,"capture preserved nonzero target "..name)
   check(Categories.allowed(d,name)==(name=="rail" or name=="rail-signal"),"capture category selection "..name)
  end
  game.take_screenshot{player=player,position={2,0},resolution={1280,900},zoom=1,show_gui=true,show_entity_info=true,path="construction-train-prototype.png",force_render=true}
  helpers.write_file("ct-visual-result.txt","CT VISUAL OK\n",false)
  log("CT_VISUAL SUCCESS")
  v.done=true;game.speed=1
 end
 if v.roboport and v.roboport.valid then v.roboport.energy=100000000 end
end)
