-- Keep the editable body layers intact. At 0.375 scale a one-source-pixel
-- contour vanishes; three source pixels survive as a thin gameplay contour.
-- Hair already reads dark, so keep its original one-source-pixel perimeter.
local root=assert(app.params.root)
local path=root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite'
local s=app.open(path)
local pc=app.pixelColor
local outline
for _,l in ipairs(s.layers) do if l.name:find('Black outline') then outline=l end end
assert(outline)
local hair={}
for _,rgb in ipairs({{22,22,30},{79,77,92},{43,42,56}}) do
 hair[pc.rgba(rgb[1],rgb[2],rgb[3],255)]=true
end
local snapshots={}
for _,l in ipairs(s.layers) do
 if l~=outline then
  for _,c in ipairs(l.cels) do snapshots[#snapshots+1]={cel=c,bytes=c.image.bytes,x=c.position.x,y=c.position.y} end
 end
end
for n=1,#s.frames do
 local grounded=false
 for _,t in ipairs(s.tags) do
  if n>=t.fromFrame.frameNumber and n<=t.toFrame.frameNumber then
   grounded=t.name=='idle' or t.name=='run' or t.name=='sprint' or t.name=='skid'
  end
 end
 local body=Image(s.width,s.height,ColorMode.RGB)
 for _,l in ipairs(s.layers) do
  if l~=outline and not l.name:find('Socks') then
   local c=l:cel(n);if c then body:drawImage(c.image,c.position) end
  end
 end
 local ring=Image(s.width,s.height,ColorMode.RGB)
 for y=0,s.height-1 do for x=0,s.width-1 do
  local pixel=body:getPixel(x,y)
  if pc.rgbaA(pixel)>0 then
   local radius=hair[pixel] and 1 or 3
   for dy=-radius,radius do for dx=-radius,radius do
    local xx,yy=x+dx,y+dy
    if xx>=0 and yy>=0 and xx<s.width and yy<s.height and pc.rgbaA(body:getPixel(xx,yy))==0 then
     ring:putPixel(xx,yy,pc.rgba(0,0,0,255))
    end
   end end
  end
 end end
 -- Put the bottom stroke just inside the soles on standing/stride frames.
 -- Expanding it below the soles would draw through the floor. This is on
 -- the outline layer, leaving the original editable shoe pixels underneath.
 if grounded then
  for y=60,s.height-1 do for x=0,s.width-1 do
   if y>=63 then ring:putPixel(x,y,0)
   elseif pc.rgbaA(body:getPixel(x,y))>0 then ring:putPixel(x,y,pc.rgba(0,0,0,255)) end
  end end
 end
 s:newCel(outline,n,ring,Point(0,0))
end
outline.stackIndex=#s.layers-1 -- above body/details, below the sock marks
outline.name='Black outline - gameplay pixel'
for _,v in ipairs(snapshots) do
 assert(v.cel.image.bytes==v.bytes and v.cel.position.x==v.x and v.cel.position.y==v.y,'Body layer changed')
end
s:saveAs(path)
print('Outlined '..#s.frames..' editable frames; body, hair, timing and sock layers preserved')
