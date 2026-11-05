local C=require("scripts.constants")
local Categories={}
function Categories.key(name)
 return C.rail_types[name] and "rail" or name
end
function Categories.allowed(depot,name)
 local key=Categories.key(name)
 return C.targets[key]~=nil and (not depot.categories or depot.categories[key]~=false)
end
function Categories.initialize(depot)
 depot.categories=depot.categories or {}
 for name in pairs(C.targets) do if depot.categories[name]==nil then depot.categories[name]=true end end
end
function Categories.any(depot)
 for name in pairs(C.targets) do if Categories.allowed(depot,name) then return true end end
 return false
end
return Categories
