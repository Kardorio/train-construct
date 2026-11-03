local I = {}
function I.stock(depot)
 local stock=depot.stock or depot.entity
 if stock and stock.valid then return stock.get_inventory(defines.inventory.chest) end
end
function I.cargo(depot)
 if depot.wagon and depot.wagon.valid then return depot.wagon.get_inventory(defines.inventory.cargo_wagon) end
end
function I.spill(inventory, surface, position)
 if not inventory then return true end
 for i=1,#inventory do
  local stack=inventory[i]
  if stack.valid_for_read then
   local dropped=surface.spill_item_stack{position=position,stack=stack,allow_belts=false,enable_looted=false,use_start_position_on_failure=true}
   local count=0
   for _,entity in pairs(dropped) do if entity.valid then count=count+entity.stack.count end end
   if count>=stack.count then stack.clear()
   elseif count>0 then stack.count=stack.count-count end
  end
 end
 return inventory.is_empty()
end
function I.cost(ghost, inventory)
 local options=ghost.ghost_prototype.items_to_place_this
 if not options then return nil end
 local quality=ghost.quality.name
 for _,item in ipairs(options) do
  if inventory.get_item_count{name=item.name,quality=quality}>=item.count then
   return {name=item.name,quality=quality,count=item.count}
  end
 end
end
function I.revive(depot, ghost)
 local inventory=I.cargo(depot)
 if not inventory or not ghost.valid then return nil,"missing" end
 local cost=I.cost(ghost,inventory)
 if not cost then
  local options=ghost.ghost_prototype.items_to_place_this
  if options and options[1] then depot.missing={name=options[1].name,quality=ghost.quality.name,count=options[1].count} end
  return nil,"materials"
 end
 local taken=inventory.remove(cost)
 if taken~=cost.count then
  if taken>0 then inventory.insert{name=cost.name,quality=cost.quality,count=taken} end
  return nil,"materials"
 end
 local old_force=ghost.force
 ghost.force=game.forces[depot.force_index]
 -- Overflow is the source of truth; the first return value must not be credited again.
 local _,real=ghost.revive{overflow=depot.recovery,raise_revive=true}
 if not real or not real.valid then
  local restored=inventory.insert(cost)
  if restored<cost.count then depot.recovery.insert{name=cost.name,quality=cost.quality,count=cost.count-restored} end
  if ghost.valid then ghost.force=old_force end
  return nil,"obstacle"
 end
 depot.missing=nil
 depot.built=(depot.built or 0)+1
 return real
end
function I.transfer(source,target,name,quality,amount)
 local count=math.min(amount,source.get_item_count{name=name,quality=quality})
 if count<=0 then return 0 end
 local inserted=target.insert{name=name,quality=quality,count=count}
 if inserted>0 then assert(source.remove{name=name,quality=quality,count=inserted}==inserted) end
 return inserted
end
local function compatible(burner, prototype)
 if not burner or not prototype or prototype.fuel_value<=0 then return false end
 for _,category in pairs(prototype.fuel_categories or {}) do
  if burner.fuel_categories[category] then return true end
 end
 return false
end
function I.fuel_energy(locomotive)
 if not (locomotive and locomotive.valid and locomotive.burner) then return 0 end
 local burner=locomotive.burner
 local energy=burner.remaining_burning_fuel
 local inventory=locomotive.get_fuel_inventory()
 for i=1,#inventory do
  local stack=inventory[i]
  if stack.valid_for_read and compatible(burner,stack.prototype) then energy=energy+stack.count*stack.prototype.fuel_value end
 end
 return energy
end
local function fuel_goal(depot)
 return depot.fuel_target*prototypes.item.coal.fuel_value
end
local function load_fuel(depot,locomotive,source)
 if not (locomotive and locomotive.valid and locomotive.burner) then return end
 local fuel=locomotive.get_fuel_inventory()
 for i=1,#source do
  local deficit=fuel_goal(depot)-I.fuel_energy(locomotive)
  if deficit<=0 then break end
  local stack=source[i]
  if stack.valid_for_read and compatible(locomotive.burner,stack.prototype) then
   local copy=game.create_inventory(1)
   copy[1].set_stack(stack)
   copy[1].count=math.min(stack.count,math.ceil(deficit/stack.prototype.fuel_value))
   local inserted=fuel.insert(copy[1])
   copy.destroy()
   if inserted==stack.count then stack.clear()
   elseif inserted>0 then stack.count=stack.count-inserted end
  end
 end
end
function I.load(depot)
 if not (depot.entity and depot.entity.valid) then return false end
 local source=I.stock(depot)
 if not source then return false end
 local target=I.cargo(depot)
 if not target then return false end
 for name,count in pairs(depot.targets) do
  I.transfer(source,target,name,"normal",math.max(0,count-target.get_item_count{name=name,quality="normal"}))
 end
 if depot.missing then
  local m=depot.missing
  I.transfer(source,target,m.name,m.quality,math.max(0,m.count-target.get_item_count{name=m.name,quality=m.quality}))
 end
 for _,locomotive in ipairs{depot.head,depot.rear} do
  load_fuel(depot,locomotive,source)
 end
 I.transfer(depot.recovery,target,"rail","normal",depot.recovery.get_item_count("rail"))
 return true
end
function I.ready(depot)
 local cargo=I.cargo(depot)
 if not cargo then return false,{"ct.cargo-missing"} end
 if depot.missing then
  local m=depot.missing
  local deficit=m.count-cargo.get_item_count{name=m.name,quality=m.quality}
  if deficit>0 then return false,{"ct.missing",prototypes.item[m.name].localised_name,m.quality,deficit} end
 end
 for name,count in pairs(depot.targets) do
  local deficit=count-cargo.get_item_count{name=name,quality="normal"}
  if deficit>0 and (not depot.refill_mode or (depot.refill_mode=="rails" and name=="rail")) then
   return false,{"ct.missing",prototypes.item[name].localised_name,"normal",deficit}
  end
 end
 for index,loco in ipairs{depot.head,depot.rear} do
  local deficit=fuel_goal(depot)-I.fuel_energy(loco)
  if deficit>0 then return false,{"ct.fuel-missing",index,math.ceil(deficit/1000000)} end
 end
 return true
end
function I.low_fuel(depot)
 for _,loco in ipairs{depot.head,depot.rear} do
  if I.fuel_energy(loco)<2*prototypes.item.coal.fuel_value then return true end
 end
 return false
end
return I
