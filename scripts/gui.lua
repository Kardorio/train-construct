local C=require("scripts.constants")
local R=require("scripts.registry")
local F=require("scripts.factory")
local W=require("scripts.worker")
local I=require("scripts.inventory")
local Categories=require("scripts.categories")
local Gui={}
local ROOT="ct_window"
local function window(player) return player.gui.relative[ROOT] or player.gui.screen[ROOT] end
function Gui.close(player)
 for _,parent in ipairs{player.gui.relative,player.gui.screen} do if parent[ROOT] then parent[ROOT].destroy() end end
end
function Gui.open(player,depot,anchor)
 Gui.close(player)
 if depot.force_index~=player.force.index then return end
 local frame=player.gui.relative.add{type="frame",name=ROOT,direction="vertical",caption={"ct.title"},tags={depot_id=depot.id},anchor={gui=anchor or defines.relative_gui_type.container_gui,position=defines.relative_gui_position.left}}
 frame.style.width=340
 frame.add{type="label",name="ct_status",caption=""}
 frame.add{type="label",name="ct_built",caption=""}
 local note=frame.add{type="label",caption={"ct.prototype"}}
 note.style.single_line=false;note.style.maximal_width=310
 frame.add{type="checkbox",name="ct_bots",state=depot.bot_enabled,caption={"ct.reserve"},tags={depot_id=depot.id}}
 frame.add{type="label",name="ct_requests",caption=""}
 local missing=frame.add{type="label",name="ct_missing",caption=""}
 missing.style.single_line=false;missing.style.maximal_width=310
 local categories=frame.add{type="label",caption={"ct.categories"}}
 categories.style.single_line=false;categories.style.maximal_width=310
 local targets=frame.add{type="table",name="ct_targets",column_count=2}
 targets.add{type="label",caption={"ct.build-category"}}
 targets.add{type="label",caption={"ct.load-target"}}
 for _,name in ipairs{"rail","rail-signal","rail-chain-signal","train-stop"} do
  targets.add{type="checkbox",name="ct_category_"..name,state=Categories.allowed(depot,name),caption=prototypes.item[name].localised_name,tags={depot_id=depot.id,category=name}}
  local field=targets.add{type="textfield",name="ct_target_"..name,text=tostring(depot.targets[name] or 0),numeric=true,allow_decimal=false,allow_negative=false,tags={depot_id=depot.id,target=name}}
  field.style.width=80
 end
 for _,actions in ipairs{{"start","pause","recall"},{"withdraw","close"}} do
  local row=frame.add{type="flow",direction="horizontal"}
  for _,action in ipairs(actions) do
   row.add{type="button",caption={"ct."..action},tags={depot_id=depot.id,action=action}}
  end
 end
 Gui.update(player)
end
function Gui.update(player)
 local frame=window(player)
 if not frame then return end
 local depot=storage.ct.depots[frame.tags.depot_id]
 if not depot then Gui.close(player);return end
 if not frame.ct_targets then
  local anchor=frame.anchor
  Gui.open(player,depot,anchor and anchor.gui)
  return
 end
 for name in pairs(C.targets) do
  frame.ct_targets["ct_category_"..name].state=Categories.allowed(depot,name)
  frame.ct_targets["ct_target_"..name].enabled=Categories.allowed(depot,name)
 end
 frame.ct_status.caption={"ct.state",{"ct-state."..depot.state}}
 frame.ct_built.caption={"ct.built",depot.built or 0}
 frame.ct_requests.caption={"ct.requests",storage.ct.policies[depot.force_index..":"..depot.surface_index] or 0}
 frame.ct_missing.caption=depot.missing and {"ct.missing",prototypes.item[depot.missing.name].localised_name,depot.missing.quality,depot.missing.count} or ""
 if depot.state=="loading" then
  local _,reason=I.ready(depot)
  frame.ct_missing.caption=reason or ""
 end
 if depot.blocked_return then frame.ct_missing.caption={"ct.return-blocked"} end
end
function Gui.event(event)
 local element=event.element
 if not (element and element.valid) then return end
 local player=game.get_player(event.player_index)
 local depot=storage.ct.depots[element.tags.depot_id]
 if not (depot and depot.force_index==player.force.index) then return end
 if element.tags.category then W.set_category(depot,element.tags.category,element.state)
 elseif element.tags.target then
  local count=tonumber(element.text)
  if count and count>=0 and count<=100000 then depot.targets[element.tags.target]=math.floor(count) end
 elseif element.name=="ct_bots" then R.policy(depot,element.state)
 elseif element.tags.action=="start" then W.start(depot)
 elseif element.tags.action=="pause" then W.pause(depot)
 elseif element.tags.action=="recall" then depot.enabled=true;F.release_claims(depot);depot.task=nil;depot.resume_anchor=nil;W.home(depot,"home")
 elseif element.tags.action=="withdraw" then F.withdraw(depot,true)
 elseif element.tags.action=="close" then Gui.close(player) end
 Gui.update(player)
end
return Gui
