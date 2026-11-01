local inventory=require("scripts.inventory")
local HEADING=8

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
local C=require("scripts.constants")
local I=require("scripts.inventory")
local test={}
script.on_init(function()
 Runtime.initialize()
 local surface=game.surfaces[1]
 surface.request_to_generate_chunks({180,0},2);surface.force_generate_chunk_requests()
 local tiles={};for x=175,195 do for y=-20,20 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;surface.set_tiles(tiles)
 for _,entity in pairs(surface.find_entities_filtered{area={{175,-20},{195,20}}}) do entity.destroy() end
 for y=-16,16,2 do surface.create_entity{name="straight-rail",position={180,y},direction=defines.direction.north,force="player"} end
 local building=surface.create_entity{name=C.depot,position={186,0},quality="rare",force="player"}
 local rare_depot=assert(Runtime.on_built{entity=building})
 assert(Runtime.factory.withdraw(rare_depot,true))
 local rare,normal=0,0
 for _,entity in pairs(surface.find_entities_filtered{area={{175,-20},{195,20}},type="item-entity"}) do
  if entity.stack.name==C.depot then
   if entity.stack.quality.name=="rare" then rare=rare+entity.stack.count else normal=normal+entity.stack.count end
  end
  entity.destroy()
 end
 assert(rare==1 and normal==0,"Building recovery degraded its quality")
 local robot=surface.create_entity{name="construction-robot",position={180,0},force="player"}
 local invalid=surface.create_entity{name=C.depot,position={200,0},quality="rare",force="player"}
 Runtime.on_built{entity=invalid,robot=robot}
 assert(not invalid.valid and robot.get_inventory(defines.inventory.robot_cargo).get_item_count{name=C.depot,quality="rare"}==1,"Rejected building degraded its quality")
 robot.destroy()
 log("CT_TEST building-quality SUCCESS recovery and rejected placement preserve rare")
 game.speed=10
 local s=game.surfaces[1]
 s.request_to_generate_chunks({0,0},8);s.force_generate_chunk_requests()
 for _,entity in pairs(s.find_entities_filtered{area={{-245,-245},{245,245}}}) do if entity.type~="character" then entity.destroy() end end
 local tiles={};for x=-230,230 do for y=-230,230 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;s.set_tiles(tiles)
 local first,last
 for y=-70,60,2 do
  local rail=s.create_entity{name="straight-rail",position={0,y},direction=defines.direction.north,force="player"}
  first=first or rail;last=rail
 end
 -- 001-AC17 / 001-AC16: a real building creates exactly its own three vehicles.
 local entity=s.create_entity{name=C.depot,position={6,0},force="player",raise_built=true}
 assert(entity and entity.valid,"Building was rejected")
 local d,creation_error=Runtime.on_built{entity=entity}
 assert(d,"Factory rejected placement: "..tostring(creation_error))
 assert(d and Runtime.factory.valid(d),"Machine was not generated")
 assert(#d.head.train.carriages==3)
 assert(d.stop.connected_rail)
 local original=d.head.train.id
 Runtime.on_built{entity=entity}
 assert(d.head.train.id==original and #d.head.train.carriages==3,"Duplicate machine on repeated event")
 d.targets={rail=7,["rail-signal"]=1,["rail-chain-signal"]=1,["train-stop"]=1}
 d.fuel_target=10
 local stock=entity.get_inventory(defines.inventory.chest)
 stock.insert{name="rail",count=500};stock.insert{name="coal",count=100}
 stock.insert{name="rail-signal",count=1};stock.insert{name="rail-chain-signal",count=1};stock.insert{name="train-stop",count=1}
 stock.remove{name="coal",count=100}
 for _,name in ipairs{"solid-fuel","rocket-fuel","nuclear-fuel"} do
  for _,loco in ipairs{d.head,d.rear} do loco.get_fuel_inventory().clear();loco.burner.currently_burning=nil end
  stock.insert{name=name,count=20}
  inventory.load(d)
  assert(inventory.ready(d),"Compatible fuel rejected: "..name)
  assert(not inventory.low_fuel(d),"Energy reserve ignored for "..name)
  for _,loco in ipairs{d.head,d.rear} do assert(loco.get_fuel_inventory().get_item_count(name)>0) end
  stock.remove{name=name,count=1000}
 end
 for _,loco in ipairs{d.head,d.rear} do loco.get_fuel_inventory().clear();loco.burner.currently_burning=nil end
 stock.insert{name="ct-test-perishable-fuel",quality="rare",count=10,spoil_percent=.75}
 local aging
 for i=1,#stock do if stock[i].valid_for_read and stock[i].name=="ct-test-perishable-fuel" then aging=stock[i] end end
 assert(aging,"Perishable test fuel not inserted")
 local age=aging.spoil_percent
 inventory.load(d)
 assert(aging.count==6 and math.abs(aging.spoil_percent-age)<.0001,"Source fuel changed age or quantity")
 for _,loco in ipairs{d.head,d.rear} do
  local stack=loco.get_fuel_inventory()[1]
  assert(stack.valid_for_read and stack.count==2 and stack.quality.name=="rare","Fuel quantity or quality changed")
  assert(math.abs(stack.spoil_percent-age)<.0001,"Fuel transfer refreshed spoilage")
  stack.clear()
 end
 stock.remove{name="ct-test-perishable-fuel",quality="rare",count=100}
 log("CT_TEST perishable-fuel SUCCESS partial transfer preserves quality and spoilage")
 stock.insert{name="uranium-fuel-cell",count=10}
 inventory.load(d)
 local ready,reason=inventory.ready(d)
 assert(not ready and reason[1]=="ct.fuel-missing","Missing fuel must be diagnosed")
 assert(d.head.get_fuel_inventory().is_empty(),"Incompatible nuclear reactor fuel loaded")
 stock.remove{name="uranium-fuel-cell",count=10}
 for _,loco in ipairs{d.head,d.rear} do
  loco.burner.currently_burning="nuclear-fuel"
  loco.burner.remaining_burning_fuel=100000000
 end
 assert(inventory.ready(d) and not inventory.low_fuel(d),"Active burning fuel was ignored")
 for _,loco in ipairs{d.head,d.rear} do loco.burner.currently_burning=nil end
 stock.insert{name="coal",count=100}
 log("CT_TEST compatible-fuels SUCCESS solid/rocket/nuclear, incompatible rejected, active fuel counted")
 local direction=outward(last,defines.direction.south)
 local route,accessories=loop_plan(s,last,direction,1)
 for i,node in ipairs(route) do
  if node.name=="straight-rail" and i>=8 then
   local vertical=node.direction==defines.direction.north or node.direction==defines.direction.south
   local position={x=node.position.x+(vertical and 2 or 0),y=node.position.y+(vertical and 0 or 2)}
   local direction=vertical and defines.direction.north or defines.direction.east
   local ghost=s.create_entity{name="entity-ghost",inner_name="train-stop",position=position,direction=direction,force="player"}
   assert(ghost)
   accessories[#accessories+1]={ghost=ghost,name="train-stop",anchor_index=i,position=ghost.position,direction=ghost.direction}
   break
  end
 end
 for _,node in ipairs(route) do Runtime.on_built{entity=node.ghost} end
 for _,a in ipairs(accessories) do Runtime.on_built{entity=a.ghost} end
 test.id=d.id;test.route=route;test.accessories=accessories;test.original_train=original
 storage.ct_test=test
 log("CT_TEST generated "..helpers.table_to_json{depot=d.id,train=original,rails=#route})
end)
script.on_event(defines.events.on_tick,function(event)
 if game.speed~=10 then game.speed=10 end
 if event.tick%30~=0 or not storage.ct_test then return end
 local state=storage.ct_test
 if state.done then return end
 if state.phase=="release" then
  if event.tick<state.release_tick then return end
  assert(state.isolated.valid and state.isolated.force==game.forces.player,"Last request did not release the ghost")
  local d=storage.ct.depots[state.id]
  local t=d.head.train
  t.schedule={current=1,records={{rail=d.entity.surface.find_entity("straight-rail",{1,31}),wait_conditions={{type="time",compare_type="and",ticks=10000}}}}}
  t.manual_mode=false
  state.phase="remote-withdraw"
  return
 elseif state.phase=="remote-withdraw" then
  local d=storage.ct.depots[state.id]
  if d.head.train.speed~=0 or d.head.train.state~=defines.train_state.wait_station then return end
  if math.abs(d.wagon.position.y-d.position.y)<10 then return end
  local expected={}
  local function count(inv)
   if not inv then return end
   for i=1,#inv do if inv[i].valid_for_read then
    local key=inv[i].name.."|"..inv[i].quality.name
    expected[key]=(expected[key] or 0)+inv[i].count
   end end
  end
  count(d.entity.get_inventory(defines.inventory.chest));count(I.cargo(d));count(d.recovery)
  for _,loco in ipairs{d.head,d.rear} do count(loco.get_fuel_inventory());count(loco.get_burnt_result_inventory()) end
  expected["ct-construction-depot|normal"]=1
  local head,wagon,rear,stop=d.head,d.wagon,d.rear,d.stop
  assert(Runtime.factory.withdraw(d,true),"Remote withdrawal did not finish")
  assert(not head.valid and not wagon.valid and not rear.valid and not stop.valid)
  assert(not storage.ct.depots[state.id])
  local actual={}
  for _,entity in pairs(game.surfaces[1].find_entities_filtered{type="item-entity"}) do
   local stack=entity.stack;local key=stack.name.."|"..stack.quality.name
   actual[key]=(actual[key] or 0)+stack.count
  end
  for key,value in pairs(expected) do assert(actual[key]==value,"Remote recovery mismatch: "..key) end
  for key,value in pairs(actual) do assert(expected[key]==value,"Unexpected recovery item: "..key) end
  state.done=true
  log("CT_TEST SUCCESS lifecycle "..helpers.table_to_json{items=actual,remote=true})
  helpers.write_file("ct-engine-result.txt","CT ENGINE OK\n",false)
  return
 end
 local d=storage.ct.depots[state.id]
 assert(d,"Depot disappeared")
 if (d.refills or 0)>0 and not state.checkpoint then
  state.checkpoint=true
  game.auto_save("ct-midmission")
  log("CT_TEST checkpoint "..game.tick)
 end
 if d.arrival=="refill" and not state.refill_prepared then
  -- 001-AC8 / 001-AC10: after the first shortage the supply target is raised.
  for _,a in ipairs(state.accessories) do assert(a.ghost.valid,"Signal built before refill") end
  d.targets.rail=200;state.refill_prepared=true
  log("CT_TEST shortage-return")
 end
 local remaining=0
 for _,node in ipairs(state.route) do if node.ghost.valid then remaining=remaining+1 end end
 if remaining>0 then
  for _,a in ipairs(state.accessories) do assert(a.ghost.valid,"Accessory built before all rails") end
 end
 local built_accessories=0
 for _,a in ipairs(state.accessories) do if not a.ghost.valid then built_accessories=built_accessories+1 end end
 if remaining==0 and built_accessories==3 and Runtime.factory.at_home(d) then
  for _,node in ipairs(state.route) do
   assert(d.entity.surface.find_entity(node.name,node.position),"Rail ghost vanished without its real rail")
  end
  for _,a in ipairs(state.accessories) do
   assert(d.entity.surface.find_entity(a.name,a.position),"Accessory ghost vanished without its real entity: "..a.name)
  end
  assert(d.built==55,"Wrong number of paid constructions")
  for _,phase in ipairs{"build","accessory","accessories","idle","loading"} do assert(state.manual_checks and state.manual_checks[phase],"Manual takeover transition not tested: "..phase) end
  assert(d.head.train.id==state.original_train)
  assert((d.refills or 0)>0)
  local stock=d.entity.get_inventory(defines.inventory.chest)
  local cargo=I.cargo(d)
  assert(stock.get_item_count("rail")+cargo.get_item_count("rail")==416,"Incorrect rail payment")
  -- 001-AC13 / AC17: two buildings own two independent machines and requests.
  Runtime.worker.pause(d)
  local surface=d.entity.surface
  for y=-16,16,2 do surface.create_entity{name="straight-rail",position={40,y},direction=defines.direction.north,force="player"} end
  local other_entity=surface.create_entity{name=C.depot,position={46,0},force="player"}
  local other=Runtime.on_built{entity=other_entity}
  assert(other and other.head.train.id~=state.original_train)
  Runtime.worker.pause(other)
  state.isolated=surface.create_entity{name="entity-ghost",inner_name="straight-rail",position={150,150},direction=defines.direction.north,force="player"}
  Runtime.on_built{entity=state.isolated}
  assert(state.isolated.force~=game.forces.player)
  Runtime.registry.policy(d,false)
  assert(Runtime.registry.active(d.force_index,d.surface_index),"Second building request was lost")
  assert(Runtime.factory.withdraw(other,false))
  assert(not Runtime.registry.active(d.force_index,d.surface_index))
  state.phase="release";state.release_tick=event.tick+100
  log("CT_TEST loop-and-requests "..helpers.table_to_json{tick=event.tick,built=d.built,refills=d.refills,train=d.head.train.id})
 elseif event.tick%1800==0 then
  log("CT_TEST progress "..helpers.table_to_json{tick=event.tick,state=d.state,arrival=d.arrival,message=d.message,remaining=remaining,accessories=built_accessories,head=d.head.position,wagon=d.wagon.position})
 end
end)

local worker_tick=Runtime.worker.tick
Runtime.worker.tick=function(d)
 local state=storage.ct_test
 if state and d.id==state.id and d.enabled and d.auto_controlled and
  (d.state=="build" or d.state=="accessory" or d.state=="accessories" or d.state=="idle" or d.state=="loading") then
  state.manual_checks=state.manual_checks or {}
  if not state.manual_checks[d.state] then
   local before,phase=d.built,d.state
   d.head.train.manual_mode=true
   worker_tick(d)
   assert(not d.enabled and d.state=="paused" and d.head.train.manual_mode and d.built==before,"Manual takeover was ignored before new work")
   state.manual_checks[phase]=true
   log("CT_TEST manual-takeover SUCCESS "..phase)
   Runtime.worker.start(d)
   return
  end
 end
 return worker_tick(d)
end
