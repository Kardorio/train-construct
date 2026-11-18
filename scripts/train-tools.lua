-- Purely visual: no inventory, placement or train commands belong here.
local G=require("scripts.geometry")
local Tools={duration=16}
local tau=2*math.pi
local function allowed(d,entity)
 if not (d.enabled and d.auto_controlled and not d.pending_removal and not d.retired and
  d.state~="damaged" and d.entity and d.entity.valid and entity and entity.valid) then return false end
 local train=entity.train
 if not (train and train.valid and not train.manual_mode and #train.passengers==0) then return false end
 for _,field in ipairs{"head","wagon","rear"} do
  local part=d[field]
  if not (part and part.valid and part.train==train) then return false end
 end
 return entity==d.head or entity==d.rear
end
function Tools.clear(d)
 local tool=d.train_tools
 if not tool then return end
 for _,object in pairs(tool.objects or {}) do if object.valid then object.destroy() end end
 d.train_tools=nil
end
function Tools.pulse(d,contact)
 if not (contact and allowed(d,contact.entity)) then return end
 if contact.length<0.8 or contact.length>1.2 or math.abs(contact.angle)>math.pi/6 then return end
 local tool=d.train_tools
 if tool and tool.entity~=contact.entity then Tools.clear(d);tool=nil end
 tool=tool or {objects={}}
 tool.entity=contact.entity;tool.started=game.tick
 tool.length=contact.length;tool.angle=contact.angle
 local entity=contact.entity
 local angle=entity.orientation*tau
 tool.joint={x=entity.position.x+3*math.sin(angle)+contact.length*math.sin(angle+contact.angle),
  y=entity.position.y-3*math.cos(angle)-contact.length*math.cos(angle+contact.angle)}
 tool.retract_started=nil;tool.retract_reach=nil;tool.reach=0;tool.closed=false
 d.train_tools=tool
 -- Refresh only on paid work, never each frame.
 for _,object in pairs(tool.objects) do if object.valid then object.time_to_live=Tools.duration+2 end end
end
local function target(entity,x,y)
 return {entity=entity,offset={x=x,y=y}}
end
function Tools.update(d)
 local tool=d.train_tools
 if not tool then return end
 local age=game.tick-tool.started
 if age<0 or age>=Tools.duration or not allowed(d,tool.entity) then Tools.clear(d);return end
 -- Invalid references are discarded, rather than spawning replacements every tick.
 for _,object in pairs(tool.objects) do if not object.valid then Tools.clear(d);return end end
 local entity=tool.entity
 local angle=entity.orientation*tau
 local contact=not tool.retract_started and age<6 and G.rail_contact(entity,tool.joint)
 local reach
 if contact then
  tool.length=contact.length;tool.angle=contact.angle
  reach=math.min(age/2,1)
  reach=reach*reach*(3-2*reach)
  tool.closed=age>=2
 else
  -- The old joint is no longer a work target. Fold from the last valid pose
  -- in the locomotive's frame, without reaching towards a point behind it.
  if not tool.retract_started then
   tool.retract_started=game.tick;tool.retract_reach=tool.reach
  end
  local elapsed=game.tick-tool.retract_started
  if elapsed>=8 then Tools.clear(d);return end
  local remaining=1-elapsed/8
  reach=tool.retract_reach*remaining*remaining*(3-2*remaining)
 end
 tool.reach=reach
 local px,py=3*math.sin(angle),-3*math.cos(angle)
 local tx=px+tool.length*reach*math.sin(angle+tool.angle)
 local ty=py-tool.length*reach*math.cos(angle+tool.angle)
 local from,to=target(entity,px,py),target(entity,tx,ty)
 local objects=tool.objects
 local sprite="ct-train-tool-"..(tool.closed and "closed" or "open")
 if not objects.rod then
  local ttl=Tools.duration-age+2
  objects.rod=rendering.draw_line{surface=entity.surface,from=from,to=to,width=5,
   color={r=.28,g=.31,b=.33},time_to_live=ttl}
  objects.piston=rendering.draw_line{surface=entity.surface,from=from,to=to,width=2,
   color={r=1,g=.72,b=.12},time_to_live=ttl}
  objects.grip=rendering.draw_sprite{surface=entity.surface,target=to,sprite=sprite,
   orientation=(entity.orientation+tool.angle/tau)%1,x_scale=.5,y_scale=.5,
   render_layer="higher-object-above",time_to_live=ttl}
 else
  objects.rod.from=from;objects.rod.to=to
  objects.piston.from=from;objects.piston.to=to
  objects.grip.target=to;objects.grip.sprite=sprite
  objects.grip.orientation=(entity.orientation+tool.angle/tau)%1
 end
end
return Tools
