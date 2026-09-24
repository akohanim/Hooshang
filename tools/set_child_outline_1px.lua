-- Aseprite-only contour correction. Never rescale or move the body artwork.
local root=app.params.root
local path=root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite'
local s=app.open(path)
local body,outline
for _,layer in ipairs(s.layers) do
 if layer.name:find('Black outline') then outline=layer end
 if layer.name=='Young Hooshang movement' then body=layer end
end
assert(body and outline,'Expected separate body and outline layers')
local pc=app.pixelColor
local before={}
for n=1,#s.frames do
 local cel=body:cel(n)
 before[n]={bytes=cel.image.bytes,x=cel.position.x,y=cel.position.y}
 local im=Image(88,88,ColorMode.RGB)
 im:drawImage(cel.image,cel.position)
 local ring=Image(88,88,ColorMode.RGB)
 for y=1,86 do for x=1,86 do
  if pc.rgbaA(im:getPixel(x,y))==0 then
   local adjacent=false
   for dy=-1,1 do for dx=-1,1 do
    if pc.rgbaA(im:getPixel(x+dx,y+dy))>0 then adjacent=true end
   end end
   if adjacent then ring:putPixel(x,y,pc.rgba(0,0,0,255)) end
  end
 end end
 s:newCel(outline,n,ring,Point(0,0))
end
outline.name='Black outline - 1px'
for n=1,#s.frames do
 local cel=body:cel(n); local original=before[n]
 assert(cel.image.bytes==original.bytes and cel.position.x==original.x and cel.position.y==original.y,
  'Body artwork or position changed')
end
s:saveAs(path)
print('Exactly 1px outline on '..#s.frames..' frames; body pixels and positions unchanged')
