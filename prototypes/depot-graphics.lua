-- Native source rectangles only: never resample or rewrite the generated art.
local layout = require("prototypes.depot-sprite-layout")
local M = {}

local function subtract(rect, hole)
  local x1, y1 = math.max(rect[1], hole[1]), math.max(rect[2], hole[2])
  local x2, y2 = math.min(rect[3], hole[3]), math.min(rect[4], hole[4])
  if x1 >= x2 or y1 >= y2 then return {rect} end
  local result = {}
  local function add(a, b, c, d)
    if a < c and b < d then result[#result+1] = {a,b,c,d} end
  end
  add(rect[1],rect[2],rect[3],y1)
  add(rect[1],y2,rect[3],rect[4])
  add(rect[1],y1,x1,y2)
  add(x2,y1,rect[3],y2)
  return result
end

function M.depot()
  local picture = {}
  for _, direction in ipairs({"north","east","south","west"}) do
    local spec = layout.depot[direction]
    local ppu, origin = spec.ppu, spec.origin
    local horizontal = direction == "east" or direction == "west"
    -- Only the railway is clipped; the building visually contains the stock.
    local axis = horizontal and 2 or 1
    local track = {0,0,spec.size[1],spec.size[2]}
    track[axis] = math.floor(origin[axis] - 1.5 * ppu)
    track[axis+2] = math.ceil(origin[axis] + 1.5 * ppu)
    local layers = {}
    for _, rect in ipairs(subtract(spec.bounds, track)) do
      layers[#layers+1] = {
        filename = "__construction-train__/graphics/entity/depot/depot-"..direction..".png",
        x=rect[1], y=rect[2], width=rect[3]-rect[1], height=rect[4]-rect[2],
        scale=32/ppu,
        shift={1+((rect[1]+rect[3])/2-origin[1])/ppu,
               1+((rect[2]+rect[4])/2-origin[2])/ppu}
      }
    end
    picture[direction] = {layers=layers}
  end
  return picture
end

function M.floor()
  local picture={}
  for _,direction in ipairs({"north","east","south","west"}) do
    local horizontal=direction=="east" or direction=="west"
    local layers={}
    local start=direction=="south" and 2 or 1
    local rows=horizontal and 4 or (32-start)
    local columns=horizontal and 4 or 1
    local width=horizontal and 8 or 4
    for row=0,rows-1 do
      for column=0,columns-1 do
        layers[#layers+1]={
          filename="__construction-train__/graphics/entity/depot/platform.png",
          x=horizontal and column==0 and start*512 or 0,y=0,
          width=(horizontal and column==0 and width-start or width)*512,height=512,scale=0.0625,
          shift={horizontal and (-15+column*width+width/2+(column==0 and start/2 or 0)) or 1,
                 horizontal and (-1+row+0.5) or (-15+start+row+0.5)}
        }
      end
    end
    picture[direction]={layers=layers}
  end
  return picture
end

return M
