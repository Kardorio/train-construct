local layout=require("prototypes.train-sprite-layout")
local Graphics={}

function Graphics.picture(kind)
 local art=assert(layout[kind])
 local frames={}
 for index,frame in ipairs(art.frames) do
  frames[#frames+1]={x=frame.x-(index-1)%art.line_length*art.cell_size,
   y=frame.y-math.floor((index-1)/art.line_length)*art.cell_size,width=art.width,height=art.height}
 end
 local sprite={filename="__construction-train__/"..art.source,width=art.cell_size,height=art.cell_size,
  line_length=art.line_length,frames=frames,direction_count=#frames,scale=art.scale,shift=art.shift,usage="train"}
 local shadow=table.deepcopy(sprite)
 shadow.draw_as_shadow=true
 shadow.tint={r=0,g=0,b=0,a=0.3}
 shadow.shift={art.shift[1]+0.6,art.shift[2]+0.45}
 return {rotated={layers={shadow,sprite}}}
end

return Graphics
