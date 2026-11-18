-- Reuse the native detailed gripper; no additional bitmap assets.
local inserter=data.raw.inserter.inserter
for _,state in ipairs{"open","closed"} do
 local sprite=table.deepcopy(inserter["hand_"..state.."_picture"])
 sprite.type="sprite"
 sprite.name="ct-train-tool-"..state
 data:extend{sprite}
end
