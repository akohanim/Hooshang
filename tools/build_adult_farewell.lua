-- Ending-only aging/release poses, derived from the approved adult grip.
-- Never writes the shared movement source or the child's farewell source.
local root=app.params.root or '/Users/ari/Hooshang_claude'
local dest=root..'/assets/characters/hooshang/act2_ending/source/farewell.aseprite'
local exists=io.open(dest,'rb');if exists then exists:close();error('Edit the saved adult farewell source; do not rebuild it.') end
local base=app.open(root..'/assets/characters/hooshang/aseprite/hooshang_18px_movement.aseprite')
local gripTag;for _,t in ipairs(base.tags) do if t.name=='climb_idle' then gripTag=t end end
assert(gripTag,'Missing adult grip pose')
local hold=Image(18,18,ColorMode.RGB);hold:drawSprite(base,gripTag.fromFrame)
local function lower(drop)
 local im=Image(hold)
 for _,span in ipairs({{2,4},{12,14}}) do
  for y=3,8 do for x=span[1],span[2] do im:putPixel(x,y,0) end end
  for y=3,8 do for x=span[1],span[2] do
   local px=hold:getPixel(x,y)
   if app.pixelColor.rgbaA(px)>0 then im:putPixel(x,y+drop,px) end
  end end
 end
 return im
end
local s=Sprite(18,18,ColorMode.RGB)
local frames={hold,hold,lower(1),lower(2),lower(3),lower(4)}
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
print('Saved adult farewell: 6 native 18px frames, hold/release/fall_rest')
