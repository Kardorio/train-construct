local Fixture={}
local function point(v) return {x=v.x,y=v.y} end
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
 error("No requested extension")
end

local function loop_plan(surface,anchor,direction,turn,inspect)
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
 if inspect then for _,node in ipairs(planned) do inspect(node.real) end end
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

Fixture.loop=loop_plan
Fixture.outward=outward
return Fixture
