-- One-time ending-only poses from the approved adult source. Never saves it.
-- Later edits belong in the new Aseprite file; export with export_act2_finale.py.
local root=app.params.root or '/Users/ari/Hooshang_claude'
local dest=root..'/assets/characters/hooshang/act2_ending/source/finale.aseprite'
local exists=io.open(dest,'rb'); if exists then exists:close(); if app.params.rebuild~='yes' then error('Finale source exists; edit/export it instead of rebuilding.') end end
local base=app.open(root..'/assets/characters/hooshang/aseprite/hooshang_18px_movement.aseprite')
local idle=Image(18,18,ColorMode.RGB); idle:drawSprite(base,1)
local crouch=Image(18,18,ColorMode.RGB); crouch:drawSprite(base,59)
local black=idle:getPixel(7,1)
local skin=idle:getPixel(8,4)
local sleeve=idle:getPixel(5,9)
local shade=idle:getPixel(4,10)
local blue=idle:getPixel(8,8)
local inkSprite=app.open(root..'/assets/props/school_wall/poem_second_line.png')
local inkImage=Image(232,40,ColorMode.RGB);inkImage:drawSprite(inkSprite,1)
local ink
for y=0,39 do for x=0,231 do
 local pixel=inkImage:getPixel(x,y)
 if not ink and app.pixelColor.rgbaA(pixel)>200 then ink=pixel end
end end
assert(ink,'Missing poem ink colour')
local function rect(im,x,y,w,h,c)
 for yy=y,y+h-1 do for xx=x,x+w-1 do im:putPixel(xx,yy,c) end end
end
local function arm(y,frame)
 local im=Image(idle)
 if frame then im=Image(18,18,ColorMode.RGB); im:drawSprite(base,frame) end
 -- Only the leading arm changes; the face, torso, legs and outline stay intact.
 rect(im,13,8,4,6,0)
 rect(im,12,8,3,3,black); rect(im,13,9,2,1,sleeve)
 rect(im,14,y+1,3,10-y,black); rect(im,15,y+2,1,8-y,sleeve)
 rect(im,14,y,3,3,black); rect(im,15,y+1,1,1,skin)
 return im
end
local s=Sprite(18,18,ColorMode.RGB)
local frames={crouch,crouch,arm(9),arm(7),arm(6,7),arm(7,9),arm(8,11),arm(7,13),arm(6),arm(4),arm(3),arm(4),idle}
local function painted(im)
 local copy=Image(im)
 for y=9,17 do for x=0,17 do
  if copy:getPixel(x,y)==skin then copy:putPixel(x,y,ink) end
 end end
 return copy
end
for i=9,12 do
 frames[i]=painted(frames[i])
 -- The raised leading palm sits above the ordinary hand band.
 for y=0,8 do for x=14,17 do
  if frames[i]:getPixel(x,y)==skin then frames[i]:putPixel(x,y,ink) end
 end end
end
for i=7,14 do local im=Image(18,18,ColorMode.RGB);im:drawSprite(base,i);table.insert(frames,painted(im)) end
for i=1,4 do table.insert(frames,painted(frames[i])) end
table.insert(frames,painted(idle))
for i,im in ipairs(frames) do
 if i>1 then s:newEmptyFrame() end
 local old=s.layers[1]:cel(i); if old then s:deleteCel(old) end
 s:newCel(s.layers[1],i,im,Point(0,0));s.frames[i].duration=0.16
end
s.frames[1].duration=0.25;s.frames[2].duration=0.2;s.frames[11].duration=0.65
for _,clip in ipairs({{'pickup',1,4},{'paint',5,8},{'salute',9,12},{'idle',13,13},{'walk_home',14,21},{'pickup_coat',22,25},{'paint_idle',26,26}}) do
 local t=s:newTag(clip[2],clip[3]);t.name=clip[1]
end
s:saveAs(dest)
-- A folded overcoat, using the same approved outfit colours, with dark seams.
local coat=Sprite(12,8,ColorMode.RGB);local im=Image(12,8,ColorMode.RGB)
rect(im,2,1,8,6,black);rect(im,1,3,10,4,black)
rect(im,3,2,6,4,sleeve);rect(im,2,4,8,2,sleeve)
rect(im,5,2,2,2,shade);rect(im,4,3,4,1,blue);rect(im,3,6,6,1,shade)
coat:newCel(coat.layers[1],1,im,Point(0,0))
coat:saveAs(root..'/assets/characters/hooshang/act2_ending/source/coat.aseprite')
print('Authored ending-only pickup, paint and salute; original source untouched.')
