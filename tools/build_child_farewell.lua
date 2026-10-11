-- Ending-only hand release derived from the approved child's hanging pose.
-- Does not save the shared source. Later edits belong in farewell.aseprite.
local root=app.params.root or '/Users/ari/Hooshang_claude'
local dest=root..'/assets/characters/hooshang_child/act2_ending/source/farewell.aseprite'
local f=io.open(dest,'rb');if f then f:close();if app.params.rebuild~='yes' then error('Farewell source exists; edit it in Aseprite instead.') end end
local source=app.open(root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
local tag;for _,t in ipairs(source.tags) do if t.name=='climb_idle' then tag=t end end
assert(tag,'Missing approved grip pose')
local hold=Image(source.width,source.height,ColorMode.RGB);hold:drawSprite(source,tag.fromFrame)
local s=Sprite(source.width,source.height,ColorMode.RGB)
local function release(drop)
 local im=Image(hold)
 -- Keep the head, torso and legs. Lower both forearms away from the carpet.
 for _,span in ipairs({{28,35},{52,59}}) do
  for y=38,43 do for x=span[1],span[2] do im:putPixel(x,y,0) end end
  for y=38,43 do for x=span[1],span[2] do
   local px=hold:getPixel(x,y)
   if app.pixelColor.rgbaA(px)>0 then im:putPixel(x,y+drop,px) end
  end end
 end
 return im
end
local frames={hold,hold,release(2),release(7),release(14),release(20)}
for i,im in ipairs(frames) do
 if i>1 then s:newEmptyFrame() end
 local old=s.layers[1]:cel(i);if old then s:deleteCel(old) end
 s:newCel(s.layers[1],i,im,Point(0,0));s.frames[i].duration=.16
end
s.frames[2].duration=.24;s.frames[6].duration=.3
local t=s:newTag(1,1);t.name='hold'
t=s:newTag(2,6);t.name='release'
t=s:newTag(6,6);t.name='fall_rest'
s:saveAs(dest)
