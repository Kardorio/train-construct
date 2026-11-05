-- Appended only to the isolated beta package by pyanodon.py.
local function amounts(entries)
 local result={}
 for _,entry in pairs(entries) do
  assert(not result[entry.name],"Duplicate ingredient: "..entry.name)
  result[entry.name]=entry.amount
 end
 return result
end
local function same(actual,expected,label)
 for name,value in pairs(expected) do assert(actual[name]==value,label..": "..name.." expected "..tostring(value)..", got "..tostring(actual[name])) end
 for name in pairs(actual) do assert(expected[name]~=nil,label..": unexpected "..name) end
end
script.on_event(defines.events.on_tick,function(event)
 if storage.ct_py_done then return end
 local player=game.get_player(1)
 if not player then return end -- --create has no player; --test-save supplies one.
 local force=player.force
 local name="ct-construction-depot"
 if not storage.ct_py_started then
  storage.ct_py_started=event.tick
  local recipe=force.recipes[name]
  local tech=force.technologies["ct-railway-construction"]
  local railway=force.technologies["automated-rail-transportation"]
  local py=script.active_mods.pycoalprocessing or script.active_mods.pyindustry
  local petroleum=script.active_mods.pypetroleumhandling
  local expected={locomotive=2,["cargo-wagon"]=1,["steel-chest"]=4,["steel-plate"]=40,["electronic-circuit"]=py and 15 or 30,rail=15}
  expected[py and petroleum and "small-parts-01" or "iron-gear-wheel"]=40
  same(amounts(recipe.ingredients),expected,"Final recipe")
  same(amounts(recipe.products),{[name]=1},"Recipe products")
  assert(recipe.energy==10,"Recipe crafting time changed")
  local prerequisites={}
  for key in pairs(tech.prerequisites) do prerequisites[key]=1 end
  local required={["automated-rail-transportation"]=1}
  same(prerequisites,required,"Final prerequisites")
  local unit=tech.prototype
  assert(#unit.effects==1 and unit.effects[1].type=="unlock-recipe" and unit.effects[1].recipe==name,"Technology unlock effect changed")
  if py then
   local source=railway.prototype
   assert(unit.research_unit_count==source.research_unit_count,"Research count differs from railway")
   assert(unit.research_unit_count_formula==source.research_unit_count_formula,"Research formula differs from railway")
   assert(unit.research_unit_energy==source.research_unit_energy,"Research time differs from railway")
   same(amounts(unit.research_unit_ingredients),amounts(source.research_unit_ingredients),"Railway science clone")
  else
   assert(unit.research_unit_count==150,"Vanilla research count changed")
   assert(unit.research_unit_energy==1800,"Vanilla research time changed")
   same(amounts(unit.research_unit_ingredients),{["automation-science-pack"]=1,["logistic-science-pack"]=1},"Vanilla science")
  end
  assert(not tech.researched and not recipe.enabled,"Recipe must start locked")
  for _,prerequisite in pairs(tech.prerequisites) do prerequisite.researched=true end
  assert(not recipe.enabled,"Prerequisite research unlocked depot early")
  assert(force.add_research(tech.name),"Native research queue rejected depot technology")
  assert(force.current_research==tech,"Depot technology not selected for research")
  tech.researched=true
  assert(recipe.enabled,"Research did not unlock depot recipe")
  log("CT_PY research verified")
  if player.controller_type==defines.controllers.cutscene then player.exit_cutscene() end
  if not player.character then
   player.set_controller{type=defines.controllers.god}
   assert(player.create_character(),"Native player has no character")
  end
  player.clear_items_inside()
  local inventory=player.get_main_inventory()
  for ingredient,count in pairs(expected) do
   assert(inventory.insert{name=ingredient,count=count}==count,"Cannot insert exact ingredients: "..ingredient)
  end
  assert(player.begin_crafting{count=1,recipe=name}==1,"Native crafting rejected depot")
  for ingredient in pairs(expected) do assert(inventory.get_item_count(ingredient)==0,"Crafting did not consume exact ingredients: "..ingredient) end
 elseif player.crafting_queue_size==0 then
  local inventory=player.get_main_inventory()
  assert(inventory.get_item_count(name)==1,"Native crafting produced no depot")
  assert(#inventory.get_contents()==1,"Native crafting left unexpected items")
  storage.ct_py_done=true
  log("CT_PY SUCCESS native research and exact crafting")
  helpers.write_file("ct-py-result.txt","success",false)
 end
end)
