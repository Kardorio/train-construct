local L=require("tests.legacy_fixture")
return function(Runtime)
 -- Keep the real configuration callback; inspect before and after it runs.
 script.on_configuration_changed(function(event)
  local _,test=L.check(Runtime)
  local change=assert(event.mod_changes[script.mod_name],"No mod upgrade event")
  assert(change.old_version and change.new_version and change.old_version~=change.new_version,"Missing version transition")
  assert(test.configuration_changes==0,"Configuration migration ran more than once")
  Runtime.initialize()
  L.check(Runtime)
  test.configuration_changes=1
  log("CT_LEGACY configuration upgrade "..change.old_version.." -> "..change.new_version)
 end)
 local checked=false
 local checkpoint_requested=false
 script.on_event(defines.events.on_tick,function(event)
  if checked or event.tick%30~=0 then return end
  local _,test=L.check(Runtime)
  assert(test.fixture_saved and test.configuration_changes==1,"Legacy configuration was not migrated")
  if test.upgrade_saved and not checkpoint_requested then
   checked=true
   helpers.write_file("ct-legacy-reload.txt","reload verified\n",false)
   log("CT_LEGACY SUCCESS current reload identities and exact manifests")
  elseif not checkpoint_requested then
   test.upgrade_saved=true
   checkpoint_requested=true
   game.auto_save("ct-legacy-current")
   log("CT_LEGACY checkpoint current")
  else
   checked=true
   helpers.write_file("ct-legacy-upgrade.txt","upgrade verified\n",false)
   log("CT_LEGACY SUCCESS upgrade identities and exact manifests")
  end
 end)
end
