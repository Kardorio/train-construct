local G=require("scripts.geometry")
local I=require("scripts.inventory")
local F=require("scripts.factory")
local original_home=Runtime.worker.home
local home_inspected=false
local attempts={}
Runtime.worker.home=function(d,reason)
 if not home_inspected then
  home_inspected=true
  local goal=d.stop.connected_rail
  local alternatives=game.train_manager.request_train_path{train=d.head.train,type="all-goals-accessible",goals={{rail=goal,direction=0},{rail=goal,direction=1}},steps_limit=16384}
  local queue={d.head.train.front_end.rail};local seen={[queue[1].unit_number]=true};local cursor=1
  while queue[cursor] do
   local rail=queue[cursor];cursor=cursor+1
   for _,direction in ipairs{0,1} do for _,connection in ipairs{0,1,2} do
    local next_rail=rail.get_connected_rail{rail_direction=direction,rail_connection_direction=connection}
    if next_rail and not seen[next_rail.unit_number] then seen[next_rail.unit_number]=true;queue[#queue+1]=next_rail end
   end end
  end
  local isolated={}
  for _,rail in pairs(goal.surface.find_entities_filtered{type={"straight-rail","half-diagonal-rail","curved-rail-a","curved-rail-b"}}) do
   if not seen[rail.unit_number] then isolated[#isolated+1]={name=rail.name,position=rail.position,direction=rail.direction} end
  end
  local home_goals=F.home_goals(d)
  local goal_dump={}
  for _,g in ipairs(home_goals) do goal_dump[#goal_dump+1]={position=g.rail.position,direction=g.direction} end
  local stages={}
  for _,rail in ipairs(queue) do if rail.type=="straight-rail" then for _,direction in ipairs{0,1} do
   local reverse=game.train_manager.request_train_path{starts={{rail=rail,direction=1-direction}},goals=home_goals,steps_limit=8192}
   if reverse.found_path then
    local first=game.train_manager.request_train_path{train=d.head.train,goals={{rail=rail,direction=direction}},return_path=true,steps_limit=8192}
    if first.found_path then stages[#stages+1]={rail=rail.position,direction=direction,length=first.total_length} end
   end
  end end end
  log("CT_DEBUG STAGES "..helpers.table_to_json{goals=goal_dump,stages=stages,backward_speed=d.head.train.max_backward_speed,forward_speed=d.head.train.max_forward_speed,front_movers=#d.head.train.locomotives.front_movers,back_movers=#d.head.train.locomotives.back_movers})
  log("CT_DEBUG GRAPH "..helpers.table_to_json{reachable=#queue,home_connected=seen[goal.unit_number] or false,home_rail=goal.position,home_direction=d.stop.connected_rail_direction,alternatives=alternatives,isolated=isolated})
 end
 local native=game.train_manager.request_train_path{train=d.head.train,goals={d.stop},return_path=false,steps_limit=16384}
 log("CT_DEBUG HOME "..helpers.table_to_json{tick=game.tick,reason=reason,missing=d.missing,depot=d.position,stop=d.stop.position,stop_direction=d.stop.direction,native_steps=native.steps_count,native_stop_path=native.found_path,head_energy=I.fuel_energy(d.head),rear_energy=I.fuel_energy(d.rear),stock=d.entity.get_inventory(defines.inventory.chest).get_contents()})
 return original_home(d,reason)
end
local original_block=Runtime.worker.block
Runtime.worker.block=function(d,state,message)
 local joint=d.anchor and d.anchor.valid and d.anchor.get_rail_end(d.direction).location.position
 log("CT_DEBUG BLOCK "..helpers.table_to_json{tick=game.tick,state=state,message=message,anchor=d.anchor and d.anchor.valid and d.anchor.position,joint=joint,head=d.head.valid and d.head.position,rear=d.rear.valid and d.rear.position,head_orientation=d.head.valid and d.head.orientation,rear_orientation=d.rear.valid and d.rear.orientation,head_contact=joint and G.rail_contact(d.head,joint)~=nil,rear_contact=joint and G.rail_contact(d.rear,joint)~=nil})
 return original_block(d,state,message)
end
local previous={}
local initial={}
local inspected=false
script.on_event(defines.events.on_tick,function()
 if not inspected then
  inspected=true
  local signals={}
  for _,surface in pairs(game.surfaces) do
   for _,e in pairs(surface.find_entities_filtered{type={"rail-signal","rail-chain-signal"}}) do
    signals[#signals+1]={name=e.name,position=e.position,direction=e.direction}
    if CT_IGNORE_SIGNALS then e.destroy() end
   end
  end
  log("CT_DEBUG SIGNALS "..helpers.table_to_json(signals))
 end
 for id,d in pairs(storage.ct.depots) do
  initial[id]=initial[id] or d.built
  if game.tick%600==0 then
   local remaining=0
   for _,r in pairs(storage.ct.ghosts) do if r.entity.valid and r.rail then remaining=remaining+1 end end
   log("CT_DEBUG PROGRESS "..helpers.table_to_json{tick=game.tick,built=d.built,initial=initial[id],rail_ghosts=remaining})
  end
  local signature=table.concat({d.state,d.built or 0,d.task or 0,d.accessory or 0,d.message or ""},":")
  if signature~=previous[id] or game.tick%600==0 then
   previous[id]=signature
   local record=d.accessory and storage.ct.ghosts[d.accessory]
   log("CT_DEBUG STATE "..helpers.table_to_json{tick=game.tick,id=id,accessory=d.accessory,accessory_position=record and record.entity.valid and record.entity.position,destination=d.destination and d.destination.valid and d.destination.position,state=d.state,arrival=d.arrival,built=d.built,task=d.task,message=d.message,head=d.head and d.head.valid and d.head.position,anchor=d.anchor and d.anchor.valid and d.anchor.position,direction=d.direction,frontiers=#storage.ct.frontier_order})
  end
 end
end)
