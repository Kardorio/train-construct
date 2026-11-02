local C = require("scripts.constants")
local G = {}
function G.key(owner, surface, name, position, direction)
 return table.concat({owner,surface,name,math.floor(position.x*256+0.5),math.floor(position.y*256+0.5),direction},":")
end
function G.same(a,b)
 local ax,ay=a.x or a[1],a.y or a[2]
 local bx,by=b.x or b[1],b.y or b[2]
 return math.abs(ax-bx)<C.epsilon and math.abs(ay-by)<C.epsilon
end
function G.rail_contact(entity, joint)
 if not (entity and entity.valid) then return nil end
 local a=entity.orientation*2*math.pi
 local vx,vy=math.sin(a),-math.cos(a)
 local dx,dy=joint.x-entity.position.x,joint.y-entity.position.y
 local along,side=dx*vx+dy*vy,dx*(-vy)+dy*vx
 local rod_x=along-3
 local length=math.sqrt(rod_x*rod_x+side*side)
 local angle=math.atan2(side,rod_x)
 if length<0.8 or length>1.2 or math.abs(angle)>math.pi/6 then return nil end
 local tip={x=entity.position.x+3*vx+length*math.sin(a+angle),y=entity.position.y+3*vy-length*math.cos(a+angle)}
 if not G.same(tip,joint) then return nil end
 return {length=length,angle=angle,entity=entity}
end
function G.side_contact(entity, position)
 if not (entity and entity.valid) then return false end
 local a=entity.orientation*2*math.pi
 local vx,vy=math.sin(a),-math.cos(a)
 local dx,dy=position.x-entity.position.x,position.y-entity.position.y
 local along,side=dx*vx+dy*vy,dx*(-vy)+dy*vx
 return math.abs(along)<=4+C.epsilon and math.abs(side)>=0.5 and math.abs(side)<=3
end
function G.find_end(rail, location)
 for _,d in ipairs{defines.rail_direction.front,defines.rail_direction.back} do
  local ending=rail.get_rail_end(d).location
  if ending.direction==location.direction and G.same(ending.position,location.position) then return d end
 end
end
function G.distance(a,b) return (a.x-b.x)^2+(a.y-b.y)^2 end
function G.paired_signal(rail,signal,force)
 for _,direction in ipairs{defines.rail_direction.front,defines.rail_direction.back} do
  local ending=rail.get_rail_end(direction)
  local outgoing={ending.out_signal_location,ending.alternative_out_signal_location}
  local incoming={ending.in_signal_location,ending.alternative_in_signal_location}
  for _,pair in ipairs{{outgoing,incoming},{incoming,outgoing}} do
   for _,spot in ipairs(pair[1]) do
    if signal.direction==spot.direction and G.same(signal.position,spot.position) then
     for _,opposite in ipairs(pair[2]) do
      for _,real in pairs(rail.surface.find_entities_filtered{position=opposite.position,type={"rail-signal","rail-chain-signal"},force=force}) do
       if real.direction==opposite.direction and G.same(real.position,opposite.position) then return true end
      end
     end
     return false
    end
   end
  end
 end
 return false
end
return G
