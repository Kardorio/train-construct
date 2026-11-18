local C=require("scripts.constants")
local R=require("scripts.registry")
local W=require("scripts.worker")
local Settings={tag="construction-train-settings",version=1}

local function compatible(entity)
 if not (entity and entity.valid) then return false end
 local name=entity.type=="entity-ghost" and entity.ghost_name or entity.name
 return name==C.module or name==C.depot
end
local function depot(entity)
 return compatible(entity) and storage.ct.depots[entity.unit_number] or nil
end
local function quantity(value,fallback)
 if type(value)~="number" or value~=value or value<0 or value>100000 then return fallback end
 return math.floor(value)
end
local function boolean(value,fallback)
 if type(value)=="boolean" then return value end
 return fallback
end

-- A whitelist prevents imported state, identities and arbitrary nested tags
-- from becoming runtime data. Unknown versions are deliberately left alone.
function Settings.decode(tags)
 if type(tags)~="table" then return end
 local raw=tags[Settings.tag]
 if type(raw)~="table" or raw.version~=Settings.version then return end
 local result={version=Settings.version,categories={},targets={},
  fuel_target=quantity(raw.fuel_target,C.fuel_target),bot_enabled=boolean(raw.bot_enabled,false)}
 local categories=type(raw.categories)=="table" and raw.categories or {}
 local targets=type(raw.targets)=="table" and raw.targets or {}
 for name,count in pairs(C.targets) do
  result.categories[name]=boolean(categories[name],true)
  result.targets[name]=quantity(targets[name],count)
 end
 if type(raw.circuit)=="table" then
  result.circuit={}
  for _,name in ipairs{"read_contents","read_empty_slots"} do
   if type(raw.circuit[name])=="boolean" then result.circuit[name]=raw.circuit[name] end
  end
 end
 return result
end

function Settings.encode(d)
 local result=Settings.decode{[Settings.tag]={version=Settings.version,
  categories=d.categories,targets=d.targets,fuel_target=d.fuel_target,bot_enabled=d.bot_enabled}}
 local control=d.entity.get_control_behavior()
 if control then
  result.circuit={read_contents=control.read_contents,read_empty_slots=control.read_empty_slots}
 end
 return result
end

function Settings.restore(d,tags)
 local settings=Settings.decode(tags)
 if not settings then return false end
 W.pause(d)
 for name in pairs(C.targets) do W.set_category(d,name,settings.categories[name]) end
 d.targets=settings.targets;d.fuel_target=settings.fuel_target
 R.policy(d,settings.bot_enabled)
 -- Re-evaluate reservations even if the boolean did not change.
 storage.ct.policy_cursor=1
 if settings.circuit then
  local control=d.entity.get_or_create_control_behavior()
  if control then
   for name,value in pairs(settings.circuit) do control[name]=value end
   d.circuit_initialized=true
  end
 end
 return true
end

function Settings.blueprint(event)
 local blueprint
 if event.record then
  if not (event.record.valid and event.record.type=="blueprint") then return end
  blueprint=event.record
 else
  local stack=event.stack
  if not (stack and stack.valid and stack.valid_for_read and stack.is_blueprint) then return end
  blueprint=stack
 end
 if not event.mapping then return end
 local entries={}
 for _,entry in pairs(blueprint.get_blueprint_entities() or {}) do entries[entry.entity_number]=entry.name end
 for index,entity in pairs(event.mapping.get()) do
  if compatible(entity) then
   local name=entity.type=="entity-ghost" and entity.ghost_name or entity.name
   -- Another mod may have rebuilt the blueprint, invalidating its mapping.
   if entries[index]==name then
    local d=depot(entity)
    local settings=d and Settings.encode(d) or
     (entity.type=="entity-ghost" and Settings.decode(entity.tags))
    if settings then blueprint.set_blueprint_entity_tag(index,Settings.tag,settings) end
   end
  end
 end
end

function Settings.cloned(destination,source)
 local original=depot(source)
 if not original then return false end
 -- The factory has already rebound a cloned module to its own new stock.
 -- Only configuration crosses this boundary; native legacy inventories are
 -- left to Factorio's cloning behavior.
 return Settings.restore(destination,{[Settings.tag]=Settings.encode(original)})
end

function Settings.pasted(event)
 local source,destination=event.source,event.destination
 if not (compatible(source) and compatible(destination)) then return end
 if source.force~=destination.force or source==destination then return end
 local d=depot(source)
 local settings=d and Settings.encode(d) or (source.type=="entity-ghost" and Settings.decode(source.tags))
 if not settings then return end
 if destination.type=="entity-ghost" then
  local tags=destination.tags or {};tags[Settings.tag]=settings;destination.tags=tags
 else
  local target=depot(destination)
  if target then Settings.restore(target,{[Settings.tag]=settings}) end
 end
end

function Settings.blueprint_pasted(event)
 local d=depot(event.entity)
 if d then Settings.restore(d,event.tags) end
end
return Settings
