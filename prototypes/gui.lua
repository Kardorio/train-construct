local styles=data.raw["gui-style"].default
for name,parent in pairs{ct_category_on="green_button",ct_category_off="red_button"} do
 local base=styles[parent]
 styles[name]={
  type="button_style",parent=parent,size=40,padding=0,minimal_width=40,
  draw_shadow_under_picture=true,
  selected_graphical_set=table.deepcopy(base.default_graphical_set),
  selected_hovered_graphical_set=table.deepcopy(base.hovered_graphical_set),
  selected_clicked_graphical_set=table.deepcopy(base.clicked_graphical_set)
 }
end
