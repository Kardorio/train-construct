local C=require("scripts.constants")
local G=require("scripts.geometry")
local I=require("scripts.inventory")
local R=require("scripts.registry")
local F=require("scripts.factory")
local W={}
local directions={defines.rail_direction.front,defines.rail_direction.back}
local connections={defines.rail_connection_direction.straight,defines.rail_connection_direction.left,defines.rail_connection_direction.right}
local function train(d) return d.head and d.head.valid and d.head.train end
local function guard(callback)
 storage.ct.mutating=true
 local ok,result=pcall(callback)
 storage.ct.mutating=false
 if not ok then error(result) end
 return result
end
local function drive(d,rail,direction,arrival)
 if not (rail and rail.valid and F.valid(d)) then d.state="damaged";return false end
 local t=train(d)
 guard(function()
  t.schedule={current=1,records={{rail=rail,rail_direction=direction,temporary=false,wait_conditions={{type="time",compare_type="and",ticks=100000}}}}}
  t.manual_mode=false
 end)
 d.auto_controlled=true;d.state="travelling";d.arrival=arrival;d.destination=rail;d.command_tick=game.tick
 return true
end
function W.home(d,reason)
 local goals=F.home_goals(d)
 if #goals==0 then d.state="damaged";return false end
 d.return_reason=reason or "home"
 local result=game.train_manager.request_train_path{train=train(d),goals=goals,steps_limit=16384}
 if not result.found_path then
  if (d.return_attempts or 0)>=4 then W.block(d,"no-path","return");return false end
  local candidates={}
  for _,rail in pairs(d.visited) do
   if rail.valid and rail.type=="straight-rail" then
    for _,direction in ipairs(directions) do candidates[#candidates+1]={rail=rail,direction=direction} end
   end
  end
  table.sort(candidates,function(a,b)
   local da,db=G.distance(a.rail.position,d.head.position),G.distance(b.rail.position,d.head.position)
   if da~=db then return da<db end
   if a.rail.unit_number~=b.rail.unit_number then return a.rail.unit_number<b.rail.unit_number end
   return a.direction<b.direction
  end)
  d.return_search={candidates=candidates,cursor=1};d.state="return-search"
  train(d).manual_mode=true;d.auto_controlled=false
  return false
 end
 d.return_attempts=nil;d.blocked_return=nil;d.return_search=nil
 local goal=goals[result.goal_index]
 return drive(d,goal.rail,goal.direction,d.return_reason)
end
function W.search_return(d)
 if train(d).speed~=0 or storage.ct.path_budget<=0 then return end
 local search=d.return_search
 local candidate=search and search.candidates[search.cursor]
 if not candidate then d.return_search=nil;W.block(d,"no-path","return");return end
 search.cursor=search.cursor+1
 if not candidate.rail.valid then return end
 local goals=F.home_goals(d)
 if #goals==0 then d.state="damaged";return end
 storage.ct.path_budget=storage.ct.path_budget-1
 local reverse=game.train_manager.request_train_path{starts={{rail=candidate.rail,direction=1-candidate.direction}},goals=goals,steps_limit=8192}
 if not reverse.found_path then return end
 local first=game.train_manager.request_train_path{train=train(d),goals={candidate},return_path=true,steps_limit=8192}
 if not first.found_path or first.total_length<30 then return end
 d.return_attempts=(d.return_attempts or 0)+1;d.return_search=nil
 drive(d,candidate.rail,candidate.direction,"retreat")
end
function W.pause(d)
 d.enabled=false;d.auto_controlled=false;d.return_search=nil;d.return_attempts=nil;d.blocked_return=nil
 local t=train(d)
 if t then t.manual_mode=true end
 F.release_claims(d)
 d.task=nil;d.resume_anchor=nil;d.state="paused"
end
local blocked_states={contact=true,obstacle=true,["no-path"]=true,placement=true}
function W.block(d,state,message)
 d.blocked_return=message=="return" and d.return_reason or nil
 d.state=state;d.message=message;d.retry_at=game.tick+300
 F.release_claims(d)
 local t=train(d)
 if t and t.speed==0 then t.manual_mode=true;d.auto_controlled=false end
end
function W.start(d)
 if not F.valid(d) then d.state="damaged";return end
 d.enabled=true;d.auto_controlled=false;d.retry_at=nil;d.message=nil;d.return_search=nil;d.return_attempts=nil;d.blocked_return=nil;d.frontier_checked=0;d.frontier_anchor=1
 d.state=F.at_home(d) and "loading" or "idle"
end
local function add_pending(d,record,rail,permit)
 if record and not d.pending[record.id] then
  d.pending[record.id]={id=record.id,rail=rail,permit=permit};d.accessory_wait=nil
 end
end
function W.visit(d,rail)
 if not (rail and rail.valid) then return end
 d.visited[rail.unit_number]=rail
 local p=rail.position
 for _,ghost in pairs(rail.surface.find_entities_filtered{area={{p.x-12,p.y-12},{p.x+12,p.y+12}},type="entity-ghost"}) do
  R.register(ghost)
 end
 for _,direction in ipairs(directions) do
  local ending=rail.get_rail_end(direction)
  local locations={
   {ending.out_signal_location,direction},
   {ending.in_signal_location,1-direction},
   {ending.alternative_out_signal_location,direction},
   {ending.alternative_in_signal_location,1-direction}
  }
  for _,pair in ipairs(locations) do
   local p=pair[1]
   if p then
    for _,name in ipairs{"rail-signal","rail-chain-signal"} do
     add_pending(d,R.lookup(d.force_index,d.surface_index,name,p.position,p.direction),rail,pair[2])
    end
   end
  end
 end
 if rail.type=="straight-rail" then
  local p=rail.position
  local slots
  if rail.direction==defines.direction.north or rail.direction==defines.direction.south then
   slots={{x=p.x+2,y=p.y,direction=defines.direction.north},{x=p.x-2,y=p.y,direction=defines.direction.south}}
  elseif rail.direction==defines.direction.east or rail.direction==defines.direction.west then
   slots={{x=p.x,y=p.y+2,direction=defines.direction.east},{x=p.x,y=p.y-2,direction=defines.direction.west}}
  end
  for _,slot in ipairs(slots or {}) do
   add_pending(d,R.lookup(d.force_index,d.surface_index,"train-stop",slot,slot.direction),rail,nil)
  end
 end
end
local function claim(d,id)
 local owner=storage.ct.claims[id]
 if owner and owner~=d.id and storage.ct.depots[owner] then return false end
 storage.ct.claims[id]=d.id;return true
end
local function next_ghost(d,rail,direction)
 local options={}
 for _,ext in ipairs(rail.get_rail_end(direction).get_rail_extensions("rail")) do
  if C.rail_types[ext.name] then
   local record=R.lookup(d.force_index,d.surface_index,ext.name,ext.position,ext.direction)
   if record and (not storage.ct.claims[record.id] or storage.ct.claims[record.id]==d.id) then
    options[#options+1]={record=record,extension=ext}
   end
  end
 end
 table.sort(options,function(a,b) return a.record.key<b.record.key end)
 return options[1]
end
local function dispatch(d)
 if game.tick<(d.path_retry or 0) then return false end
 if storage.ct.path_budget<=0 then return nil end
 local ids,revision=R.frontier_ids(d.force_index,d.surface_index)
 if #ids==0 then return false end
 if d.frontier_revision~=revision then
  d.frontier_revision=revision;d.frontier_checked=0;d.frontier_anchor=1
 end
 if d.frontier_total~=#ids then d.frontier_total=#ids;d.frontier_checked=0;d.frontier_anchor=1 end
 local candidates,goals={},{}
 local processed=0
 while processed<32 and (d.frontier_checked or 0)<#ids and #goals<16 do
  if d.frontier_cursor>#ids then d.frontier_cursor=1 end
  local id=ids[d.frontier_cursor]
  local record=storage.ct.ghosts[id];local frontier=storage.ct.frontiers[id]
  local eligible=record and record.entity.valid and record.owner==d.force_index and record.surface==d.surface_index and frontier and
   (not storage.ct.claims[id] or storage.ct.claims[id]==d.id)
  local index=d.frontier_anchor or 1
  if eligible then
   while index<=#frontier.anchors and #goals<16 do
    local a=frontier.anchors[index];index=index+1
    if a.rail.valid then
     goals[#goals+1]={rail=a.rail,direction=a.direction}
     candidates[#candidates+1]={id=id,rail=a.rail,direction=a.direction}
    end
   end
  end
  if not eligible or index>#frontier.anchors then
   d.frontier_cursor=d.frontier_cursor+1;d.frontier_anchor=1
   d.frontier_checked=(d.frontier_checked or 0)+1;processed=processed+1
  else d.frontier_anchor=index;break end
 end
 local complete=d.frontier_checked>=#ids
 if complete then d.frontier_checked=0;d.frontier_anchor=1 end
 if #goals==0 then if complete then return false else return nil end end
 storage.ct.path_budget=storage.ct.path_budget-1
 local result=game.train_manager.request_train_path{train=train(d),goals=goals,return_path=false,steps_limit=8192}
 if not result.found_path then
  if complete then d.path_retry=game.tick+300;return false end
  return nil
 end
 d.frontier_checked=0;d.frontier_anchor=1;d.path_retry=nil
 local chosen=candidates[result.goal_index]
 if not claim(d,chosen.id) then return nil end
 d.anchor=chosen.rail;d.direction=chosen.direction;d.task=chosen.id
 W.visit(d,d.anchor)
 return drive(d,d.anchor,d.direction,"build")
end
local function native_exit(d,full)
 return game.train_manager.request_train_path{train=train(d),goals=F.home_goals(d),return_path=full,steps_limit=16384}
end
local function signal_safe(d,job)
 if not job.permit then return true end
 local result=native_exit(d,true)
 if not result.found_path then return false end
 for index,rail in ipairs(result.path or {}) do
  if rail==job.rail then
   local next_rail=result.path[index+1]
   if not next_rail then return true end
   local needed
   for _,direction in ipairs(directions) do
    for _,connection in ipairs(connections) do
     if rail.get_connected_rail{rail_direction=direction,rail_connection_direction=connection}==next_rail then needed=direction end
    end
   end
   if needed==nil or needed==job.permit then return true end
   -- An already installed opposite signal preserves the other travel direction.
   local ending=rail.get_rail_end(needed)
   local spot=ending.out_signal_location
   for _,real in pairs(rail.surface.find_entities_filtered{position=spot.position,type={"rail-signal","rail-chain-signal"},force=game.forces[d.force_index]}) do
    if real.direction==spot.direction and G.same(real.position,spot.position) then return true end
   end
   return false
  end
 end
 return true
end
local finish_accessory
local function accessory(d)
 local candidates={}
 local earliest
 for id,job in pairs(d.pending) do
  local record=storage.ct.ghosts[id]
  if not (record and record.entity.valid and job.rail.valid) then d.pending[id]=nil
  elseif job.retry and game.tick<job.retry then earliest=math.min(earliest or job.retry,job.retry)
  elseif not storage.ct.claims[id] or storage.ct.claims[id]==d.id or not storage.ct.depots[storage.ct.claims[id]] then
   local position=record.entity.position
   candidates[#candidates+1]={id=id,job=job,distance=math.min(G.distance(position,d.head.position),G.distance(position,d.rear.position)),contact=G.side_contact(d.head,position) or G.side_contact(d.rear,position)}
  end
 end
 table.sort(candidates,function(a,b)
  if a.contact~=b.contact then return a.contact end
  if a.distance~=b.distance then return a.distance<b.distance end
  return a.id<b.id
 end)
 if #candidates==0 then
  if earliest then d.accessory_wait=earliest;return nil end
  return false
 end
 d.accessory_wait=nil
 local first=candidates[1]
 if first.contact and train(d).speed==0 and claim(d,first.id) then
  d.accessory=first.id;d.state="accessory";finish_accessory(d)
  return true
 end
 if storage.ct.path_budget<=0 then return nil end
 local goals,choices={},{}
 for i=1,math.min(8,#candidates) do
  local candidate=candidates[i]
  for _,direction in ipairs(directions) do
   goals[#goals+1]={rail=candidate.job.rail,direction=direction}
   choices[#choices+1]=candidate
  end
 end
 storage.ct.path_budget=storage.ct.path_budget-1
 local path=game.train_manager.request_train_path{train=train(d),goals=goals,shortest_path=true,steps_limit=8192}
 if not path.found_path then
  for i=1,math.min(8,#candidates) do candidates[i].job.retry=game.tick+300 end
  return nil
 end
 local chosen=choices[path.goal_index]
 if not claim(d,chosen.id) then return nil end
 d.accessory=chosen.id
 local goal=goals[path.goal_index]
 return drive(d,goal.rail,goal.direction,"accessory")
end
local function build(d)
 if I.low_fuel(d) then
  d.resume_anchor=d.anchor;d.resume_direction=d.direction;d.refill_mode="rails"
  W.home(d,"refill");return
 end
 if not (d.anchor and d.anchor.valid) then d.task=nil;d.state="idle";return end
 local option=next_ghost(d,d.anchor,d.direction)
 if not option then
  if d.task then storage.ct.claims[d.task]=nil end
  d.task=nil;d.state="idle";d.next_dispatch=game.tick+30
  return
 end
 local ending=d.anchor.get_rail_end(d.direction)
 if not (G.rail_contact(d.head,ending.location.position) or G.rail_contact(d.rear,ending.location.position)) then
  W.block(d,"contact","rail");return
 end
 if not claim(d,option.record.id) then d.state="idle";return end
 d.task=option.record.id
 local real,reason=I.revive(d,option.record.entity)
 if not real then
  if reason=="materials" then
   d.resume_anchor=d.anchor;d.resume_direction=d.direction
   d.refill_mode="rails"
   W.home(d,"refill")
  else W.block(d,"obstacle","obstacle") end
  return
 end
 R.unregister(option.record.id)
 local direction=G.find_end(real,option.extension.goal)
 if not direction then W.block(d,"contact","rail");return end
 W.visit(d,real);R.from_rail(real)
 d.anchor=real;d.direction=direction;d.task=nil
 drive(d,real,direction,"build")
end
finish_accessory=function(d)
 if I.low_fuel(d) then d.refill_mode="accessories";W.home(d,"refill");return end
 local id=d.accessory;local record=storage.ct.ghosts[id];local job=d.pending[id]
 if not (record and record.entity.valid and job and job.rail.valid) then d.pending[id]=nil;d.state="accessories";return end
 if not (G.side_contact(d.head,record.entity.position) or G.side_contact(d.rear,record.entity.position)) then
  job.retry=game.tick+1800;storage.ct.claims[id]=nil;d.state="accessories";d.message="accessory-contact";return
 end
 if not signal_safe(d,job) then
  job.retry=game.tick+1800;storage.ct.claims[id]=nil;d.state="accessories";d.message="return";return
 end
 local real,reason=I.revive(d,record.entity)
 if not real then
  if reason=="materials" then d.refill_mode="accessories";W.home(d,"refill")
  else job.retry=game.tick+1800;d.state="accessories" end
  return
 end
 if real.type=="train-stop" then
  if real.connected_rail~=job.rail then W.block(d,"contact","stop-binding");return end
 else
  local correct=false
  for _,rail in ipairs(real.get_connected_rails()) do if rail==job.rail then correct=true end end
  if not correct then W.block(d,"contact","signal-binding");return end
 end
 R.unregister(id);d.pending[id]=nil;d.accessory=nil;d.state="accessories"
 local exit=native_exit(d,false)
 if not exit.found_path then W.block(d,"no-path","return") end
end
function W.tick(d)
 if d.pending_removal then F.withdraw(d,d.refund);return end
 if not F.valid(d) then d.state="damaged";d.enabled=false;F.release_claims(d);return end
 local t=train(d);d.train_id=t.id
 if #t.passengers>0 then if d.enabled then W.pause(d) end;return end
 if not d.enabled then return end
 if d.auto_controlled==nil then d.auto_controlled=d.state=="travelling" or d.state=="build" or d.state=="accessory" or d.state=="accessories" end
 if d.auto_controlled and t.manual_mode then W.pause(d);return end
 if blocked_states[d.state] then
  if not d.retry_at then W.block(d,d.state,d.message) end
  if game.tick>=d.retry_at then
   d.retry_at=nil;d.task=nil;d.path_retry=nil;d.next_dispatch=game.tick
   if d.blocked_return then
    local reason=d.blocked_return;d.blocked_return=nil;W.home(d,reason)
   else d.state="idle" end
  end
  return
 end
 if d.state=="travelling" then
  if game.tick-d.command_tick<20 or t.speed~=0 then return end
  if t.state==defines.train_state.no_path or t.state==defines.train_state.path_lost then
   W.block(d,"no-path",(d.arrival=="home" or d.arrival=="refill" or d.arrival=="retreat") and "return" or "route");return
  end
  if t.state~=defines.train_state.wait_station then return end
  if d.arrival=="build" then d.state="build"
  elseif d.arrival=="accessory" then d.state="accessory"
  elseif d.arrival=="retreat" then W.home(d,d.return_reason)
  elseif d.arrival=="refill" then
   if not F.at_home(d) then W.block(d,"placement","home");return end
   d.refills=(d.refills or 0)+1;d.state="loading"
  else d.state="loading";d.home_idle=true end
 elseif d.state=="return-search" then W.search_return(d)
 elseif d.state=="loading" then
  if not F.at_home(d) then W.home(d,"home");return end
  I.load(d)
  if I.ready(d) then
   if d.refill_mode=="rails" and d.resume_anchor and d.resume_anchor.valid then
    d.refill_mode=nil;drive(d,d.resume_anchor,d.resume_direction,"build");d.resume_anchor=nil
   elseif d.refill_mode=="accessories" then d.refill_mode=nil;d.state="accessories"
   else d.state="idle";d.next_dispatch=game.tick end
  end
 elseif d.state=="build" then build(d)
 elseif d.state=="accessory" then finish_accessory(d)
 elseif d.state=="accessories" then
  local rails=dispatch(d)
  if rails==nil or rails then return end
  if accessory(d)==false then W.home(d,"home");d.next_dispatch=game.tick+300 end
 elseif d.state=="idle" then
  if game.tick<(d.next_dispatch or 0) or game.tick<(d.path_retry or 0) then return end
  local dispatched=dispatch(d)
  if dispatched==nil then return end
  if not dispatched then
   if storage.ct.dirty[storage.ct.dirty_head] then d.next_dispatch=game.tick+60;return end
   for _,rail in pairs(d.visited) do if rail.valid then W.visit(d,rail) end end
   if next(d.pending) then d.state="accessories"
   elseif not F.at_home(d) then W.home(d,"home")
   else d.next_dispatch=game.tick+300 end
  end
 end
end
return W
