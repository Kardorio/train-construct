-- Appended to control.lua only in a disposable packaged mod.
local C=require("scripts.constants")
local F=require("scripts.factory")
local G=require("scripts.geometry")
local I=require("scripts.inventory")
local R=require("scripts.registry")
local O=require("scripts.obstacles")
local W=require("scripts.worker")
local function check(value,message) assert(value,"CT_OBSTACLES "..message) end
local function mark(message) log("CT_OBSTACLES "..message) end
local loaded=false
script.on_load(function() loaded=true end)
local mine_handler=script.get_event_handler(defines.events.on_robot_mined_entity)
script.on_event(defines.events.on_robot_mined_entity,function(event)
 local test=storage.ct_obstacles
 if test and test.blocker and test.blocker.valid and event.entity==test.blocker then
  test.robot_mined=(test.robot_mined or 0)+1
  check(event.robot and event.robot.valid,"missing native mining robot")
 end
 if mine_handler then mine_handler(event) end
end)
local revive=I.revive
I.revive=function(d,ghost)
 -- Observe the real payment boundary, including attempts later refunded.
 check(O.can_place(d,ghost),"payment attempted while obstructed")
 return revive(d,ghost)
end
local function rail_total(d)
 return I.stock(d).get_item_count("rail")+I.cargo(d).get_item_count("rail")+d.recovery.get_item_count("rail")
end
local function health(d,test)
 for index,key in ipairs{"head","wagon","rear"} do
  check(d[key].valid and d[key].health==test.health[index],"rolling stock damaged: "..key)
 end
