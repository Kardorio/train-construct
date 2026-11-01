
local function emit(label,data) log("CT_CONTACT "..label.." "..helpers.table_to_json(data)) end
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
local function plan(surface,anchor,direction,turn)
 local planned={}
 local current=anchor
 local d=direction
 local function append(t)
  local ending=current.get_rail_end(d)
  local ext=choose(ending,t)
  local real=surface.create_entity{name=ext.name,position=ext.position,direction=ext.direction,force="player"}
  assert(real and real.valid)
  local nextd=find_end(real,ext.goal)
  planned[#planned+1]={real=real,name=real.name,position=point(real.position),direction=real.direction,end_direction=nextd,goal=ext.goal}
  current=real;d=nextd
 end
 append(0);append(0)
 local initial=anchor.get_rail_end(direction).location.direction
 for step=1,12 do
  local heading=current.get_rail_end(d).location.direction
  if (heading-initial)*turn%16==1 then break end
  append(turn)
 end
 assert((current.get_rail_end(d).location.direction-initial)*turn%16==1,"First 22.5-degree bend failed")
 for i=1,4 do append(0) end
 for step=1,12 do
  local heading=current.get_rail_end(d).location.direction
  if (heading-initial)*turn%16==4 then break end
  append(turn)
 end
 assert((current.get_rail_end(d).location.direction-initial)*turn%16==4,"Second 45-degree bend failed")
 for i=1,12 do append(0) end
 for i=#planned,1,-1 do assert(planned[i].real.destroy());planned[i].real=nil end
 for _,n in ipairs(planned) do
  n.ghost=surface.create_entity{name="entity-ghost",inner_name=n.name,position=n.position,direction=n.direction,force="player"}
  assert(n.ghost and n.ghost.valid)
 end
 return planned
end
local function command(rail)
 local t=storage.head.train
 t.schedule={current=1,records={{rail=rail,temporary=false,wait_conditions={{type="time",compare_type="and",ticks=100000}}}}}
 t.manual_mode=false;storage.command_tick=game.tick
end
script.on_init(function()
 local s=game.surfaces[1]
 s.request_to_generate_chunks({0,0},8);s.force_generate_chunk_requests()
 for _,e in pairs(s.find_entities_filtered{area={{-245,-245},{245,245}}}) do if e.type~="character" then e.destroy() end end
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
 cargo.get_inventory(defines.inventory.cargo_wagon).insert{name="rail",count=500}
 assert(#head.train.carriages==3)
 storage.head=head;storage.cargo=cargo;storage.rear=rear;storage.first=first
 storage.anchor=last;storage.anchor_direction=outward(last,HEADING)
 storage.route=plan(s,last,storage.anchor_direction,TURN)
 storage.index=1;storage.stage="outbound";storage.active=head;storage.checked=0;storage.max_angle=0;storage.min_extension=100;storage.max_extension=0;storage.rigid_misses=0;storage.max_error=0;storage.cost=0;storage.poses=0;storage.types={}
 command(last)
 emit("init",{heading=HEADING,turn=TURN,planned=#storage.route,train_id=head.train.id})
end)
script.on_event(defines.events.on_tick,function(e)
 if storage.done then return end
 if e.tick%30~=0 then return end
 assert(e.tick-storage.command_tick<2400,"Native train did not reach target: "..storage.stage.." state="..storage.head.train.state)
 local t=storage.head.train
 if t.speed~=0 or e.tick-storage.command_tick<30 or t.state~=defines.train_state.wait_station then return end
 if storage.stage=="outbound" or storage.stage=="opposite_curve" then
  local node=storage.route[storage.index]
  if not node then
   if storage.stage=="opposite_curve" then finish();return end
   storage.stage="reverse";storage.previous_head=point(storage.head.position);storage.original_id=t.id
   command(storage.first)
   emit("reverse_started",{head=point(storage.head.position),rear=point(storage.rear.position)})
   return
  end
  local ending=storage.anchor.get_rail_end(storage.anchor_direction)
  local joint=ending.location.position
  local h=storage.active
  local a=h.orientation*2*math.pi
  local vx,vy=math.sin(a),-math.cos(a)
  local tx,ty=h.position.x+vx*4,h.position.y+vy*4
  local ex,ey=joint.x-tx,joint.y-ty
  local err=math.sqrt(ex*ex+ey*ey)
  if err>1/256 then storage.rigid_misses=storage.rigid_misses+1 end
  storage.max_error=math.max(storage.max_error,err)
  local cx,cy=joint.x-h.position.x,joint.y-h.position.y
  emit("contact_sample",{index=storage.index,anchor_type=storage.anchor.name,next_type=node.name,head=point(h.position),joint=point(joint),orientation=h.orientation,rigid_error=err,longitudinal=cx*vx+cy*vy,lateral=cx*(-vy)+cy*vx})
  assert(node.ghost.valid)
  local pose=contact(h,joint)
  assert(pose,"Articulated tool cannot contact canonical entry joint")
  local far={x=joint.x+vx*3,y=joint.y+vy*3}
  assert(not contact(h,far),"Tool incorrectly accepts a distant target")
  local wrong_side={x=joint.x-vy*3,y=joint.y+vx*3}
  assert(not contact(h,wrong_side),"Tool incorrectly accepts an adjacent track target")
  local extension_matches=false
  for _,ext in ipairs(ending.get_rail_extensions("rail")) do
   if ext.name==node.ghost.ghost_name and ext.direction==node.ghost.direction and
      math.abs(ext.position.x-node.ghost.position.x)<1/256 and math.abs(ext.position.y-node.ghost.position.y)<1/256 then extension_matches=true end
  end
  assert(extension_matches,"Ghost is not an exact native extension of touched joint")
  storage.checked=storage.checked+1
  storage.max_angle=math.max(storage.max_angle,math.abs(pose.angle))
  storage.min_extension=math.min(storage.min_extension,pose.length)
  storage.max_extension=math.max(storage.max_extension,pose.length)

  local cost=node.ghost.ghost_prototype.items_to_place_this[1]
  local inv=storage.cargo.get_inventory(defines.inventory.cargo_wagon)
  assert(inv.remove{name=cost.name,count=cost.count}==cost.count)
  local items,real=node.ghost.revive{raise_revive=true};assert(real and real.valid)
  storage.cost=storage.cost+cost.count;storage.poses=storage.poses+1;storage.types[real.name]=true
  storage.anchor=real;storage.anchor_direction=node.end_direction
  storage.index=storage.index+1
  command(real)
 elseif storage.stage=="reverse" then
  assert(t.id==storage.original_id,"Reversal changed train identity")
  assert(#t.carriages==3)
  local d=outward(storage.first,(HEADING+8)%16)
  local ending=storage.first.get_rail_end(d)
  local delta=(storage.rear.position.x-storage.head.position.x)*math.sin((HEADING+8)*math.pi/8)-(storage.rear.position.y-storage.head.position.y)*math.cos((HEADING+8)*math.pi/8)
  assert(delta>10,"Opposite locomotive is not leading")
  storage.anchor=storage.first;storage.anchor_direction=d
  storage.active=storage.rear
  storage.route=plan(storage.rear.surface,storage.first,d,-TURN)
  storage.index=1;storage.stage="opposite_curve"
  emit("reverse_reached",{same_train=t.id,head=point(storage.head.position),new_head=point(storage.rear.position)})
 end
end)
