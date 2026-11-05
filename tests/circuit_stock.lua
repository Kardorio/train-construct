local Circuit=require("scripts.circuit")
local I=require("scripts.inventory")
local G=require("scripts.geometry")
local T={}

local function contents(inventory)
 local result={}
 for _,item in pairs(inventory.get_contents()) do
  result[item.name.."|"..item.quality]=item.count
 end
 return result
end

local function equal(actual,expected,label)
 for key,count in pairs(expected) do assert((actual[key] or 0)==count,label..": "..key) end
 for key,count in pairs(actual) do assert(count==(expected[key] or 0),label..": unexpected "..key) end
end

-- Persist setup's state; keep the fixture idle until check returns true (next_tick).
-- During missions and after reload, use persisted without freezing stock contents.
function T.setup(d)
 assert(not d.enabled,"Circuit fixture must be disabled")
 local entity=d.entity
 assert(entity.valid and d.circuit_initialized,"Factory did not initialize circuit reading")
 assert(entity.get_control_behavior().read_contents,"Initial stock reading is disabled")
 local frame=assert(G.frame(entity.direction))
 local center=d.position
 local pole=assert(entity.surface.create_entity{name="small-electric-pole",
  position=G.offset(center,frame,0,9),force=entity.force})
 for _,id in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green} do
  local source=assert(entity.get_wire_connector(id,true),"Missing visible circuit connector")
  assert(source.connect_to(pole.get_wire_connector(id,true),true),"Native wire could not reach workshop")
 end
 local stock=assert(I.stock(d))
 local expected=contents(stock)
 expected["copper-plate|normal"]=(expected["copper-plate|normal"] or 0)+37
 expected["copper-plate|rare"]=(expected["copper-plate|rare"] or 0)+11
 assert(stock.insert{name="copper-plate",quality="normal",count=37}==37)
 assert(stock.insert{name="copper-plate",quality="rare",count=11}==11)
 -- Deliberately use an item also present in stock: summed train contents fail.
 assert(I.cargo(d).insert{name="copper-plate",quality="normal",count=19}==19)
 for _,loco in ipairs{d.head,d.rear} do
  assert(loco.get_fuel_inventory().insert{name="coal",count=3}==3)
 end
 return {pole=pole,entity=entity,stock=d.stock or entity,
  expected=expected,phase="insert",next_tick=game.tick+2,read_contents=true,
  initialized=d.circuit_initialized}
end

function T.check(d,state)
 assert(d.entity==state.entity and (d.stock or d.entity)==state.stock,"Circuit inventory identity changed")
 assert(d.circuit_initialized==state.initialized and state.initialized,"Circuit initialization flag lost")
 local control=assert(d.entity.get_control_behavior())
 assert(control.read_contents==state.read_contents,"Native reading setting lost")
 assert(not Circuit.initialize(d),"Circuit reading was initialized twice")
 assert(control.read_contents==state.read_contents,"Initialization overwrote native setting")
 equal(contents(assert(I.stock(d))),state.expected,"Persisted stock")
 if game.tick<state.next_tick then return false end
 local network_ids={}
 for _,id in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green} do
  local source=assert(d.entity.get_wire_connector(id,false))
  local target=assert(state.pole.get_wire_connector(id,false))
  assert(source.is_connected_to(target),"Circuit wire lost after reload")
  local network=assert(state.pole.get_circuit_network(id),"Missing real circuit network")
  network_ids[#network_ids+1]=network.network_id
  local actual={}
  for _,entry in pairs(network.signals or {}) do
   local signal=entry.signal
   assert(signal.type==nil or signal.type=="item",
    "Unexpected non-stock circuit signal: "..helpers.table_to_json(entry))
   actual[signal.name.."|"..(signal.quality or "normal")]=entry.count
  end
  equal(actual,state.read_contents and state.expected or {},"Native circuit stock")
 end
 assert(network_ids[1]~=network_ids[2],"Red and green networks were merged")
 if state.phase=="insert" then
  local stock=I.stock(d)
  assert(stock.remove{name="copper-plate",quality="normal",count=13}==13)
  assert(stock.remove{name="copper-plate",quality="rare",count=4}==4)
  state.expected["copper-plate|normal"]=state.expected["copper-plate|normal"]-13
  state.expected["copper-plate|rare"]=state.expected["copper-plate|rare"]-4
  state.phase="remove"
 elseif state.phase=="remove" then
  control.read_contents=false
  state.read_contents=false;state.phase="disabled"
 elseif state.phase=="disabled" then
  state.phase="done"
  return true
 else
  assert(state.phase=="done","Unknown circuit test phase")
  return true
 end
 state.next_tick=game.tick+2
 return false
end

function T.persisted(d,state)
 assert(state.phase=="done","Circuit fixture is not complete")
 assert(d.entity==state.entity and d.entity.valid,"Circuit proxy identity changed")
 assert((d.stock or d.entity)==state.stock and state.stock.valid,"Circuit stock identity changed")
 assert(d.circuit_initialized==state.initialized and state.initialized,"Circuit initialization flag lost")
 assert(state.read_contents==false and d.entity.get_control_behavior().read_contents==false,
  "Native disabled reading setting lost")
 assert(state.pole.valid,"Circuit pole lost")
 local network_ids={}
 for _,id in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green} do
  local source=assert(d.entity.get_wire_connector(id,false))
  local target=assert(state.pole.get_wire_connector(id,false))
  assert(source.is_connected_to(target),"Circuit wire lost after reload")
  local network=assert(state.pole.get_circuit_network(id),"Missing real circuit network")
  local output=assert(d.entity.get_circuit_network(id),"Proxy circuit network lost")
  assert(output.network_id==network.network_id,"Proxy and pole networks differ")
  local signals=network.signals
  assert(not signals or next(signals)==nil,
   "Disabled circuit emitted signals: "..helpers.table_to_json(signals or {}))
  network_ids[#network_ids+1]=network.network_id
 end
 assert(network_ids[1]~=network_ids[2],"Red and green networks were merged")
 return true
end

return T
