
local function emit(label,data) log("CT_LOOP "..label.." "..helpers.table_to_json(data)) end
local function point(v) return {x=v.x,y=v.y} end
-- Physical candidate: pivot three tiles ahead, short articulated tool.
-- The fixture must reject out-of-envelope targets before any material debit.
local function contact(head,joint)
 local a=head.orientation*2*math.pi
 local vx,vy=math.sin(a),-math.cos(a)
 local dx,dy=joint.x-head.position.x,joint.y-head.position.y
 local along,side=dx*vx+dy*vy,dx*(-vy)+dy*vx
 local rod_x=along-3
 local length=math.sqrt(rod_x*rod_x+side*side)
 local angle=math.atan2(side,rod_x)
 if length<0.8 or length>1.2 or math.abs(angle)>math.pi/6 then return nil end
 local tip={x=head.position.x+3*vx+length*math.sin(a+angle),y=head.position.y+3*vy-length*math.cos(a+angle)}
 local error=math.sqrt((tip.x-joint.x)^2+(tip.y-joint.y)^2)
 if error>1/256 then return nil end
 return {length=length,angle=angle,error=error,along=along,side=side}
end
local function finish()
 local t=storage.head.train
 local remaining=storage.cargo.get_inventory(defines.inventory.cargo_wagon).get_item_count("rail")
 assert(remaining==500-storage.cost)
 assert(storage.checked==storage.poses)
 storage.done=true;t.manual_mode=true
 emit("success",{heading=HEADING,turn=TURN,poses=storage.poses,contacts=storage.checked,remaining=remaining,consumed=storage.cost,types=storage.types,max_angle_degrees=storage.max_angle*180/math.pi,min_extension=storage.min_extension,max_extension=storage.max_extension})
end
local function find_end(rail, goal)
 for _,d in ipairs{defines.rail_direction.front,defines.rail_direction.back} do
  local ending=rail.get_rail_end(d)
  local l=ending.location
  if l.direction==goal.direction and math.abs(l.position.x-goal.position.x)<0.01 and math.abs(l.position.y-goal.position.y)<0.01 then return d end
 end
 error("No rail end matches extension goal")
end
local function outward(rail,heading)
 for _,d in ipairs{defines.rail_direction.front,defines.rail_direction.back} do
  if rail.get_rail_end(d).location.direction==heading then return d end
 end
 error("No rail end matches heading")
end
local function choose(ending,turn)
 local entries=ending.get_rail_extensions("rail")
 table.sort(entries,function(a,b) return a.name<b.name end)
 for _,e in ipairs(entries) do
  local delta=(e.goal.direction-ending.location.direction+8)%16-8
  if e.name~="rail-ramp" and ((turn==0 and delta==0) or (turn~=0 and delta*turn>0 and math.abs(delta)<=2)) then return e end
 end
 emit("extensions_unmatched",{turn=turn,location=ending.location,entries=entries})
 error("No requested extension")
end

