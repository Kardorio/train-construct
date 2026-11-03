-- Shared assertions are also loaded by the upgraded control script.
local L={commit="f14769e3a9a0a7e2c26eeeab08486885a1be45b4"}
local C=require("scripts.constants")
local manifests={
 stock={{name="rail",quality="rare",count=137},{name="rail",quality="normal",count=11},
  {name="rail-signal",quality="rare",count=19},{name="coal",quality="rare",count=23}},
 cargo={{name="rail",quality="rare",count=29},{name="rail-chain-signal",quality="normal",count=5}},
 head_fuel={{name="coal",quality="rare",count=17}},
 rear_fuel={{name="solid-fuel",quality="rare",count=13}},
 recovery={{name="train-stop",quality="rare",count=3}}
}
local function inventories(d)
 return {stock=d.entity.get_inventory(defines.inventory.chest),
  cargo=d.wagon.get_inventory(defines.inventory.cargo_wagon),
  head_fuel=d.head.get_fuel_inventory(),rear_fuel=d.rear.get_fuel_inventory(),recovery=d.recovery}
end
local function slots(inv)
 local result={size=#inv}
 for i=1,#inv do
  local stack=inv[i]
  if stack.valid_for_read then result[tostring(i)]={name=stack.name,quality=stack.quality.name,count=stack.count} end
 end
 return result
end
local function equal(actual,expected,path)
 if type(expected)~="table" then assert(actual==expected,"Legacy mismatch: "..path);return end
 assert(type(actual)=="table","Missing legacy table: "..path)
 for k,v in pairs(expected) do equal(actual[k],v,path.."/"..tostring(k)) end
 for k in pairs(actual) do assert(expected[k]~=nil,"Unexpected legacy value: "..path.."/"..tostring(k)) end
end
function L.snapshot(d)
 local result={id=d.id,train=d.head.train.id,quality=d.quality,entities={},rails={},inventories={}}
 for _,field in ipairs{"entity","head","wagon","rear","stop"} do
  local entity=d[field]
  assert(entity and entity.valid,"Missing legacy entity: "..field)
  result.entities[field]={unit=entity.unit_number,name=entity.name,quality=entity.quality.name,
   position=entity.position,direction=entity.direction,force=entity.force.index,surface=entity.surface.index}
 end
 for _,rail in pairs(d.entity.surface.find_entities_filtered{type="straight-rail"}) do
  result.rails[tostring(rail.unit_number)]={position=rail.position,direction=rail.direction}
 end
 for name,inv in pairs(inventories(d)) do result.inventories[name]=slots(inv) end
 return result
end
function L.check(Runtime)
 local test=assert(storage.ct_legacy,"Missing persisted legacy fixture")
 assert(test.commit==L.commit,"Wrong fixture source")
 local d=assert(storage.ct.depots[test.original.id],"Legacy depot disappeared")
 assert(d.entity.name==C.depot and d.quality=="rare" and d.entity.quality.name=="rare","Legacy building changed")
 assert(d.stock==nil and d.track==nil and d.rails==nil,"Legacy depot converted to an integrated module")
 assert(Runtime.factory.valid(d) and Runtime.factory.at_home(d),"Legacy machine is no longer compatible")
 assert(#Runtime.factory.home_goals(d)==2,"Legacy docking goals lost")
 assert(d.head.train==d.wagon.train and d.head.train==d.rear.train and #d.head.train.carriages==3,"Legacy composition changed")
 assert(d.train_id==test.original.train,"Stored train identity changed")
 assert(not d.enabled and d.state=="paused" and d.head.train.manual_mode,"Paused legacy machine changed state")
 local count=0;for _ in pairs(storage.ct.depots) do count=count+1 end
 assert(count==1,"Unexpected extra depot")
 assert(#d.entity.surface.find_entities_filtered{name=C.locomotive}==2,"Unexpected extra locomotives")
 assert(#d.entity.surface.find_entities_filtered{name=C.wagon}==1,"Unexpected extra wagon")
 assert(#d.entity.surface.find_entities_filtered{name=C.stop}==1,"Unexpected extra stop")
 assert(#d.entity.surface.find_entities_filtered{type="item-entity"}==0,"Migration spilled items")
 for name,inv in pairs(inventories(d)) do
  local expected,actual={},{}
  for _,stack in ipairs(manifests[name]) do expected[stack.name.."|"..stack.quality]=stack.count end
  for i=1,#inv do
   local stack=inv[i]
   if stack.valid_for_read then
    local key=stack.name.."|"..stack.quality.name
    actual[key]=(actual[key] or 0)+stack.count
   end
  end
  equal(actual,expected,"manifest/"..name)
 end
 equal(L.snapshot(d),test.original,"snapshot")
 return d,test
end
function L.install_fixture(Runtime)
 script.on_init(function()
  Runtime.initialize()
  game.speed=10
  local s=game.surfaces[1]
  s.request_to_generate_chunks({0,0},2);s.force_generate_chunk_requests()
  for _,entity in pairs(s.find_entities()) do entity.destroy() end
  local tiles={}
  for x=-24,24 do for y=-30,30 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
  s.set_tiles(tiles)
  for y=-20,20,2 do assert(s.create_entity{name="straight-rail",position={0,y},direction=defines.direction.north,force="player"}) end
  local entity=assert(s.create_entity{name=C.depot,position={6,0},quality="rare",force="player"})
  local d=assert(Runtime.on_built{entity=entity},"Old runtime rejected legacy placement")
  Runtime.worker.pause(d)
  for name,inv in pairs(inventories(d)) do
   assert(inv.is_empty(),"Old runtime prefilled inventory")
   for _,stack in ipairs(manifests[name]) do assert(inv.insert(stack)==stack.count,"Cannot seed "..name) end
  end
  -- Preheated burners avoid consuming an inventory item on the first idle tick.
  for _,loco in ipairs{d.head,d.rear} do
   loco.burner.currently_burning="coal"
   loco.burner.remaining_burning_fuel=prototypes.item.coal.fuel_value
  end
  storage.ct_legacy={commit=L.commit,original=L.snapshot(d),configuration_changes=0}
  L.check(Runtime)
 end)
 script.on_event(defines.events.on_tick,function(event)
  if event.tick%30~=0 then return end
  local _,test=L.check(Runtime)
  if not test.fixture_saved then
   test.fixture_saved=true
   game.auto_save("ct-legacy-fixture")
   log("CT_LEGACY checkpoint fixture "..helpers.table_to_json(test.original))
  else
   helpers.write_file("ct-legacy-fixture.txt","fixture ready\n",false)
  end
 end)
end
return L
