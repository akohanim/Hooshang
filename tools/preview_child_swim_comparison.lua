local root=assert(app.params.root);local pc=app.pixelColor
local s=app.open(root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
local first,rest;for _,t in ipairs(s.tags) do if t.name=='swim' then first=t.fromFrame.frameNumber elseif t.name=='swim_idle' then rest=t.fromFrame.frameNumber end end
local preview=Sprite(3*44,44)
for tick=0,47 do
 if tick>0 then preview:newEmptyFrame() end
 local im=Image(132,44,ColorMode.RGB);im:clear(pc.rgba(165,178,168,255))
 local phase=tick%24
 local offset=phase<4 and 0 or (phase<8 and 1 or (phase<12 and 2 or 3))
 for col=1,3 do
  local full=Image(88,88,ColorMode.RGB);full:drawSprite(s,col==3 and rest or first+offset)
  for y=0,43 do for x=0,43 do local c=full:getPixel(2*x,2*y);if pc.rgbaA(c)>0 then im:putPixel((col-1)*44+(col==2 and 43-x or x),y,c) end end end
 end
 preview:newCel(preview.layers[1],tick+1,im,Point(0,0));preview.frames[tick+1].duration=1/60
end
preview:resize(660,220);preview:saveAs(root..'/output/child_animation_pack/swim_corrected.gif')
print('Child right / child left / resting glide')
