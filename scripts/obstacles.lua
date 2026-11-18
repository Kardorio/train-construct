local Obstacles={}
function Obstacles.can_place(depot,ghost)
 if not (ghost and ghost.valid and ghost.type=="entity-ghost") then return false end
 return ghost.surface.can_place_entity{name=ghost.ghost_name,position=ghost.position,direction=ghost.direction,
  force=game.forces[depot.force_index],build_check_type=defines.build_check_type.ghost_revive}
end
return Obstacles