local function loop_plan(surface,anchor,direction,turn)
 local planned={}
 local current,d=anchor,direction
 local closed,closure=false,nil
 local function append(t)
  if closed then return end
  local ext=choose(current.get_rail_end(d),t)
  for _,existing in pairs(surface.find_entities_filtered{name=ext.name,position=ext.position}) do
   if existing.direction==ext.direction and math.abs(existing.position.x-ext.position.x)<1/256 and math.abs(existing.position.y-ext.position.y)<1/256 then
    closure=existing;closed=true;return
   end
  end
  local rail=surface.create_entity{name=ext.name,position=ext.position,direction=ext.direction,force="player"}
  assert(rail and rail.valid,"Loop planning placement failed")
  d=find_end(rail,ext.goal)
  planned[#planned+1]={real=rail,name=rail.name,position=point(rail.position),direction=rail.direction,end_direction=d}
  current=rail
 end
 local initial=anchor.get_rail_end(direction).location.direction
 for corner=1,4 do
  local target=(initial+corner*4*turn)%16
  for step=1,12 do
   if closed or current.get_rail_end(d).location.direction==target then break end
   append(turn)
  end
  if closed then break end
  assert(current.get_rail_end(d).location.direction==target,"Corner did not reach expected direction")
  local amount=corner==4 and 40 or 12
  for i=1,amount do append(0);if closed then break end end
 end
 assert(closed and closure and closure.valid,"Loop did not reconnect to real backbone")
 local final=current
 local connected=false
 for _,c in ipairs{defines.rail_connection_direction.straight,defines.rail_connection_direction.left,defines.rail_connection_direction.right} do
  local next=final.get_connected_rail{rail_direction=d,rail_connection_direction=c}
  if next==closure then connected=true end
 end
 assert(connected,"Loop geometric closure is not an actual native connection")
 local accessories={}
 for i,node in ipairs(planned) do
  if node.name=="straight-rail" and (#accessories==0 or i>math.floor(#planned/2)) then
   local location=node.real.get_rail_end(node.end_direction).in_signal_location
   local name=#accessories==0 and "rail-chain-signal" or "rail-signal"
   accessories[#accessories+1]={name=name,position=location.position,direction=location.direction,anchor_index=i}
   if #accessories==2 then break end
  end
 end
 assert(#accessories==2)
 for i=#planned,1,-1 do assert(planned[i].real.destroy());planned[i].real=nil end
 for _,node in ipairs(planned) do
  node.ghost=surface.create_entity{name="entity-ghost",inner_name=node.name,position=node.position,direction=node.direction,force="player"}
  assert(node.ghost and node.ghost.valid)
 end
 for _,a in ipairs(accessories) do
  a.ghost=surface.create_entity{name="entity-ghost",inner_name=a.name,position=a.position,direction=a.direction,force="player"}
  assert(a.ghost and a.ghost.valid)
 end
 return planned,accessories,closure
end
local function drive(rail,stage)
 local t=storage.head.train
 assert(t.id==storage.train_id)
 t.schedule={current=1,records={{rail=rail,temporary=false,wait_conditions={{type="time",compare_type="and",ticks=100000}}}}}
 t.manual_mode=false;storage.command_tick=game.tick
 if stage then storage.stage=stage end
end
local function assert_signals_are_ghosts()
 for _,a in ipairs(storage.accessories) do assert(a.ghost.valid and a.ghost.type=="entity-ghost","Premature accessory construction") end
end
local function side_contact(entity,target)
 local a=entity.orientation*2*math.pi
 local vx,vy=math.sin(a),-math.cos(a)
 local dx,dy=target.x-entity.position.x,target.y-entity.position.y
 local along,side=dx*vx+dy*vy,dx*(-vy)+dy*vx
 -- Candidate side tooling occupies the locomotive length, not a circular radius.
 return math.abs(along)<=4+1/256 and math.abs(side)>=0.5 and math.abs(side)<=3,
 {along=along,side=side,vehicle=entity.unit_number}
end
script.on_init(function()
 local s=game.surfaces[1]
 s.request_to_generate_chunks({0,0},8);s.force_generate_chunk_requests()
 for _,entity in pairs(s.find_entities_filtered{area={{-245,-245},{245,245}}}) do if entity.type~="character" then entity.destroy() end end
 local tiles={};for x=-230,230 do for y=-230,230 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;s.set_tiles(tiles)
 local angle=HEADING*math.pi/8
 local dx,dy=math.sin(angle),-math.cos(angle)
 local first,last
 for k=-70,60,2 do
  local r=s.create_entity{name="straight-rail",position={dx*k,dy*k},direction=HEADING,force="player"}
  assert(r and r.valid);first=first or r;last=r
 end
 local head=s.create_entity{name="locomotive",position={dx*14,dy*14},direction=HEADING,force="player"}
 local cargo=s.create_entity{name="cargo-wagon",position={dx*7,dy*7},direction=HEADING,force="player"}
 local rear=s.create_entity{name="locomotive",position={0,0},direction=(HEADING+8)%16,force="player"}
 head.get_fuel_inventory().insert{name="coal",count=100};rear.get_fuel_inventory().insert{name="coal",count=100}
 local inv=cargo.get_inventory(defines.inventory.cargo_wagon)
 inv.insert{name="rail",count=7};inv.insert{name="rail-signal",count=1};inv.insert{name="rail-chain-signal",count=1}
 local depot=s.create_entity{name="steel-chest",position={first.position.x+10*dx-5*dy,first.position.y+10*dy+5*dx},force="player"}
 assert(depot);depot.insert{name="rail",count=500}
 storage.head=head;storage.rear=rear;storage.cargo=cargo;storage.first=first;storage.depot=depot
 storage.train_id=head.train.id
 storage.anchor=last;storage.anchor_direction=outward(last,HEADING)
 storage.route,storage.accessories,storage.closure=loop_plan(s,last,storage.anchor_direction,TURN)
 storage.index=1;storage.stage="rails";storage.cost=0;storage.poses=0;storage.refills=0;storage.signal_count=0
 drive(last)
 emit("loop_init",{heading=HEADING,turn=TURN,planned=#storage.route,closure=point(storage.closure.position),accessories=#storage.accessories})
end)
script.on_event(defines.events.on_tick,function(e)
 if storage.done or e.tick%30~=0 then return end
 local t=storage.head.train
 assert(e.tick-storage.command_tick<3600,"Native route failed in phase "..storage.stage.." state="..t.state)
 if t.speed~=0 or e.tick-storage.command_tick<30 or t.state~=defines.train_state.wait_station then return end
 if storage.stage=="rails" then
  assert_signals_are_ghosts()
  local node=storage.route[storage.index]
  if not node then
   local connection=false
   for _,c in ipairs{defines.rail_connection_direction.straight,defines.rail_connection_direction.left,defines.rail_connection_direction.right} do
    if storage.anchor.get_connected_rail{rail_direction=storage.anchor_direction,rail_connection_direction=c}==storage.closure then connection=true end
   end
   assert(connection,"Built loop is not natively closed")
   assert(storage.refills==1,"Material shortage was not exercised exactly once")
   storage.accessory_index=#storage.accessories
   local target=storage.route[storage.accessories[storage.accessory_index].anchor_index].real
   drive(target,"accessories")
   emit("rails_complete",{poses=storage.poses,consumed=storage.cost,refills=storage.refills,signals_built=storage.signal_count})
   return
  end
  local inv=storage.cargo.get_inventory(defines.inventory.cargo_wagon)
  local cost=node.ghost.ghost_prototype.items_to_place_this[1]
  if inv.get_item_count(cost.name)<cost.count then
   assert(storage.refills==0,"Second shortage is not expected in this fixture")
   emit("shortage",{next_index=storage.index,remaining=inv.get_item_count("rail"),signals_built=storage.signal_count})
   drive(storage.first,"refill")
   return
  end
  local ending=storage.anchor.get_rail_end(storage.anchor_direction)
  assert(contact(storage.head,ending.location.position),"Rail tool lacks exact bounded contact")
  local matches=false
  for _,ext in ipairs(ending.get_rail_extensions("rail")) do
   if ext.name==node.ghost.ghost_name and ext.direction==node.ghost.direction and math.abs(ext.position.x-node.position.x)<1/256 and math.abs(ext.position.y-node.position.y)<1/256 then matches=true end
  end
  assert(matches)
  assert(inv.remove{name=cost.name,count=cost.count}==cost.count)
  local _,real=node.ghost.revive{raise_revive=true};assert(real and real.valid)
  node.real=real
  storage.anchor=real;storage.anchor_direction=node.end_direction;storage.index=storage.index+1;storage.cost=storage.cost+cost.count;storage.poses=storage.poses+1
  drive(real)
 elseif storage.stage=="refill" then
  assert_signals_are_ghosts()
  local delta={x=storage.cargo.position.x-storage.depot.position.x,y=storage.cargo.position.y-storage.depot.position.y}
  assert(delta.x^2+delta.y^2<36,"Train is not actually at the supply fixture")
  local source=storage.depot.get_inventory(defines.inventory.chest)
  local target=storage.cargo.get_inventory(defines.inventory.cargo_wagon)
  assert(source.remove{name="rail",count=200}==200)
  assert(target.insert{name="rail",count=200}==200)
  storage.refills=storage.refills+1
  emit("refilled",{amount=200,at=point(storage.cargo.position),signals_built=storage.signal_count})
  drive(storage.anchor,"resume")
 elseif storage.stage=="resume" then
  assert_signals_are_ghosts()
  storage.stage="rails";storage.command_tick=e.tick-30
 elseif storage.stage=="accessories" then
  local a=storage.accessories[storage.accessory_index]
  assert(a.ghost.valid)
  local touch,measurement=side_contact(storage.head,a.position)
  if not touch then touch,measurement=side_contact(storage.rear,a.position) end
  emit("signal_contact",{target=a.position,head=point(storage.head.position),rear=point(storage.rear.position),touch=touch,measurement=measurement})
  assert(touch,"Signal tool lacks local side contact")
  local inv=storage.cargo.get_inventory(defines.inventory.cargo_wagon)
  assert(inv.remove{name=a.name,count=1}==1)
  local _,real=a.ghost.revive{raise_revive=true};assert(real and real.valid)
  local anchor=storage.route[a.anchor_index].real
  local linked=false
  for _,rail in pairs(real.get_connected_rails()) do if rail==anchor then linked=true end end
  assert(linked,"Signal is attached to a different track")
  storage.signal_count=storage.signal_count+1
  local exit=game.train_manager.request_train_path{train=t,goals={{rail=storage.first,direction=outward(storage.first,(HEADING+8)%16)}},return_path=false,steps_limit=10000}
  assert(exit.found_path,"Signal trapped the train")
  emit("signal_built",{name=real.name,after_rails=storage.poses,exit_path=true})
  storage.accessory_index=storage.accessory_index-1
  if storage.accessory_index>0 then
   drive(storage.route[storage.accessories[storage.accessory_index].anchor_index].real)
  else drive(storage.first,"final_return") end
 elseif storage.stage=="final_return" then
  assert(storage.signal_count==2 and storage.refills==1)
  local inv=storage.cargo.get_inventory(defines.inventory.cargo_wagon)
  local depot=storage.depot.get_inventory(defines.inventory.chest)
  assert(inv.get_item_count("rail")+depot.get_item_count("rail")==507-storage.cost)
  assert(inv.get_item_count("rail-signal")==0 and inv.get_item_count("rail-chain-signal")==0)
  assert(#t.carriages==3 and t.id==storage.train_id)
  storage.done=true;t.manual_mode=true
  emit("success",{heading=HEADING,turn=TURN,poses=storage.poses,consumed=storage.cost,refills=storage.refills,accessories=storage.signal_count,returned=true,premature_signals=0})
 end
end)
