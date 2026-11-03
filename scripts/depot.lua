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
end
function D.prepare(entity)
 local frame=G.frame(entity.direction)
 if not frame then return nil,"placement" end
 local center={x=math.floor(entity.position.x/2)*2+1,y=math.floor(entity.position.y/2)*2+1}
 local layout={center=center,frame=frame,created={},rails={},track={},decor={}}
 local surface,force=entity.surface,entity.force
 if #surface.find_entities_filtered{area=D.area(center,frame),type=vehicles}>0 then return nil,"occupied" end
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
 local stock={name=C.stock,position=G.offset(center,frame,0,6),force=force}
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
function D.decorate(layout,surface)
 local a,b=G.offset(layout.center,layout.frame,-15,-2),G.offset(layout.center,layout.frame,15,8)
 local left_top={x=math.min(a.x,b.x),y=math.min(a.y,b.y)}
 local right_bottom={x=math.max(a.x,b.x),y=math.max(a.y,b.y)}
 layout.decor={
  rendering.draw_rectangle{surface=surface,left_top=left_top,right_bottom=right_bottom,color={r=0.2,g=0.25,b=0.28,a=0.35},filled=true,draw_on_ground=true},
  rendering.draw_rectangle{surface=surface,left_top=left_top,right_bottom=right_bottom,color={r=0.9,g=0.65,b=0.15,a=0.8},filled=false,width=2,draw_on_ground=true}
 }
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
