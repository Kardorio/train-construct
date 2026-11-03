local depot = table.deepcopy(data.raw.container["steel-chest"])
depot.name = "ct-construction-depot"
depot.icon = "__base__/graphics/icons/train-stop.png"
depot.icon_size = 64
depot.minable = {mining_time = 0.5, result = "ct-construction-depot"}
depot.placeable_by = {item="ct-construction-depot",count=1}
depot.inventory_size = 100
depot.inventory_type = "with_filters_and_bar"
depot.collision_box = {{-1.3,-1.3},{1.3,1.3}}
depot.selection_box = {{-1.5,-1.5},{1.5,1.5}}
depot.flags = {"placeable-player","player-creation","not-rotatable"}
local function enlarge(sprite)
  if type(sprite) ~= "table" then return end
  if sprite.filename or sprite.filenames then sprite.scale = (sprite.scale or 1) * 3 end
  for _, value in pairs(sprite) do if type(value) == "table" then enlarge(value) end end
end
enlarge(depot.picture)
local stock=table.deepcopy(depot)
stock.name="ct-depot-stock"
stock.minable=nil
stock.placeable_by=nil
stock.flags={"placeable-player","player-creation","not-blueprintable","not-deconstructable","not-rotatable"}
local module=table.deepcopy(depot)
module.type="proxy-container"
module.name="ct-construction-module"
module.icon=depot.icon;module.icon_size=64
module.minable={mining_time=0.5,result=depot.name}
module.flags={"placeable-player","player-creation"}
module.collision_box={{-0.1,-0.1},{0.1,0.1}}
module.collision_mask={layers={water_tile=true}}
module.selection_box={{-3,-16},{9,16}}
module.selection_priority=10
module.tile_width=12;module.tile_height=32;module.build_grid_size=2
module.direction_count=4;module.inventory_size=nil;module.inventory_type=nil
module.circuit_connector=nil;module.circuit_wire_max_distance=0
module.next_upgrade=nil;module.fast_replaceable_group=nil
local empty={filename="__core__/graphics/empty.png",width=1,height=1}
module.picture={north=empty,east=empty,south=empty,west=empty}
local rail=table.deepcopy(data.raw["straight-rail"]["straight-rail"])
rail.name="ct-depot-rail";rail.minable=nil;rail.next_upgrade=nil;rail.fast_replaceable_group=nil
rail.selectable_in_game=false;rail.hidden_in_factoriopedia=true
rail.flags={"not-blueprintable","not-deconstructable","not-upgradable","no-copy-paste"}
local connector=table.deepcopy(rail)
connector.name="ct-depot-connector";connector.selectable_in_game=true
local locomotive = table.deepcopy(data.raw.locomotive.locomotive)
locomotive.name = "ct-construction-locomotive"
locomotive.minable = nil
locomotive.max_power = "2400kW"
locomotive.braking_force = 40
locomotive.color = {r=0.85,g=0.55,b=0.12}
locomotive.allow_manual_color = false
local wagon = table.deepcopy(data.raw["cargo-wagon"]["cargo-wagon"])
wagon.name = "ct-construction-wagon"
wagon.minable = nil
wagon.inventory_size = 100
wagon.quality_affects_inventory_size = false
local stop = table.deepcopy(data.raw["train-stop"]["train-stop"])
stop.name = "ct-depot-stop"
stop.minable = nil
stop.flags = {"placeable-player","player-creation","not-blueprintable","not-deconstructable"}
local item = {
 type="item", name=depot.name, icon=depot.icon, icon_size=64, subgroup="transport",
 order="a[train-system]-z[construction-depot]", place_result=module.name, stack_size=10
}
local recipe = {
 type="recipe",name=depot.name,enabled=false,energy_required=10,
 ingredients={{type="item",name="locomotive",amount=2},{type="item",name="cargo-wagon",amount=1},
 {type="item",name="steel-chest",amount=4},{type="item",name="steel-plate",amount=40},
 {type="item",name="iron-gear-wheel",amount=40},{type="item",name="electronic-circuit",amount=30},{type="item",name="rail",amount=15}},
 results={{type="item",name=depot.name,amount=1}}
}
local technology = {
 type="technology",name="ct-railway-construction",
 icon="__base__/graphics/technology/railway.png",icon_size=256,
 prerequisites={"automated-rail-transportation"},
 effects={{type="unlock-recipe",recipe=depot.name}},
 unit={count=150,ingredients={{"automation-science-pack",1},{"logistic-science-pack",1}},time=30}
}
data:extend{depot,stock,module,rail,connector,locomotive,wagon,stop,item,recipe,technology}