end
local function fixture(index)
 local s=game.create_surface("ct-obstacles-"..index,{width=256,height=128,autoplace_controls={}})
 s.request_to_generate_chunks({0,0},4);s.force_generate_chunk_requests()
 for _,e in pairs(s.find_entities()) do e.destroy() end
 local tiles={}
 for x=-110,110 do for y=-45,45 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
 s.set_tiles(tiles)
 local entity=assert(s.create_entity{name=C.module,position={0,0},direction=defines.direction.east,force="player"})
 local d,reason=F.create(entity)
 check(d and F.valid(d) and F.at_home(d),"real module failed: "..tostring(reason))
 check(#d.head.train.carriages==3,"module does not have native three-car train")
 local anchor
 for x=16,60,2 do
  anchor=assert(s.create_entity{name="straight-rail",position={d.position.x+x,d.position.y},direction=defines.direction.east,force="player",raise_built=true})
 end
 local direction
 for _,value in ipairs{defines.rail_direction.front,defines.rail_direction.back} do
  if anchor.get_rail_end(value).location.direction==defines.direction.east then direction=value end
 end
 check(direction~=nil,"missing east rail end")
 for name in pairs(d.targets) do d.targets[name]=0 end
 d.fuel_target=0
 check(I.cargo(d).insert{name="rail",count=100}==100,"cargo fixture rejected")
 for _,loco in ipairs{d.head,d.rear} do loco.get_fuel_inventory().insert{name="coal",count=50} end
 R.policy(d,true)
 return d,s,anchor,direction
end
local function ghost(d,anchor,direction,curve)
 for _,ext in ipairs(anchor.get_rail_end(direction).get_rail_extensions("rail")) do
  if (curve and ext.name=="curved-rail-a") or (not curve and ext.name=="straight-rail") then
   local g=assert(anchor.surface.create_entity{name="entity-ghost",inner_name=ext.name,position=ext.position,direction=ext.direction,force="player"})
   R.register(g);R.from_rail(anchor)
   check(storage.ct.frontiers[g.unit_number],"ghost is not a real frontier")
   check(O.can_place(d,g),"empty fixture ghost cannot be placed")
   return g
  end
 end
 error("CT_OBSTACLES requested native rail extension not found")
end
local function blocked_position(d,g,name,alternative)
 -- Curves have an empty center: find a genuine collision on their footprint.
 for radius=0,12 do for dx=-radius,radius do for dy=-radius,radius do
  local p={x=g.position.x+dx,y=g.position.y+dy}
  local e=g.surface.create_entity{name=name,position=p,force=name=="wooden-chest" and "player" or "neutral",preserve_ghosts_and_corpses=true}
  if e then
   local blocked=not g.surface.can_place_entity{name=g.ghost_name,position=g.position,direction=g.direction,
    force=game.forces[d.force_index],build_check_type=defines.build_check_type.ghost_revive}
   if blocked and (not alternative or O.can_place(d,alternative)) then return e end
   e.destroy()
  end
 end end end
 error("CT_OBSTACLES no native collision for "..name)
end
local low_fuel=I.low_fuel
I.low_fuel=function(d)
 local test=storage.ct_obstacles
 if test and test.id==d.id and test.payment and test.phase=="approach" then
  -- Inject at the actual build entry, after the per-tick motion guard but
  -- before the independent payment guard. Fuel behavior remains native.
  local joint=test.anchor.get_rail_end(test.direction).location.position
  check(G.rail_contact(d.head,joint) or G.rail_contact(d.rear,joint),"payment fixture has no native contact")
  test.blocker=blocked_position(d,test.ghost,"tree-01");test.blocker_health=test.blocker.health
  test.phase="blocked";test.start=game.tick
  test.head={x=d.head.position.x,y=d.head.position.y};test.rear={x=d.rear.position.x,y=d.rear.position.y}
  mark("obstacle inserted at native payment boundary")
 end
 return low_fuel(d)
end
local cases={}
local function add(kind,name,marked,curve)
 if obstacles_case=="all" or obstacles_case==kind then cases[#cases+1]={kind=kind,name=name,marked=marked,curve=curve} end
end
-- 012-AC1/AC3: marked entities remain physical obstacles, including curves.
for _,curve in ipairs{false,true} do
 for _,name in ipairs{"tree-01","big-rock","huge-rock","wooden-chest"} do
  for _,marked in ipairs{false,true} do add("static",name,marked,curve) end
 end
end
for _,kind in ipairs{"dynamic","payment","fork","neighbor","guards"} do add(kind,"tree-01",false,false) end
local function begin(index)
 local case=cases[index]
 if not case then
  storage.ct_obstacles.done=true
  helpers.write_file("ct-obstacles-success.txt","success",false)
  mark("ALL SUCCESS")
  return
 end
 local d,s,anchor,direction=fixture(index)
 local g=ghost(d,anchor,direction,case.curve or case.kind=="fork")
 local test={index=index,id=d.id,surface=s,ghost=g,anchor=anchor,direction=direction,
  name=g.ghost_name,position={x=g.position.x,y=g.position.y},heading=g.direction,
  cost=g.ghost_prototype.items_to_place_this[1].count,start=game.tick,phase="approach",payment=case.kind=="payment",
  health={d.head.health,d.wagon.health,d.rear.health},head={x=d.head.position.x,y=d.head.position.y},
  rear={x=d.rear.position.x,y=d.rear.position.y}}
 storage.ct_obstacles=test
 if case.kind=="fork" then
  test.alternative=ghost(d,anchor,direction,false)
  test.alt_position={x=test.alternative.position.x,y=test.alternative.position.y}
  test.alt_name=test.alternative.ghost_name;test.alt_heading=test.alternative.direction
  test.alt_cost=test.alternative.ghost_prototype.items_to_place_this[1].count
 end
 if case.kind=="static" or case.kind=="fork" then
  test.blocker=blocked_position(d,g,case.name,test.alternative);test.blocker_health=test.blocker.health
  if case.marked then check(test.blocker.order_deconstruction(game.forces.player),"deconstruction mark rejected") end
  test.phase="blocked"
 elseif case.kind=="neighbor" then
  test.neighbor=assert(s.create_entity{name="tree-01",position={g.position.x,g.position.y+8}})
  test.neighbor_health=test.neighbor.health
  check(O.can_place(d,g),"neighbor outside footprint blocked placement")
 end
 if case.kind=="fork" then
  test.phase="finish"
  check(O.can_place(d,test.alternative),"fork obstacle overlaps alternative")
 end
 W.start(d)
 mark("START "..index.." "..case.kind.." "..case.name.." marked="..tostring(case.marked).." curve="..tostring(case.curve))
end
local function robot(test)
 local s=test.surface
 local port=assert(s.create_entity{name="roboport",position={test.position.x-10,20},force="player"})
 assert(s.create_entity{name="storage-chest",position={test.position.x-5,20},force="player"})
 -- Giant rocks spill many native item entities. Enough robots must also
 -- collect those drops before ghost_revive considers the footprint clear.
 check(port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=50}==50,"robot insertion failed")
 port.energy=100000000
 test.port=port
 check(test.blocker.to_be_deconstructed() or test.blocker.order_deconstruction(game.forces.player),"robot deconstruction request failed")
 test.phase="robot";test.cleaned_at=nil
end
local function finish(test,d)
 health(d,test)
 check((d.built or 0)==1,"unexpected number of paid rails")
 local alternative=cases[test.index].kind=="fork"
 local name=alternative and test.alt_name or test.name
 local position=alternative and test.alt_position or test.position
 local real=test.surface.find_entity(name,position)
 check(real and real.valid and real.direction==(alternative and test.alt_heading or test.heading),"missing real rail at exact target")
 check(real.force.index==d.force_index,"built rail has wrong owner")
 check(rail_total(d)==100-(alternative and test.alt_cost or test.cost),"rail stocks do not match exact native cost")
 if test.neighbor then check(test.neighbor.valid and test.neighbor.health==test.neighbor_health,"neighbor destroyed or damaged") end
 if alternative then check(test.blocker.valid and test.blocker.health==test.blocker_health and test.ghost.valid,"fork damaged blocked branch") end
 mark("SUCCESS "..test.index.." "..cases[test.index].kind.." real rail + exact stock + health")
 W.pause(d)
 game.delete_surface(test.surface)
 begin(test.index+1)
end
-- 012-AC2: exercise guards with native rolling stock and a real character.
local function guards(test,d)
 local t=d.head.train
 storage.ct.mutating=true;t.manual_mode=true;t.speed=.05;storage.ct.mutating=false
 d.state="travelling";d.arrival="build";d.anchor=test.anchor;d.direction=test.direction;d.task=test.ghost.unit_number
 d.enabled=true;d.auto_controlled=true
 W.motion(d)
 check(t.manual_mode and t.speed==.05 and not d.enabled,"manual motion was forcibly stopped or restarted")
 storage.ct.mutating=true;t.speed=0;storage.ct.mutating=false
 local player=game.get_player(1) or game.create_player{name="ct-obstacles-passenger"}
 player.teleport({0,25},test.surface)
 if not player.character then
  player.set_controller{type=defines.controllers.god}
  player.create_character()
 end
 check(player.character,"passenger character missing")
 check(player.teleport({0,25},test.surface),"passenger teleport failed")
 d.head.set_driver(player.character)
 check(d.head.get_driver()==player.character,"native passenger could not enter locomotive")
 storage.ct.mutating=true;t.manual_mode=false;t.speed=.05;storage.ct.mutating=false
 d.enabled=true;d.auto_controlled=true;d.state="travelling";d.arrival="build"
 W.motion(d)
 check(t.speed==.05 and not d.enabled,"occupied train was forcibly stopped or restarted")
 d.head.set_driver(nil)
 player.teleport({0,25},game.surfaces[1])
 storage.ct.mutating=true;t.speed=0;storage.ct.mutating=false
 W.start(d)
 test.phase="finish"
 mark("native manual/passenger guards SUCCESS")
end
script.on_event(defines.events.on_tick,function()
 if obstacles_server then game.speed=20 end
 if not storage.ct_obstacles then begin(1) end
 local test=storage.ct_obstacles
 if test.done then return end
 local d=assert(storage.ct.depots[test.id])
 local case=cases[test.index]
 if test.phase=="finish" and d.state=="obstacle" and game.tick-test.start>2000 and not test.diagnosed then
  test.diagnosed=true
  local entities={}
  for _,e in pairs(test.surface.find_entities_filtered{area={{test.position.x-10,test.position.y-10},{test.position.x+10,test.position.y+10}}}) do
   entities[e.name]=(entities[e.name] or 0)+1
  end
  mark("DIAGNOSTIC "..helpers.table_to_json{entities=entities,can_place=O.can_place(d,test.ghost),state=d.state})
 end
 check(game.tick-test.start<6500,"timeout "..case.kind.." phase="..test.phase.." state="..d.state)
 health(d,test)
 if test.port then test.port.energy=100000000 end
 if loaded then
  loaded=false
  if test.saved then
   check(test.phase=="blocked" and test.blocker.valid and test.ghost.valid and d.enabled,"blocked save lost mission")
   mark("RELOADED blocked")
  end
 end
 if case.kind=="guards" and test.phase=="approach" then guards(test,d) end
 -- 012-AC2/AC3: introduce the obstacle well before the construction joint.
 if case.kind=="dynamic" and test.phase=="approach" and d.head.train.speed~=0 then
  local joint=test.anchor.get_rail_end(test.direction).location.position
  check(d.auto_controlled and math.min(G.distance(d.head.position,joint),G.distance(d.rear.position,joint))>20,
   "dynamic fixture did not leave a safe approach interval")
  test.blocker=blocked_position(d,test.ghost,case.name);test.blocker_health=test.blocker.health
  W.motion(d)
  check(d.head.train.speed==0 and d.head.train.manual_mode and d.state=="obstacle" and d.enabled,
   "dynamic stop was not immediate")
  check(rail_total(d)==100 and test.ghost.valid,"dynamic obstruction consumed rail")
  test.phase="blocked";test.start=game.tick
  test.head={x=d.head.position.x,y=d.head.position.y};test.rear={x=d.rear.position.x,y=d.rear.position.y}
 end
 -- 012-AC1/AC3: monitor every tick, across a full retry interval.
 if test.phase=="blocked" then
  check(G.same(d.head.position,test.head) and G.same(d.rear.position,test.rear),"blocked approach moved")
  check(test.blocker.valid and test.blocker.health==test.blocker_health,"train mined or damaged obstacle")
  check(test.ghost.valid and rail_total(d)==100 and (d.built or 0)==0,"blocked rail stock changed")
  check(d.enabled,"safe stop disabled automatic retry")
  if game.tick-test.start>=330 then
   check(d.state=="obstacle" and d.head.train.speed==0 and d.head.train.manual_mode,"missing obstacle wait state")
   -- 012-AC4/AC5: only the native robot removes the obstacle.
   if obstacles_server and not test.saved then
    test.saved=true;game.auto_save("ct-obstacles-blocked")
    mark("SAVE blocked")
   elseif not obstacles_server or game.tick-test.start>=390 then robot(test) end
  end
 elseif test.phase=="robot" then
  if test.blocker.valid then
   check(test.blocker.health==test.blocker_health and rail_total(d)==100,"train altered obstacle while robots work")
  else
   check(test.robot_mined==1,"obstacle vanished without native robot mining event")
   if not test.cleaned_at then test.cleaned_at=game.tick;mark("native robot cleared obstacle") end
   test.phase="finish"
  end
 end
 if case.kind=="fork" then
  if not test.alternative.valid then finish(test,d) end
 elseif not test.ghost.valid then
  check(test.phase~="blocked","blocked ghost disappeared")
  finish(test,d)
 end
end)
