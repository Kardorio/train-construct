local C=require("scripts.constants")
local R=require("scripts.registry")
local I=require("scripts.inventory")
local G=require("scripts.geometry")
local D=require("scripts.depot")
local Categories=require("scripts.categories")
local Circuit=require("scripts.circuit")
local F={}
function F.conflict(depot)
 for id,other in pairs(storage.ct.depots) do
  if id~=depot.id and other.force_index==depot.force_index and other.surface_index==depot.surface_index then return true end
 end
 return false
end
function F.create(entity)
 local state=storage.ct;local id=entity.unit_number
 if state.depots[id] then return state.depots[id] end
 if F.conflict{id=id,force_index=entity.force.index,surface_index=entity.surface.index} then return nil,"fleet-limit" end
 local position=entity.position
 local layout,frame,center
 if entity.name==C.module then
  local reason
  layout,reason=D.prepare(entity)
  if not layout then return nil,reason end
  frame,center=layout.frame,layout.center
 else
 local candidates=entity.surface.find_entities_filtered{area={{position.x-8,position.y-2},{position.x-3,position.y+2}},type="straight-rail",force=entity.force}
 table.sort(candidates,function(a,b) return G.distance(a.position,position)<G.distance(b.position,position) end)
 local rail
 for _,r in ipairs(candidates) do
  if r.direction==defines.direction.north or r.direction==defines.direction.south then rail=r;break end
 end
 if not rail then return nil,"placement" end
 local x,y=rail.position.x,rail.position.y
 -- A single nearby rail must never make vehicles snap onto another parallel track.
 for offset=-10,10,2 do
  local complete=false
  for _,part in pairs(entity.surface.find_entities_filtered{name="straight-rail",position={x,y+offset},force=entity.force}) do
   if G.same(part.position,{x=x,y=y+offset}) and (part.direction==defines.direction.north or part.direction==defines.direction.south) then complete=true end
  end
  if not complete then return nil,"placement" end
 end
 local occupied=entity.surface.find_entities_filtered{area={{x-1.5,y-14},{x+1.5,y+14}},type={"locomotive","cargo-wagon","fluid-wagon","artillery-wagon"}}
 if #occupied>0 then return nil,"occupied" end
 frame=G.frame(defines.direction.north);center={x=x,y=y}
 end
 local definitions={
  {name=C.locomotive,position=G.offset(center,frame,7),direction=frame.direction},
  {name=C.wagon,position=center,direction=frame.direction},
  {name=C.locomotive,position=G.offset(center,frame,-7),direction=(frame.direction+8)%16},
  {name=C.stop,position=G.offset(center,frame,10,2),direction=frame.direction}
 }
 local created={}
 local function rollback()
  for _,e in ipairs(created) do if e.valid then e.destroy() end end
  if layout then D.rollback(layout) end
 end
 for _,definition in ipairs(definitions) do
  definition.force=entity.force
  if not entity.surface.can_place_entity(definition) then
   rollback()
   return nil,"placement"
  end
  local e=entity.surface.create_entity(definition)
  if not e then
   rollback()
   return nil,"placement"
  end
  if not G.same(e.position,definition.position) then
   e.destroy()
   rollback()
   return nil,"placement"
  end
  created[#created+1]=e
 end
 local head,wagon,rear,stop=created[1],created[2],created[3],created[4]
 if not (head.train and head.train==wagon.train and head.train==rear.train and #head.train.carriages==3 and stop.connected_rail) then
  rollback()
  return nil,"composition"
 end
 stop.backer_name="Construction #"..id
 if layout then for _,component in ipairs(layout.created) do created[#created+1]=component end end
 for _,e in ipairs(created) do e.minable_flag=false;state.components[e.unit_number]=id end
 local targets={}
 for name,count in pairs(C.targets) do targets[name]=count end
 local depot={
  id=id,entity=entity,quality=entity.quality.name,head=head,wagon=wagon,rear=rear,stop=stop,
  position=layout and center or position,surface_index=entity.surface.index,force_index=entity.force.index,
  stock=layout and layout.stock,rails=layout and layout.rails,track=layout and layout.track,
  state="loading",enabled=true,auto_controlled=false,bot_enabled=false,bot_counted=false,targets=targets,
  fuel="coal",fuel_target=C.fuel_target,visited={},pending={},built=0,
  recovery=game.create_inventory(100),train_id=head.train.id,
  frontier_cursor=1,generation=game.tick
 }
 depot.registrations={R.track(entity,"depot",id)}
 Categories.initialize(depot)
 for _,component in ipairs(created) do
  depot.registrations[#depot.registrations+1]=R.track(component,"component",id)
 end
 state.depots[id]=depot
 if layout then
  entity.proxy_target_entity=layout.stock
  entity.proxy_target_inventory=defines.inventory.chest
  entity.rotatable=false
  depot.decor={}
  D.ensure_barriers(depot)
 end
 Circuit.initialize(depot)
 head.train.manual_mode=true
 R.policy(depot,true)
 R.scan_surface(entity.surface)
 return depot
end
function F.valid(depot)
 if depot.stock and not depot.stock.valid then return false end
 for _,rail in ipairs(depot.track or {}) do if not rail.valid then return false end end
 if not (depot.head and depot.head.valid and depot.wagon and depot.wagon.valid and depot.rear and depot.rear.valid and depot.stop and depot.stop.valid) then return false end
 local train=depot.head.train
 return train and train==depot.wagon.train and train==depot.rear.train and #train.carriages==3
end
function F.home_goals(depot)
 local stop=depot.stop
 if not (stop and stop.valid and stop.connected_rail) then return {} end
 local rail=stop.connected_rail
 local goals={{rail=rail,direction=stop.connected_rail_direction}}
 local opposite=(rail.get_rail_end(stop.connected_rail_direction).location.direction+8)%16
 local frame=G.frame((opposite+8)%16)
 if not frame then return goals end
 local mirror=G.offset(rail.position,frame,-20)
 for _,other in pairs(rail.surface.find_entities_filtered{type="straight-rail",position=mirror,force=rail.force}) do
  if G.same(other.position,mirror) then
   for _,direction in ipairs{defines.rail_direction.front,defines.rail_direction.back} do
    if other.get_rail_end(direction).location.direction==opposite then goals[#goals+1]={rail=other,direction=direction} end
   end
  end
 end
 return goals
end
function F.at_home(depot)
 if not F.valid(depot) then return false end
 local frame=G.frame(depot.stop.direction or defines.direction.north)
 if not frame then return false end
 local dx,dy=depot.wagon.position.x-depot.position.x,depot.wagon.position.y-depot.position.y
 return depot.head.train.speed==0 and G.distance(depot.wagon.position,depot.position)<=65 and
  math.abs(dx*frame.forward.x+dy*frame.forward.y)<3
end
function F.release_claims(depot)
 for id,owner in pairs(storage.ct.claims) do if owner==depot.id then storage.ct.claims[id]=nil end end
end
function F.damage(depot)
 depot.state="damaged";depot.enabled=false;depot.auto_controlled=false
 depot.return_search=nil;depot.task=nil;depot.accessory=nil
 F.release_claims(depot)
 local trains={}
 for _,field in ipairs{"head","wagon","rear"} do
  local entity=depot[field]
  local current=entity and entity.valid and entity.train
  if current then trains[current.id]=current end
 end
 for _,current in pairs(trains) do if #current.passengers==0 then current.manual_mode=true end end
end
function F.withdraw(depot,refund,origin)
 if depot.retired then return true end
 depot.quality=depot.quality or (depot.entity and depot.entity.valid and depot.entity.quality.name) or "normal"
 depot.pending_removal=true;depot.enabled=false
 if origin=="mined" or origin=="destroyed" then
  depot.refund_origin=origin;depot.refund=false
 elseif refund and not depot.refund_origin then depot.refund=true end
 R.policy(depot,false)
 F.release_claims(depot)
 local trains={}
 for _,field in ipairs{"head","wagon","rear"} do
  local entity=depot[field]
  local current=entity and entity.valid and entity.train
  if current then trains[current.id]=current end
 end
 -- A detached component can have a different driver and speed from the head.
 for _,current in pairs(trains) do
  if #current.passengers>0 then depot.state="occupied";return false end
 end
 local moving=false
 for _,current in pairs(trains) do
  current.manual_mode=true
  if current.speed~=0 then moving=true end
 end
 if moving then depot.state="stopping";return false end
 if D.foreign_train(depot) then depot.state="occupied-track";return false end
 local surface=game.surfaces[depot.surface_index]
 if not surface then return false end
 local complete=true
 for _,e in ipairs{depot.head,depot.wagon,depot.rear} do
  if e and e.valid then
   local clean=I.spill(e.get_inventory(defines.inventory.cargo_wagon),surface,e.position)
   clean=I.spill(e.get_fuel_inventory(),surface,e.position) and clean
   clean=I.spill(e.get_burnt_result_inventory(),surface,e.position) and clean
   if clean then storage.ct.components[e.unit_number]=nil;e.destroy{raise_destroy=true} else complete=false end
  end
 end
 complete=I.spill(depot.recovery,surface,depot.position) and complete
 local stock=depot.stock or depot.entity
 if stock and stock.valid then complete=I.spill(stock.get_inventory(defines.inventory.chest),surface,stock.position or depot.position) and complete end
 if not complete then depot.state="recovery";return false end
 if depot.stop and depot.stop.valid then storage.ct.components[depot.stop.unit_number]=nil;depot.stop.destroy() end
 if depot.stock and depot.stock.valid then storage.ct.components[depot.stock.unit_number]=nil;depot.stock.destroy() end
 for _,rail in ipairs(depot.rails or {}) do if rail.valid then storage.ct.components[rail.unit_number]=nil;rail.destroy() end end
 D.clear_decor(depot)
 D.clear_barriers(depot)
 if depot.entity and depot.entity.valid then depot.entity.destroy() end
 if depot.refund then surface.spill_item_stack{position=depot.position,stack={name=C.depot,count=1,quality=depot.quality},allow_belts=false} end
 if depot.recovery.valid then depot.recovery.destroy() end
 for _,number in ipairs(depot.registrations or {}) do
  if storage.ct.registrations then storage.ct.registrations[number]=nil end
 end
 depot.retired=true;storage.ct.depots[depot.id]=nil
 return true
end
return F
