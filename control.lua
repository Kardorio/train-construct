local Runtime=require("scripts.runtime")
script.on_event(defines.events.on_player_setup_blueprint,Runtime.blueprint)
script.on_event(defines.events.on_entity_settings_pasted,Runtime.settings_pasted)
script.on_init(Runtime.initialize)
script.on_configuration_changed(Runtime.initialize)
script.on_nth_tick(10,Runtime.tick)
script.on_nth_tick(1,Runtime.motion)
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,
 defines.events.script_raised_built,defines.events.script_raised_revive,defines.events.on_entity_cloned},Runtime.on_built)
script.on_event({defines.events.on_player_mined_entity,defines.events.on_robot_mined_entity,
 defines.events.on_entity_died,defines.events.script_raised_destroy},Runtime.on_removed)
script.on_event(defines.events.on_train_schedule_changed,Runtime.schedule_changed)
script.on_event(defines.events.on_train_created,Runtime.train_changed)
script.on_event(defines.events.on_gui_opened,Runtime.gui_opened)
script.on_event({defines.events.on_gui_click,defines.events.on_gui_checked_state_changed,
 defines.events.on_gui_text_changed},Runtime.gui.event)
script.on_event(defines.events.on_gui_closed,function(e)
 local player=game.get_player(e.player_index)
 if player then Runtime.gui.close(player) end
end)
script.on_event({defines.events.on_pre_surface_deleted,defines.events.on_pre_surface_cleared},Runtime.surface_removed)
script.on_event(defines.events.on_object_destroyed,Runtime.object_destroyed)
script.on_event({defines.events.on_player_rotated_entity,defines.events.on_player_flipped_entity,
 defines.events.on_blueprint_settings_pasted,defines.events.on_pre_ghost_deconstructed,
 defines.events.on_pre_ghost_upgraded},Runtime.ghost_changed)
script.on_event(defines.events.on_forces_merging,Runtime.forces_merging)
script.on_event(defines.events.on_forces_merged,Runtime.forces_merged)
