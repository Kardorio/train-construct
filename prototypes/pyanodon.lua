local name="ct-construction-depot"
local recipe=data.raw.recipe[name]
local technology=data.raw.technology["ct-railway-construction"]
local railway=assert(data.raw.technology["automated-rail-transportation"])
local parts=mods.pypetroleumhandling and "small-parts-01" or "iron-gear-wheel"

assert(data.raw.item[parts],"Pyanodon mechanical parts are missing: "..parts)
recipe.ingredients={
 {type="item",name="locomotive",amount=2},
 {type="item",name="cargo-wagon",amount=1},
 {type="item",name="steel-chest",amount=4},
 {type="item",name="steel-plate",amount=40},
 {type="item",name=parts,amount=40},
 {type="item",name="electronic-circuit",amount=15},
 {type="item",name="rail",amount=15}
}
technology.prerequisites={railway.name}
-- Py's cached progression is applied in final fixes, before this optional dependency.
technology.unit=table.deepcopy(assert(railway.unit,"Pyanodon railway research has no science cost"))
