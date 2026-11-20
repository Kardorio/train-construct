local R=require("scripts.registry")
local F=require("scripts.factory")
local W=require("scripts.worker")
local I=require("scripts.inventory")
local Categories=require("scripts.categories")
local Gui={}
local ROOT="ct_window"
local LAYOUT=5
local ORDER={"rail","rail-signal","rail-chain-signal","train-stop"}
local function window(player) return player.gui.relative[ROOT] or player.gui.screen[ROOT] end
local function section(parent,name,title)
 local panel=parent.add{type="frame",name=name,direction="vertical",style="inside_shallow_frame"}
 panel.style.padding=10;panel.style.top_margin=4
 panel.style.horizontally_stretchable=true
 panel.add{type="label",caption={"ct."..title},style="caption_label"}
 return panel
end
local function wrapping(label,width)
 label.style.single_line=false;label.style.maximal_width=width
 return label
end
function Gui.close(player)
 for _,parent in ipairs{player.gui.relative,player.gui.screen} do if parent[ROOT] then parent[ROOT].destroy() end end
end
function Gui.open(player,depot,anchor)
 Gui.close(player)
 if depot.force_index~=player.force.index then return end
 local frame=player.gui.relative.add{type="frame",name=ROOT,direction="vertical",caption={"ct.title"},tags={depot_id=depot.id,layout_version=LAYOUT},anchor={gui=anchor or defines.relative_gui_type.container_gui,position=defines.relative_gui_position.left}}
 frame.style.width=380
 frame.style.vertically_stretchable=true
 local status=section(frame,"ct_status_section","section-status")
 status.style.height=192
 status.style.vertically_stretchable=false;status.style.vertically_squashable=false
 local state=wrapping(status.add{type="label",name="ct_status",caption=""},330)
 state.style.height=40;state.style.vertical_align="top"
 status.add{type="label",name="ct_built",caption="",style="grey_label"}
 local missing=wrapping(status.add{type="label",name="ct_missing",caption=""},330)
 missing.style.font_color={r=1,g=0.7,b=0.3}
 missing.style.height=60;missing.style.vertical_align="top"
 local construction=section(frame,"ct_build_section","section-build")
 wrapping(construction.add{type="label",caption={"ct.category-hint"},style="grey_label"},330)
 local targets=construction.add{type="table",name="ct_targets",column_count=3}
 targets.style.horizontal_spacing=8;targets.style.vertical_spacing=4
 targets.add{type="label",caption={"ct.build-category"},style="caption_label"}
 targets.add{type="label",caption={"ct.item"},style="caption_label"}
 targets.add{type="label",caption={"ct.load-target"},style="caption_label"}
 for _,name in ipairs(ORDER) do
  targets.add{type="sprite-button",name="ct_category_"..name,sprite="item/"..name,
   style="ct_category_on",auto_toggle=false,toggled=Categories.allowed(depot,name),tags={depot_id=depot.id,category=name}}
  wrapping(targets.add{type="label",caption=prototypes.item[name].localised_name},155)
  local field=targets.add{type="textfield",name="ct_target_"..name,text=tostring(depot.targets[name] or 0),numeric=true,allow_decimal=false,allow_negative=false,tags={depot_id=depot.id,target=name}}
  field.style.width=70
 end
 local options=section(frame,"ct_options_section","section-options")
 options.add{type="checkbox",name="ct_bots",state=depot.bot_enabled,caption={"ct.reserve"},tooltip={"ct.reserve-tooltip"},tags={depot_id=depot.id}}
 local spacer=frame.add{type="empty-widget"}
 spacer.style.vertically_stretchable=true;spacer.style.minimal_height=0
 local controls=section(frame,"ct_controls_section","section-controls")
 local row=controls.add{type="flow",direction="horizontal"}
 row.style.top_margin=4;row.style.horizontal_spacing=6
 for _,action in ipairs{"start","pause","recall"} do
  row.add{type="button",caption={"ct."..action},style=action=="start" and "green_button" or "button",tags={depot_id=depot.id,action=action}}
 end
 Gui.update(player)
end
function Gui.update(player)
 local frame=window(player)
 if not frame then return end
 local depot=storage.ct.depots[frame.tags.depot_id]
 if not depot then Gui.close(player);return end
 local status,construction,options=frame.ct_status_section,frame.ct_build_section,frame.ct_options_section
 if frame.tags.layout_version~=LAYOUT or not (status and status.ct_status and status.ct_built and status.ct_missing and
  construction and construction.ct_targets and options and options.ct_bots and frame.ct_controls_section) then
  local anchor=frame.anchor
  Gui.open(player,depot,anchor and anchor.gui)
  return
 end
 local targets=construction.ct_targets
 for _,name in ipairs(ORDER) do
  local enabled=Categories.allowed(depot,name)
  local button=targets["ct_category_"..name]
  button.style=enabled and "ct_category_on" or "ct_category_off"
  button.toggled=enabled
  button.tooltip={enabled and "ct.category-enabled" or "ct.category-disabled",prototypes.item[name].localised_name}
  targets["ct_target_"..name].enabled=enabled
 end
 status.ct_status.caption={"ct.state",{"ct-state."..depot.state}}
 status.ct_built.caption={"ct.built",depot.built or 0}
 options.ct_bots.state=depot.bot_enabled
 local notice=depot.missing and {"ct.missing",prototypes.item[depot.missing.name].localised_name,depot.missing.quality,depot.missing.count} or ""
 if depot.state=="loading" then
  local _,reason=I.ready(depot)
  notice=reason or ""
 end
 if depot.blocked_return then notice={"ct.return-blocked"} end
 status.ct_missing.caption=notice
 status.ct_missing.visible=true
end
function Gui.event(event)
 local element=event.element
 if not (element and element.valid) then return end
 local player=game.get_player(event.player_index)
 if not player then return end
 local depot=storage.ct.depots[element.tags.depot_id]
 if not (depot and depot.force_index==player.force.index) then return end
 if element.tags.category then
  if event.button and event.button~=defines.mouse_button_type.left then return end
  local enabled
  if element.type=="checkbox" then enabled=element.state
  else enabled=not Categories.allowed(depot,element.tags.category) end
  W.set_category(depot,element.tags.category,enabled)
 elseif element.tags.target then
  local count=tonumber(element.text)
  if count and count>=0 and count<=100000 then depot.targets[element.tags.target]=math.floor(count) end
 elseif element.name=="ct_bots" then R.policy(depot,element.state)
 elseif element.tags.action=="start" then W.start(depot)
 elseif element.tags.action=="pause" then W.pause(depot)
 elseif element.tags.action=="recall" then depot.enabled=true;F.release_claims(depot);depot.task=nil;depot.resume_anchor=nil;W.home(depot,"home") end
 Gui.update(player)
end
return Gui
