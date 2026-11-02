local function component(entity)
 if not (entity and entity.valid) then return {valid=false} end
 local t=entity.train
 return {valid=true,id=entity.unit_number,name=entity.name,position=entity.position,orientation=entity.orientation,health=entity.health,train=t and t.id,carriages=t and #t.carriages,speed=t and t.speed,manual=t and t.manual_mode,train_state=t and t.state}
end
local previous={}
script.on_event(defines.events.on_tick,function()
 for id,d in pairs(storage.ct.depots) do
  local head,wagon,rear=component(d.head),component(d.wagon),component(d.rear)
  local signature=table.concat({d.state,d.built or 0,head.train or 0,head.carriages or 0,head.health or 0,wagon.health or 0,rear.health or 0},":")
  if previous[id]~=signature or game.tick%120==0 then
   previous[id]=signature
   local record=d.task and storage.ct.ghosts[d.task]
   log("CT_TRAFFIC "..helpers.table_to_json{tick=game.tick,depot=id,state=d.state,enabled=d.enabled,built=d.built,arrival=d.arrival,task=d.task,task_position=record and record.entity.valid and record.entity.position,claim=d.task and storage.ct.claims[d.task],head=head,wagon=wagon,rear=rear})
  end
 end
end)
