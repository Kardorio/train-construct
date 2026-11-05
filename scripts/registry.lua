local C = require("scripts.constants")
local G = require("scripts.geometry")
local Categories=require("scripts.categories")
local R = {}
local function data() return storage.ct end
function R.initialize()
 storage.ct=storage.ct or {schema_version=1,depots={},ghosts={},ghost_order={},index={},frontiers={},frontier_order={},claims={},components={},policies={},forces={},force_owner={},scan={},scan_head=1,dirty={},dirty_head=1,policy_cursor=1}
end
local function frontier_changed(record)
 local state=data()
 state.frontier_sequence=(state.frontier_sequence or 0)+1
 if not record then state.frontier_domains=nil;return end
 state.frontier_domains=state.frontier_domains or {}
 local key=record.owner..":"..record.surface
 state.frontier_domains[key]={revision=state.frontier_sequence}
end
function R.frontier_ids(owner,surface)
 local state=data()
 state.frontier_ids=nil
 state.frontier_domains=state.frontier_domains or {}
 local key=owner..":"..surface
 local cache=state.frontier_domains[key]
 if not cache then cache={revision=state.frontier_sequence or 0};state.frontier_domains[key]=cache end
 if not cache.ids then
  local ids={}
  for id in pairs(state.frontiers) do
   local record=state.ghosts[id]
   if record and record.owner==owner and record.surface==surface then ids[#ids+1]=id end
  end
  table.sort(ids);cache.ids=ids
 end
 return cache.ids,cache.revision
end
function R.change_domain(record,owner,surface)
 if record.owner==owner and record.surface==surface then return end
 local state=data()
 frontier_changed(record)
 if state.index[record.key]==record.id then state.index[record.key]=nil end
 if record.surface~=surface then
  state.frontiers[record.id]=nil
  if record.rail then state.dirty[#state.dirty+1]=record.id end
 end
 record.owner=owner;record.surface=surface
 record.key=G.key(owner,surface,record.entity.ghost_name,record.entity.position,record.entity.direction)
 state.index[record.key]=record.id
 frontier_changed(record)
end
function R.track(entity,kind,id)
 local state=data()
 state.registrations=state.registrations or {}
 local number=script.register_on_object_destroyed(entity)
 state.registrations[number]={kind=kind,id=id}
 return number
end
function R.owner(entity)
 return data().force_owner[entity.force.index] or entity.force.index
end
local function domain(owner,surface) return owner..":"..surface end
function R.active(owner,surface) return (data().policies[domain(owner,surface)] or 0)>0 end
function R.reserved(owner,surface,name)
 if not R.active(owner,surface) then return false end
 for _,depot in pairs(data().depots) do
  if depot.force_index==owner and depot.surface_index==surface and depot.bot_enabled and Categories.allowed(depot,name) then return true end
 end
 return false
end
function R.technical(owner)
 local state=data()
 local force=state.forces[owner] and game.forces[state.forces[owner]]
 if not force then
  force=game.forces["ct-reserved-"..owner] or game.create_force("ct-reserved-"..owner)
  state.forces[owner]=force.index;state.force_owner[force.index]=owner
 end
 local original=game.forces[owner]
 if original then original.set_friend(force,true);force.set_friend(original,true) end
 return force
end
function R.policy(depot,enabled)
 if depot.bot_counted==enabled then depot.bot_enabled=enabled;return end
 local key=domain(depot.force_index,depot.surface_index)
 local state=data()
 state.policies[key]=math.max(0,(state.policies[key] or 0)+(enabled and 1 or -1))
 depot.bot_counted=enabled;depot.bot_enabled=enabled
 state.policy_cursor=1
 if enabled then R.technical(depot.force_index) end
end
function R.supported(entity)
 return entity.type=="entity-ghost" and (C.rail_types[entity.ghost_name] or C.accessory_types[entity.ghost_name])
end
function R.unregister(id)
 local state=data();local record=state.ghosts[id]
 if state.frontiers[id] then frontier_changed(record) end
 if record and state.index[record.key]==id then state.index[record.key]=nil end
 if record and record.registration and state.registrations then state.registrations[record.registration]=nil end
 state.ghosts[id]=nil;state.frontiers[id]=nil;state.claims[id]=nil
end
function R.register(entity)
 if not (entity and entity.valid and R.supported(entity)) then return end
 local state=data();local id=entity.unit_number
 local record=state.ghosts[id]
 if record then
  R.change_domain(record,record.owner,entity.surface.index)
  local key=G.key(record.owner,entity.surface.index,entity.ghost_name,entity.position,entity.direction)
  if key~=record.key then
   if state.index[record.key]==id then state.index[record.key]=nil end
   if state.frontiers[id] then frontier_changed(record) end
   record.surface=entity.surface.index
   record.key=key;state.index[key]=id;state.frontiers[id]=nil
   if record.rail then state.dirty[#state.dirty+1]=id end
  end
  return record
 end
 local owner=R.owner(entity)
 local key=G.key(owner,entity.surface.index,entity.ghost_name,entity.position,entity.direction)
 record={entity=entity,owner=owner,surface=entity.surface.index,key=key,rail=C.rail_types[entity.ghost_name] or false,id=id}
 record.registration=R.track(entity,"ghost",id)
 state.ghosts[id]=record;state.ghost_order[#state.ghost_order+1]=id;state.index[key]=id
 if R.reserved(owner,record.surface,entity.ghost_name) then entity.force=R.technical(owner) end
 state.ghost_revision=(state.ghost_revision or 0)+1
 if record.rail then state.dirty[#state.dirty+1]=id end
 return record
end
function R.lookup(owner,surface,name,position,direction)
 local id=data().index[G.key(owner,surface,name,position,direction)]
 local record=id and data().ghosts[id]
 if record and record.entity.valid then return record end
 if id then R.unregister(id) end
end
function R.frontier(record,rail,direction)
 if not (record and record.entity.valid and rail.valid) then return end
 local state=data();local frontier=state.frontiers[record.id]
 if not frontier then
  frontier={id=record.id,anchors={}}
  state.frontiers[record.id]=frontier;state.frontier_order[#state.frontier_order+1]=record.id
 end
 for _,a in ipairs(frontier.anchors) do if a.rail==rail and a.direction==direction then return end end
 frontier.anchors[#frontier.anchors+1]={rail=rail,direction=direction}
 frontier_changed(record)
end
function R.from_rail(rail)
 if not (rail and rail.valid and C.rail_types[rail.name]) then return end
 data().ghost_revision=(data().ghost_revision or 0)+1
 local owner=rail.force.index
 for _,d in ipairs{defines.rail_direction.front,defines.rail_direction.back} do
  for _,ext in ipairs(rail.get_rail_end(d).get_rail_extensions("rail")) do
   if C.rail_types[ext.name] then R.frontier(R.lookup(owner,rail.surface.index,ext.name,ext.position,ext.direction),rail,d) end
  end
 end
end
local function discover(id)
 local record=data().ghosts[id]
 if not (record and record.entity.valid and record.rail) then return end
 local ghost=record.entity
 local p=ghost.position
 local rails=ghost.surface.find_entities_filtered{area={{p.x-12,p.y-12},{p.x+12,p.y+12}},type={"straight-rail","half-diagonal-rail","curved-rail-a","curved-rail-b"},force=game.forces[record.owner]}
 for _,rail in pairs(rails) do
  for _,d in ipairs{defines.rail_direction.front,defines.rail_direction.back} do
   for _,ext in ipairs(rail.get_rail_end(d).get_rail_extensions("rail")) do
    if ext.name==ghost.ghost_name and ext.direction==ghost.direction and G.same(ext.position,ghost.position) then R.frontier(record,rail,d) end
   end
  end
 end
end
function R.queue_scan(surface,x,y)
 local state=data()
 state.scan_keys=state.scan_keys or {}
 local key=surface..":"..x..":"..y
 if state.scan_keys[key] then return end
 state.scan_keys[key]=true
 state.scan[#state.scan+1]={surface=surface,x=x,y=y}
end
function R.scan_surface(surface)
 local state=data()
 state.scanned=state.scanned or {}
 if state.scanned[surface.index] then return end
 state.scanned[surface.index]=true
 for chunk in surface.get_chunks() do
  for x=0,3 do for y=0,3 do
   R.queue_scan(surface.index,chunk.x*32+x*8,chunk.y*32+y*8)
  end end
 end
end
function R.rescan(surface,position)
 local x=math.floor(position.x/8)*8
 local y=math.floor(position.y/8)*8
 for dx=-1,1 do for dy=-1,1 do
  R.queue_scan(surface.index,x+dx*8,y+dy*8)
 end end
end
function R.tick()
 local state=data()
 for _=1,2 do
  local job=state.scan[state.scan_head]
  if not job then break end
  state.scan[state.scan_head]=false;state.scan_head=state.scan_head+1
  if state.scan_keys then state.scan_keys[job.surface..":"..job.x..":"..job.y]=nil end
  local surface=game.surfaces[job.surface]
  if surface then
   for _,entity in pairs(surface.find_entities_filtered{area={{job.x,job.y},{job.x+8,job.y+8}},type="entity-ghost"}) do R.register(entity) end
  end
 end
 for _=1,8 do
  local id=state.dirty[state.dirty_head]
  if not id then break end
  state.dirty[state.dirty_head]=false;state.dirty_head=state.dirty_head+1
  discover(id)
 end
 for _=1,32 do
  local id=state.ghost_order[state.policy_cursor]
  if not id then break end
  state.policy_cursor=state.policy_cursor+1
  local record=state.ghosts[id]
  if record then
   if record.entity.valid then
    local desired=R.reserved(record.owner,record.surface,record.entity.ghost_name) and R.technical(record.owner) or game.forces[record.owner]
    if desired and record.entity.force~=desired then record.entity.force=desired end
   else R.unregister(id) end
  end
 end
end
return R
