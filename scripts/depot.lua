local C=require("scripts.constants")
local G=require("scripts.geometry")
local D={}
local vehicles={"locomotive","cargo-wagon","fluid-wagon","artillery-wagon"}
function D.area(center,frame)
 local a,b=G.offset(center,frame,-16,-1.5),G.offset(center,frame,16,1.5)
 return {{math.min(a.x,b.x),math.min(a.y,b.y)},{math.max(a.x,b.x),math.max(a.y,b.y)}}
end
function D.rollback(layout)
 for i=#layout.created,1,-1 do local entity=layout.created[i];if entity.valid then entity.destroy() end end
 D.clear_decor(layout)
end
function D.clear_decor(depot)
 for _,object in ipairs(depot.decor or {}) do if object.valid then object.destroy() end end
 depot.decor={}
end
local function barriers(entity,center,frame)
 local result={}
 for _,side in ipairs{"workshop","walkway"} do
  result[#result+1]={name="ct-depot-barrier-"..side..(frame.direction%8==4 and "-horizontal" or "-vertical"),
   position=G.offset(center,frame,0,side=="workshop" and 4 or -3),force=entity.force}
 end
 return result
end
function D.ensure_barriers(depot)
 local entity=depot.entity
 if not (entity and entity.valid and entity.name==C.module) then return end
 depot.barriers=depot.barriers or {}
 for i,definition in ipairs(barriers(entity,depot.position,G.frame(entity.direction))) do
  if not (depot.barriers[i] and depot.barriers[i].valid) then
   local barrier=assert(entity.surface.create_entity(definition))
   barrier.minable_flag=false;barrier.destructible=false
   depot.barriers[i]=barrier
  end
 end
end
function D.clear_barriers(depot)
 for _,barrier in ipairs(depot.barriers or {}) do if barrier.valid then barrier.destroy() end end
 depot.barriers={}
end
function D.prepare(entity)
 local frame=G.frame(entity.direction)
 if not frame then return nil,"placement" end
 local center={x=math.floor(entity.position.x/2)*2+1,y=math.floor(entity.position.y/2)*2+1}
 local layout={center=center,frame=frame,created={},rails={},track={},decor={}}
 local surface,force=entity.surface,entity.force
 if #surface.find_entities_filtered{area=D.area(center,frame),type=vehicles}>0 then return nil,"occupied" end
 for _,definition in ipairs(barriers(entity,center,frame)) do
  local box=prototypes.entity[definition.name].collision_box
  local p=definition.position
  local area={{p.x+box.left_top.x+C.epsilon,p.y+box.left_top.y+C.epsilon},
              {p.x+box.right_bottom.x-C.epsilon,p.y+box.right_bottom.y-C.epsilon}}
  for _,other in pairs(surface.find_entities_filtered{area=area}) do
   -- Seul l'emplacement exact du quai est vérifié après la création de la voie.
   local planned_stop=other.type=="train-stop" and G.same(other.position,G.offset(center,frame,10,2))
   if not planned_stop and other.prototype.collision_mask.layers.object then return nil,"placement" end
  end
 end
 local positions,definitions={},{}
 for along=-14,14,2 do
  local position=G.offset(center,frame,along)
  local found
  for _,rail in pairs(surface.find_entities_filtered{position=position,type="straight-rail"}) do
   if G.same(rail.position,position) and rail.direction%8==frame.direction%8 and rail.force==force then found=rail;break end
  end
  positions[#positions+1]={position=position,rail=found}
  if not found then
   local definition={name=math.abs(along)==14 and C.connector or C.rail,position=position,direction=frame.direction,force=force}
   if not surface.can_place_entity(definition) then return nil,"placement" end
   definitions[#definitions+1]=definition
  end
 end
 local stock={name=C.stock,position=G.offset(center,frame,0,6),direction=frame.direction,force=force}
 if not surface.can_place_entity(stock) then return nil,"placement" end
 for _,definition in ipairs(definitions) do
  local rail=surface.create_entity(definition)
  if not (rail and G.same(rail.position,definition.position)) then
   if rail then rail.destroy() end
   D.rollback(layout);return nil,"placement"
  end
  rail.minable_flag=false;rail.destructible=false
  layout.created[#layout.created+1]=rail;layout.rails[#layout.rails+1]=rail
 end
 for _,entry in ipairs(positions) do
  local rail=entry.rail
  if not rail then
   for _,created in ipairs(layout.rails) do if G.same(created.position,entry.position) then rail=created;break end end
  end
  layout.track[#layout.track+1]=rail
 end
 layout.stock=surface.create_entity(stock)
 if not layout.stock then D.rollback(layout);return nil,"placement" end
 layout.stock.minable_flag=false
 layout.created[#layout.created+1]=layout.stock
 return layout
end
function D.foreign_train(depot)
 local track=depot.track or depot.rails
 if not track or #track==0 then return false end
 local own={}
 for _,name in ipairs{"head","wagon","rear"} do local e=depot[name];if e and e.valid then own[e.unit_number]=true end end
 for _,rail in ipairs(track) do
  if rail.valid then
   local frame=G.frame(rail.direction%8)
   local a,b=G.offset(rail.position,frame,-1,-1.5),G.offset(rail.position,frame,1,1.5)
   for _,vehicle in pairs(rail.surface.find_entities_filtered{area={{math.min(a.x,b.x),math.min(a.y,b.y)},{math.max(a.x,b.x),math.max(a.y,b.y)}},type=vehicles}) do
    if not own[vehicle.unit_number] then return true end
   end
  end
 end
 return false
end
return D
