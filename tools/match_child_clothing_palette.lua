-- Recolour only the child's existing garment swatches using the live adult art.
local root=assert(app.params.root)
local pc=app.pixelColor
local function rgb(r,g,b) return pc.rgba(r,g,b,255) end
local adult=app.open(root..'/assets/characters/hooshang/sprites/native18/movement.png')
local ref=adult.cels[1].image
local cardigan=ref:getPixel(5,9);local cardiganShade=ref:getPixel(4,10)
local shirt=ref:getPixel(8,9);local shirtLight=ref:getPixel(9,9)
local trousers=ref:getPixel(7,13);local trousersShade=ref:getPixel(7,15)
local replace={
 [rgb(68,38,45)]=cardiganShade,[rgb(153,82,48)]=cardigan,[rgb(201,126,72)]=cardigan,
 [rgb(49,92,112)]=shirt,[rgb(86,149,170)]=shirt,[rgb(151,210,218)]=shirtLight,
 [rgb(40,29,46)]=trousersShade,[rgb(77,46,78)]=trousers,[rgb(115,70,102)]=trousers,
}
local path=root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite'
local s=app.open(path);local changed=0
for _,l in ipairs(s.layers) do
 if l.name=='Clothing and shoes' or l.name=='Face hair and hands' then
  for _,cel in ipairs(l.cels) do
   local im=Image(cel.image)
   for y=0,im.height-1 do for x=0,im.width-1 do
    local old=im:getPixel(x,y);local new=replace[old]
    if new then im:putPixel(x,y,new);changed=changed+1 end
   end end
   cel.image=im
  end
 end
end
s:saveAs(path)
print('Matched '..changed..' garment pixels to adult clothing colors across '..#s.frames..' frames')
