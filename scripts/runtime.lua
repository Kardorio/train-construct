local C=require("scripts.constants")
local G=require("scripts.geometry")
local R=require("scripts.registry")
local F=require("scripts.factory")
local W=require("scripts.worker")
local Gui=require("scripts.gui")
local D=require("scripts.depot")
local Runtime={}
function Runtime.initialize()
 R.initialize()
 storage.ct.path_budget=1
 for _,depot in pairs(storage.ct.depots) do
  if depot.entity and depot.entity.valid and depot.entity.name==C.module then
   depot.entity.rotatable=false
   if depot.stock and depot.stock.valid then depot.stock.direction=depot.entity.direction end
   D.clear_decor(depot)
   D.ensure_barriers(depot)
  end
  if depot.entity and depot.entity.valid and depot.bot_enabled then R.technical(depot.force_index) end
 end
end
function Runtime.on_built(event)
 local entity=event.entity or event.created_entity or event.destination
 if not (entity and entity.valid) then return end
 if entity.name==C.depot or entity.name==C.module then
  local depot,reason=F.create(entity)
  if not depot then
   local position,surface=entity.position,entity.surface
   local refund={name=C.depot,count=1,quality=entity.quality.name}
   local player=event.player_index and game.get_player(event.player_index)
   if player then player.print({reason=="fleet-limit" and "ct.fleet-limit" or "ct.invalid-placement"}) end
   if event.robot and event.robot.valid then
    local cargo=event.robot.get_inventory(defines.inventory.robot_cargo)
    if cargo.insert(refund)==0 then surface.spill_item_stack{position=position,stack=refund,allow_belts=false} end
   elseif player then
    if player.insert(refund)==0 then surface.spill_item_stack{position=position,stack=refund,allow_belts=false} end
   else
    surface.spill_item_stack{position=position,stack=refund,allow_belts=false}
   end
   entity.destroy()
   return nil,reason
  end
  return depot
 elseif entity.type=="entity-ghost" then return R.register(entity)
 elseif C.rail_types[entity.name] then R.from_rail(entity) end
end
function Runtime.on_removed(event)
 local entity=event.entity
 if not (entity and entity.valid) then return end
 local id=entity.unit_number
 local depot=storage.ct.depots[id]
 if depot then
  local mined=event.name==defines.events.on_player_mined_entity or event.name==defines.events.on_robot_mined_entity
  F.withdraw(depot,false,mined and "mined" or "destroyed")
 else
  local owner=storage.ct.components[id]
  if owner then
   depot=storage.ct.depots[owner]
   if depot and not depot.pending_removal then F.damage(depot) end
  end
  if storage.ct.ghosts[id] then R.unregister(id) end
 end
end
function Runtime.tick()
 R.tick();storage.ct.path_budget=1
 local ids={}
 for id in pairs(storage.ct.depots) do ids[#ids+1]=id end
 table.sort(ids)
 if #ids>0 then
  local cursor=storage.ct.worker_cursor or 1
  for _=1,math.min(4,#ids) do
   if cursor>#ids then cursor=1 end
   local depot=storage.ct.depots[ids[cursor]]
   if depot then W.tick(depot) end
   cursor=cursor+1
  end
  storage.ct.worker_cursor=cursor
 end
 if game.tick%30==0 then for _,player in pairs(game.connected_players) do Gui.update(player) end end
end
function Runtime.motion()
 for _,depot in pairs(storage.ct.depots) do W.motion(depot) end
end
function Runtime.gui_opened(event)
 local entity=event.entity
 if not (entity and entity.valid) then return end
 local id=(entity.name==C.depot or entity.name==C.module) and entity.unit_number or storage.ct.components[entity.unit_number]
 local depot=id and storage.ct.depots[id]
 if depot then
  local player=game.get_player(event.player_index)
  local anchor=entity.name==C.module and defines.relative_gui_type.proxy_container_gui or
   (entity.name==C.depot or entity.name==C.stock) and defines.relative_gui_type.container_gui or defines.relative_gui_type.train_gui
  Gui.open(player,depot,anchor)
 end
end
function Runtime.schedule_changed(event)
 if storage.ct.mutating then return end
 local t=event.train
 if not (t and t.valid) then return end
 for _,d in pairs(storage.ct.depots) do
  if F.valid(d) and d.head.train==t and d.enabled then W.pause(d) end
 end
end
function Runtime.train_changed(event)
 for _,d in pairs(storage.ct.depots) do
  if not d.pending_removal and not F.valid(d) then F.damage(d) end
 end
end
function Runtime.surface_removed(event)
 local index=event.surface_index
 local ids={}
 for id,d in pairs(storage.ct.depots) do if d.surface_index==index then ids[#ids+1]=id end end
 for _,id in ipairs(ids) do
  local d=storage.ct.depots[id]
  R.policy(d,false);F.release_claims(d)
  D.clear_decor(d)
  for number,owner in pairs(storage.ct.components) do if owner==id then storage.ct.components[number]=nil end end
  if d.recovery and d.recovery.valid then d.recovery.destroy() end
  storage.ct.depots[id]=nil
 end
 for id,record in pairs(storage.ct.ghosts) do if record.surface==index then R.unregister(id) end end
end
function Runtime.object_destroyed(event)
 local map=storage.ct.registrations or {}
 local object=map[event.registration_number]
 if not object then return end
 map[event.registration_number]=nil
 if object.kind=="ghost" then R.unregister(object.id);return end
 local d=storage.ct.depots[object.id]
 if not d then return end
 if object.kind=="depot" then F.withdraw(d,false,"destroyed")
 elseif not d.pending_removal then F.damage(d) end
end
function Runtime.ghost_changed(event)
 local entity=event.entity or event.ghost
 if entity and entity.valid then
  R.register(entity)
  R.rescan(entity.surface,entity.position)
 end
end
function Runtime.forces_merging(event)
 local source=event.source.index
 for _,d in pairs(storage.ct.depots) do
  if d.force_index==source then W.pause(d);R.policy(d,false) end
 end
 for _,record in pairs(storage.ct.ghosts) do
  if record.owner==source and record.entity.valid then record.entity.force=event.source end
 end
end
function Runtime.forces_merged(event)
 local source,destination=event.source_index,event.destination.index
 for _,d in pairs(storage.ct.depots) do if d.force_index==source then d.force_index=destination end end
 for tech,owner in pairs(storage.ct.force_owner) do if owner==source then storage.ct.force_owner[tech]=destination end end
 storage.ct.forces[source]=nil
 for id,record in pairs(storage.ct.ghosts) do
  if record.owner==source and record.entity.valid then
   R.change_domain(record,destination,record.surface)
  end
 end
 storage.ct.policy_cursor=1
end
Runtime.gui=Gui
Runtime.registry=R
Runtime.factory=F
Runtime.worker=W
return Runtime
