-- Author a short ledge pull-up in the existing editable Aseprite source.
-- Preserve every approved pose/tag; append only the new six-frame clip.
local root=app.params.root or '/Users/ari/Hooshang_claude'
local s=app.open(root..'/assets/characters/hooshang/aseprite/hooshang_18px_movement.aseprite')
-- Aseprite extends a tag ending at the last frame when frames are appended.
-- Pin the existing swim exit before and after editing the new clip.
local exitTag
for _,tag in ipairs(s.tags) do
 if tag.name=='exit_water' then exitTag=tag; tag.toFrame=75 end
end
local first=#s.frames+1
for _,tag in ipairs(s.tags) do if tag.name=='ledge_climb' then first=tag.fromFrame.frameNumber end end
local layer=s.layers[1]
local pc=app.pixelColor
local black=pc.rgba(0,0,0,255)
local skin=pc.rgba(255,165,99,255)
local sleeve=pc.rgba(106,56,23,255)
local pants=pc.rgba(102,21,49,255)
local white=pc.rgba(255,255,255,255)
local function rect(im,x,y,w,h,c)
 for yy=y,y+h-1 do for xx=x,x+w-1 do im:putPixel(xx,yy,c) end end
end
app.transaction('Ledge climb: catch, pull, knee, plant, recover',function()
 for i=0,5 do
  local frame=first+i
  while #s.frames<frame do s:newEmptyFrame() end
  local im=Image(18,18,ColorMode.RGB)
  im:drawSprite(s,70+i)
  if i<3 then
   -- Leading hand hooks the lip, elbow folds as the body rises.
   rect(im,13,11-i,4,2,black)
   rect(im,13,11-i,2,1,sleeve)
   rect(im,15,10-i,2,2,skin)
  end
  if i==1 or i==2 then
   -- Lift the leading knee; back foot trails instead of a seated split.
   rect(im,10,14,5,4,0)
   rect(im,10,14-i+1,4,2,black)
   rect(im,10,14-i+1,3,1,pants)
   rect(im,13,15-i+1,2,1,white)
   rect(im,13,16-i+1,2,1,black)
  end
  if i==5 then im=Image(18,18,ColorMode.RGB); im:drawSprite(s,1) end
  local old=layer:cel(frame); if old then s:deleteCel(old) end
  s:newCel(layer,frame,im,Point(0,0))
  s.frames[frame].duration=0.04
 end
 if first+5==#s.frames then
  local found=false; for _,t in ipairs(s.tags) do if t.name=='ledge_climb' then found=true end end
  if not found then local tag=s:newTag(first,first+5); tag.name='ledge_climb' end
 end
end)
assert(exitTag, "Missing original water exit tag")
exitTag.toFrame=75
s:saveAs(s.filename)
local sheet=Image(108,18,ColorMode.RGB)
for i=0,5 do local im=Image(18,18,ColorMode.RGB); im:drawSprite(s,first+i); sheet:drawImage(im,Point(i*18,0)) end
sheet:resize(648,108)
sheet:saveAs(root..'/output/ledge_mantle/ledge_climb_contact.png')
print('Saved ledge_climb frames '..first..'..'..(first+5)..' (240ms)')
