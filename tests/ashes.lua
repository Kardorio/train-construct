-- Appended only to the isolated beta package by ashes.py.
local C=require("scripts.constants")
local G=require("scripts.geometry")
local I=require("scripts.inventory")
local F=require("scripts.factory")
local W=require("scripts.worker")
local heading=defines.direction.east
local frame=assert(G.frame(heading))
local generic="used-up-uranium-fuel-cell"
local function check(value,message) assert(value,"CT_ASHES "..message) end
local function mark(message) log("CT_ASHES "..message) end
local function result(loco)
 local inventory=loco.burner.burnt_result_inventory
 check(inventory and inventory.valid and #inventory>0,"missing native burner result inventory")
 check(inventory==loco.get_burnt_result_inventory(),"burner/entity result inventories differ")
 return inventory
end
local function count(inventory,name,quality)
 return inventory.get_item_count{name=name,quality=quality or "normal"}
end
local function put(inventory,name,n,quality)
 check(inventory.insert{name=name,count=n,quality=quality or "normal"}==n,"native insertion rejected "..name)
end
local function clear(d)
 I.stock(d).clear();result(d.head).clear();result(d.rear).clear()
end
local function fill(stock)
 stock.clear()
 for index=1,#stock do stock[index].set_stack{name="iron-plate",count=prototypes.item["iron-plate"].stack_size} end
 check(not stock.can_insert{name=generic,count=1},"stock not actually full")
end
local function snapshot(loco)
 return helpers.table_to_json{fuel=loco.get_fuel_inventory().get_contents(),
  burning=loco.burner.currently_burning and loco.burner.currently_burning.name,
  remaining=loco.burner.remaining_burning_fuel}
end
local function parallel_trial(d)
 local surface=d.entity.surface
 local rails={}
 for along=-14,14,2 do
  rails[#rails+1]=assert(surface.create_entity{name="straight-rail",position=G.offset(d.position,frame,along,8),direction=heading,force="player"})
 end
 local copy={}
 for key,value in pairs(d) do copy[key]=value end
 for _,entry in ipairs{{"head",C.locomotive,7,heading},{"wagon",C.wagon,0,heading},{"rear",C.locomotive,-7,(heading+8)%16}} do
  copy[entry[1]]=assert(surface.create_entity{name=entry[2],position=G.offset(d.position,frame,entry[3],8),direction=entry[4],force="player"})
 end
 copy.enabled=false;copy.state="paused"
 copy.head.train.manual_mode=true
 check(F.valid(copy) and copy.head.train.speed==0 and #copy.head.train.passengers==0,"parallel fixture is not a real stationary three-car train")
 check(F.at_home(d) and not F.at_home(copy),"parallel track mistaken for real dock")
 put(result(copy.head),generic,2,"rare");put(result(copy.rear),generic,3,"uncommon")
 W.tick(copy)
 check(count(result(copy.head),generic,"rare")==2 and count(result(copy.rear),generic,"uncommon")==3 and I.stock(d).is_empty(),
  "stationary parallel train transferred residue into real depot stock")
 for _,field in ipairs{"head","wagon","rear"} do copy[field].destroy() end
 for _,rail in ipairs(rails) do rail.destroy() end
 mark("real stationary parallel train is outside dock and cannot unload")
end
local function synchronous(d)
 local stock=I.stock(d)
 check(type(I.unload_burnt)=="function","missing I.unload_burnt implementation")
 for name in pairs(d.targets) do d.targets[name]=0 end
 d.fuel_target=0
 check(I.unload_burnt(d)==true and I.ready(d)==true,"empty-residue readiness changed")
 if not script.active_mods.pycoalprocessing then
  mark("vanilla empty-residue compatibility")
  return false
 end
 check(prototypes.item.coal.burnt_result and prototypes.item.coal.burnt_result.name=="ash","Py coal must produce ash")
 if not prototypes.item[generic] then generic="empty-fuel-canister" end
 check(prototypes.item[generic],"generic residue prototype missing")
 local head,rear=result(d.head),result(d.rear)
 put(d.head.get_fuel_inventory(),"coal",10);put(d.rear.get_fuel_inventory(),"coal",10)
 local before_head,before_rear=snapshot(d.head),snapshot(d.rear)
 put(head,"ash",7,"rare");put(rear,generic,11,"uncommon")
 check(I.unload_burnt(d)==true,"two-locomotive unload did not finish")
 check(head.is_empty() and rear.is_empty() and count(stock,"ash","rare")==7 and count(stock,generic,"uncommon")==11,
  "two-locomotive transfer lost quantities or qualities")
 check(snapshot(d.head)==before_head and snapshot(d.rear)==before_rear,"unload modified fuel or burning energy")
 mark("two locomotives, mixed qualities, generic residue, fuel preserved")

 clear(d);fill(stock)
 put(head,generic,9);put(rear,generic,8)
 check(I.unload_burnt(d)==false,"full stock reported successful unload")
 check(count(head,generic)==9 and count(rear,generic)==8 and count(stock,generic)==0,"full stock lost residue")
 local ready,message=I.ready(d)
 check(ready==false and message and message[1]=="ct.burnt-full","readiness lacks burnt-full message")
 -- An existing stack with exactly five spaces forces a genuinely partial transfer.
 local size=prototypes.item[generic].stack_size
 stock[1].set_stack{name=generic,count=size-5}
 check(I.unload_burnt(d)==false,"partial unload reported completion")
 check(count(stock,generic)==size and count(head,generic)+count(rear,generic)==12,"partial unload did not conserve exact surplus")
 check(count(head,generic)==4 and count(rear,generic)==8,"partial unload changed the wrong locomotive quantities")
 mark("full and partial stock conserve exact surplus; ready blocks with ct.burnt-full")

 -- One free slot is sufficient for the remaining 12, and W.tick must retry by itself.
 d.enabled=true;d.state="idle";d.auto_controlled=false
 W.tick(d)
 check(d.state=="loading" and not d.auto_controlled,"idle depot did not block departure")
 stock[2].clear()
 W.tick(d)
 check(head.is_empty() and rear.is_empty() and count(stock,generic)==size+12,"worker did not automatically resume unload")
 check(I.ready(d)==true and d.state~="loading","worker did not resume after one slot became free")
 mark("idle departure blocked; one freed slot resumes worker automatically")

 clear(d);d.enabled=false;d.state="paused"
 put(head,generic,3,"rare");put(rear,generic,4,"uncommon")
 W.tick(d)
 check(not d.enabled and d.state=="paused" and head.is_empty() and rear.is_empty(),"paused depot did not unload")
 check(count(stock,generic,"rare")==3 and count(stock,generic,"uncommon")==4,"paused unload lost quality")
 mark("paused depot unloads without passengers")

 -- I.load must use the slot it frees while loading cargo, within the same call.
 clear(d);fill(stock);stock[1].set_stack{name="rail",count=1}
 I.cargo(d).clear();d.targets.rail=1
 put(head,generic,5)
 I.load(d)
 check(count(I.cargo(d),"rail")==1 and head.is_empty() and count(stock,generic)==5,"I.load did not reuse freed stock space")
 d.targets.rail=0;clear(d)
 parallel_trial(d)
 return true
end
local function setup()
 local surface=game.surfaces[1]
 surface.request_to_generate_chunks({0,0},6);surface.force_generate_chunk_requests()
 for _,entity in pairs(surface.find_entities_filtered{area={{-180,-100},{180,100}}}) do entity.destroy() end
 local tiles={}
 for x=-170,170 do for y=-70,70 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
 surface.set_tiles(tiles)
 local module=assert(surface.create_entity{name=C.module,position={0,0},direction=heading,force="player"})
 local d,reason=F.create(module)
 check(d and F.valid(d),"F.create module failed: "..tostring(reason))
 check(F.at_home(d) and #d.head.train.carriages==3 and d.head.orientation==heading/16,"real oriented module/train not docked")
 check(#d.head.train.passengers==0,"suite requires no passengers")
 local py=synchronous(d)
 if not py then return {done=true} end
 for along=-150,150,2 do
  local position=G.offset(d.position,frame,along)
  if not surface.find_entities_filtered{type="straight-rail",position=position}[1] then
   assert(surface.create_entity{name="straight-rail",position=position,direction=heading,force="player"})
  end
 end
 local target=assert(surface.find_entity("straight-rail",G.offset(d.position,frame,100)))
 local direction
 for _,candidate in ipairs{defines.rail_direction.front,defines.rail_direction.back} do
  if target.get_rail_end(candidate).location.direction==heading then direction=candidate end
 end
 check(direction~=nil,"outward rail direction missing")
 d.enabled=false;d.state="paused"
 storage.ct.mutating=true
 d.head.train.schedule={current=1,records={{rail=target,rail_direction=direction,wait_conditions={{type="time",compare_type="and",ticks=100000}}}}}
 d.head.train.manual_mode=false
 storage.ct.mutating=false
 return {id=d.id,phase="away",start=game.tick}
end
script.on_event(defines.events.on_tick,function()
 if storage.ct_ashes_done then return end
 if not game.get_player(1) then return end
 if not storage.ct_ashes then storage.ct_ashes=setup() end
 local test=storage.ct_ashes
 if test.done then
  storage.ct_ashes_done=true
  helpers.write_file("ct-ashes-result.txt","success",false)
  mark("SUCCESS")
  return
 end
 local d=assert(storage.ct.depots[test.id])
 local stock=I.stock(d)
 check(game.tick-test.start<5000,"native movement/combustion timed out in "..test.phase)
 if test.phase=="away" then
  if d.head.train.speed~=0 then
   if not test.moving then
    result(d.head).clear();result(d.rear).clear()
    put(result(d.head),"ash",2);put(result(d.rear),"ash",3)
    check(G.distance(d.wagon.position,d.position)<3,"movement trial missed the docking area")
   end
   local head_before=helpers.table_to_json(result(d.head).get_contents())
   local rear_before=helpers.table_to_json(result(d.rear).get_contents())
   W.tick(d)
   check(helpers.table_to_json(result(d.head).get_contents())==head_before and
    helpers.table_to_json(result(d.rear).get_contents())==rear_before and stock.is_empty(),
    "moving worker transferred residue")
   test.moving=true
  end
  if test.moving and d.head.train.state==defines.train_state.wait_station then
   check(not F.at_home(d),"distance trial remained at depot")
   W.tick(d)
   check(count(result(d.head),"ash")>=2 and count(result(d.rear),"ash")>=3 and stock.is_empty(),
    "stationary distant worker transferred residue")
   mark("native moving and stationary distant trains do not transfer")
   result(d.head).clear();result(d.rear).clear()
   -- No injected ash or artificial burner energy: the return journey consumes Py coal.
   test.fuel_before=count(d.head.get_fuel_inventory(),"coal")+count(d.rear.get_fuel_inventory(),"coal")
   W.home(d,"home")
   check(d.state=="travelling" and not d.head.train.manual_mode,"native return path missing")
   test.phase="burning"
  end
 elseif test.phase=="burning" then
  local ashes=count(result(d.head),"ash")+count(result(d.rear),"ash")+count(stock,"ash")
  if ashes>0 then
   check(count(d.head.get_fuel_inventory(),"coal")+count(d.rear.get_fuel_inventory(),"coal")<test.fuel_before,
    "ash appeared without native coal consumption")
   test.produced=ashes
  end
  if F.at_home(d) and d.head.train.speed==0 then
   W.tick(d)
   check(test.produced and test.produced>0,"return journey produced no native Py ash")
   check(result(d.head).is_empty() and result(d.rear).is_empty() and count(stock,"ash")==test.produced,
    "native combustion ash not unloaded exactly at home")
   check((d.head.burner.currently_burning and d.head.burner.remaining_burning_fuel>0) or
    (d.rear.burner.currently_burning and d.rear.burner.remaining_burning_fuel>0),"no native burning energy left to verify")
   local head_before,rear_before=snapshot(d.head),snapshot(d.rear)
   put(result(d.head),generic,1,"rare")
   check(I.unload_burnt(d)==true and count(stock,generic,"rare")==1,"post-combustion generic transfer failed")
   check(snapshot(d.head)==head_before and snapshot(d.rear)==rear_before,"unload changed native current fuel or burning energy")
   mark("native Py coal combustion produced and unloaded "..test.produced.." ash")
   test.done=true
  end
 end
end)
