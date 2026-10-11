-- Remove the long cheek/mouth shadow band from both saved child sources.
-- Work on the face layer only; keep short ear/jaw shading and raised hands.
local root=app.params.root or '/Users/ari/Hooshang_claude'
local pc=app.pixelColor
local shadow=pc.rgba(218,130,84,255)
local skin=pc.rgba(255,200,139,255)
for _,path in ipairs({'assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite','assets/characters/jamshid/aseprite/jamshid_child_movement.aseprite'}) do
 local s=app.open(root..'/'..path)
 local face; for _,l in ipairs(s.layers) do if l.name=='Face hair and hands' then face=l end end
 assert(face)
 local changed=0
 for n=1,#s.frames do
  local c=assert(face:cel(n));local im=Image(88,88);im:drawImage(c.image,c.position)
  -- Across all authored poses the cheek stripe is a 10-source-pixel run.
  -- The same shade on the raised palm lies at y=32, above the face band.
  for y=36,57 do
   local x=0
   while x<88 do
    local start=x;local color=im:getPixel(x,y)
    while x<88 and im:getPixel(x,y)==color do x=x+1 end
    if color==shadow and x-start==10 then
     for xx=start,x-1 do im:putPixel(xx,y,skin);changed=changed+1 end
    end
   end
  end
  face:cel(n).image=im;face:cel(n).position=Point(0,0)
 end
 s:saveAs(root..'/'..path)
 print(path..': removed '..changed..' stripe pixels')
end
