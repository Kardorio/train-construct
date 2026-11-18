-- Installed before the existing real-mission fixture in an isolated mod copy.
local Tools=require("scripts.train-tools")
local Inventory=require("scripts.inventory")
local Geometry=require("scripts.geometry")
local Constants=require("scripts.constants")
local function state()
 storage.ct_tools_test=storage.ct_tools_test or {heads={},pulses=0,frames=0,closed=0,expired=0,pauses=0}
 return storage.ct_tools_test
end
local revive=Inventory.revive
local latest
Inventory.revive=function(d,ghost)
 local rail=Constants.rail_types[ghost.ghost_name]
 if rail then
  local s=state()
  local joint=d.anchor.get_rail_end(d.direction).location.position
  local contact=assert(Geometry.rail_contact(d.head,joint) or Geometry.rail_contact(d.rear,joint))
  -- Exercise real worker failure branches without consuming anything.
  if not s.materials then s.materials=true;latest=nil;return nil,"materials" end
  if not s.obstacle then s.obstacle=true;latest=nil;return nil,"obstacle" end
  local real,reason=revive(d,ghost)
  latest=real and {entity=real,contact=contact,joint={x=joint.x,y=joint.y},built=d.built,tick=game.tick}
  return real,reason
 end
 return revive(d,ghost)
end
local pulse=Tools.pulse
Tools.pulse=function(d,contact)
 assert(latest and latest.entity.valid and latest.tick==game.tick,"Pulse without successful paid rail")
 assert(latest.contact.entity==contact.entity and latest.built==d.built,"Wrong working head or payment")
 local s=state();s.pulses=s.pulses+1
 s.heads[contact.entity==d.head and "head" or "rear"]=true
 pulse(d,contact)
 assert(d.train_tools and d.train_tools.entity==contact.entity,"Paid rail did not animate")
 assert(Geometry.same(d.train_tools.joint,latest.joint),"Visual target is not the paid rail joint")
 latest=nil
end
local pause=Runtime.worker.pause
Runtime.worker.pause=function(d)
 local active=d.train_tools~=nil
 pause(d)
 assert(not d.train_tools,"Pause kept tool references")
 if active then state().pauses=state().pauses+1 end
end
local update=Tools.update
local loaded=true
local function finish()
 local s=state()
 assert(s.pulses==52 and s.closed>0 and s.expired>0 and s.pauses>0 and s.materials and s.obstacle and s.invalid and s.guards)
 assert(#rendering.get_all_objects(script.mod_name)==0,"Recovery left orphan tools")
 if not s.done then s.done=true;log("CT_TOOLS SUCCESS "..helpers.table_to_json(s)) end
end
local withdraw=Runtime.factory.withdraw
Runtime.factory.withdraw=function(d,...)
 local result=withdraw(d,...)
 if result and storage.ct_test and storage.ct_test.phase=="remote-withdraw" then finish() end
 return result
end
Tools.update=function(d)
 assert(not latest,"Paid rail did not trigger tool pulse")
 local s=state()
 local tool=d.train_tools
 local age=tool and game.tick-tool.started
 local previous_reach=tool and tool.reach
 if loaded and tool then
  loaded=false
  if next(tool.objects) then
   for _,object in pairs(tool.objects) do assert(object.valid,"Reload lost a saved render object") end
   s.reloaded=true;log("CT_TOOLS saved LuaRenderObjects restored")
  end
 end
 update(d)
 if d.train_tools then
  tool=d.train_tools;s.frames=s.frames+1
  local count=0
  for _,object in pairs(tool.objects) do
   count=count+1;assert(object.valid and object.time_to_live>0 and object.time_to_live<=26)
  end
  assert(count==3 and #rendering.get_all_objects(script.mod_name)==3,"Unbounded or orphan rendering")
  local grip=tool.objects.grip
  assert(grip.target.entity==tool.entity,"Grip attached to the wrong locomotive")
  local function point(p) return {x=p.x or p[1],y=p.y or p[2]} end
  local offset=point(grip.target.offset)
  local from=point(tool.objects.rod.from.offset)
  local distance=math.sqrt((offset.x-from.x)^2+(offset.y-from.y)^2)
  assert(distance<=1.200001,"Rod overextended")
  assert(math.abs(tool.angle)<=math.pi/6 and tool.length>=.8 and tool.length<=1.2,"Tool escaped contact limits")
  if tool.retract_started then
   assert(tool.reach<=previous_reach+.000001,"Out-of-range tool extended towards an old joint")
   assert(game.tick-tool.retract_started<8,"Out-of-range retraction did not finish")
  end
  assert(math.abs(math.sqrt(from.x^2+from.y^2)-3)<.000001,"Pivot moved")
  if tool.closed and not tool.retract_started then
   assert(grip.sprite=="ct-train-tool-closed" and math.abs(distance-tool.length)<.000001,"Grip did not close at full reach")
   assert(Geometry.same({x=tool.entity.position.x+offset.x,y=tool.entity.position.y+offset.y},tool.joint),"Working grip drifted away from the real joint")
   s.closed=s.closed+1
  elseif age==0 then assert(grip.sprite=="ct-train-tool-open" and distance<.000001,"Grip did not start retracted") end
  if not s.saved and age==3 then
   s.saved=true;game.auto_save("ct-midmission-tools")
  end
  -- A broken render object must terminate the whole visual, without recreating it.
  if not s.invalid and age==5 then
   s.invalid=true;tool.objects.rod.destroy();update(d)
   assert(not d.train_tools and #rendering.get_all_objects(script.mod_name)==0,"Invalid render references survived")
  elseif s.invalid and s.pauses==0 and age==5 then
   Runtime.worker.pause(d)
   assert(#rendering.get_all_objects(script.mod_name)==0,"Pause left rendering")
   Runtime.worker.start(d)
  elseif s.pauses>0 and not s.guards and age==5 then
   -- Exercise guards against real render objects without changing the mission.
   local objects=tool.objects
   d.auto_controlled=false;update(d);d.auto_controlled=true
   assert(not d.train_tools and #rendering.get_all_objects(script.mod_name)==0,"Automatic-control guard leaked")
   for _,object in pairs(objects) do assert(not object.valid) end
   s.guards=true
  end
 elseif tool and (age>=Tools.duration or tool.retract_started) then
  s.expired=s.expired+1
  assert(#rendering.get_all_objects(script.mod_name)==0,"Expired tool leaked")
 end
 if storage.ct_test and storage.ct_test.done and not s.done then
  finish()
 end
end
