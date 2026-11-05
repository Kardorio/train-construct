local Circuit = {}

-- Call after the proxy target is bound, at creation and during migration.
-- This flag belongs to the persisted depot record, never to an on_load cache.
function Circuit.initialize(depot)
 if depot.circuit_initialized then return false end
 local entity=depot.entity
 if not (entity and entity.valid) then return false end
 if entity.type~="proxy-container" and entity.type~="container" then return false end
 local control=entity.get_or_create_control_behavior()
 if not control then return false end
 control.read_contents=true
 control.read_empty_slots=false
 depot.circuit_initialized=true
 return true
end

return Circuit
