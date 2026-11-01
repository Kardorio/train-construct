
local function emit(label,data) log("CT_EDITING "..label.." "..helpers.table_to_json(data)) end
script.on_init(function()
 local s=game.surfaces[1]
 s.request_to_generate_chunks({0,0},2);s.force_generate_chunk_requests()
 for _,entity in pairs(s.find_entities_filtered{area={{-20,-20},{20,20}}}) do if entity.type~="character" then entity.destroy() end end
 local tiles={};for x=-15,15 do for y=-15,15 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;s.set_tiles(tiles)
 local owner=game.forces.player
 local reserved=game.create_force("ct-editing-reserved")
 local shared=s.create_entity{name="entity-ghost",inner_name="straight-rail",position={0,0},direction=defines.direction.north,force=owner}
 local target=s.create_entity{name="entity-ghost",inner_name="straight-rail",position={8,0},direction=defines.direction.north,force=owner}
 assert(shared and target)
 local inv=game.create_inventory(1);inv[1].set_stack{name="blueprint"}
 local function copy(area)
  inv[1].clear_blueprint()
  inv[1].create_blueprint{surface=s,force=owner,area=area,include_entities=true}
  local entities=inv[1].get_blueprint_entities() or {}
  return #entities
 end
 local shared_count=copy{{-2,-2},{4,4}}
 target.tags={probe=42};target.force=reserved
 local reserved_count=copy{{6,-2},{12,4}}
 owner.set_friend(reserved,true);reserved.set_friend(owner,true)
 local friendly_count=copy{{6,-2},{12,4}}
 owner.set_friend(reserved,false);reserved.set_friend(owner,false)
 target.force=owner
 local restored_count=copy{{6,-2},{12,4}}
 assert(shared_count==1 and restored_count==1,"Blueprint control case did not work")
 assert(shared.valid and target.valid and target.tags.probe==42)
 emit("success",{shared=shared_count,reserved=reserved_count,friendly_reserved=friendly_count,restored=restored_count,native_copy_preserved=reserved_count==1,friendly_copy_preserved=friendly_count==1})
 inv.destroy()
end)
