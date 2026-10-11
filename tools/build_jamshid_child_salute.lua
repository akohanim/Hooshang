-- Finale-only half salute derived from the saved, approved child avatar.
local root=app.params.root or '/Users/ari/Hooshang_claude'
local base=root..'/assets/characters/jamshid/'
local src=app.open(base..'aseprite/jamshid_child_movement.aseprite')
local idle; for _,t in ipairs(src.tags) do if t.name=='idle' then idle=t.fromFrame.frameNumber end end
local s=Sprite(88,88,ColorMode.RGB)
for i,l in ipairs(src.layers) do
 local layer=i==1 and s.layers[1] or s:newLayer();layer.name=l.name
 local c=l:cel(idle);if c then
  local im=Image(88,88);im:drawImage(c.image,c.position)
  -- Clear the old low front hand without cutting into trousers or torso.
  for y=48,53 do for x=50,59 do im:putPixel(x,y,0) end end
  s:newCel(layer,1,im,Point(0,0))
 end
end
local gesture=s:newLayer();gesture.name='Raised sleeve and salute hand'
local im=Image(88,88);local pc=app.pixelColor
local function rgb(r,g,b) return pc.rgba(r,g,b,255) end
local function line(x1,y1,x2,y2,width,color)
 local steps=math.max(math.abs(x2-x1),math.abs(y2-y1))
 for n=0,steps do local a=n/steps;local x=math.floor(x1+(x2-x1)*a+.5);local y=math.floor(y1+(y2-y1)*a+.5)
  for dy=-math.floor(width/2),math.ceil(width/2)-1 do for dx=-math.floor(width/2),math.ceil(width/2)-1 do im:putPixel(x+dx,y+dy,color) end end
 end
end
-- Same thick gameplay contour as the child, with a bent elbow and brow touch.
line(49,48,58,43,10,rgb(0,0,0));line(58,43,56,36,10,rgb(0,0,0));line(56,36,52,35,9,rgb(0,0,0))
line(49,48,58,43,5,rgb(29,57,40));line(58,43,56,38,5,rgb(52,91,53))
line(56,37,52,35,4,rgb(255,200,139));line(54,35,52,35,2,rgb(255,217,160))
s:newCel(gesture,1,im,Point(0,0));local tag=s:newTag(1,1);tag.name='half_salute'
s:saveAs(base..'act2_ending/source/half_salute_child.aseprite')
local flat=Image(88,88);flat:drawSprite(s,1);flat:saveAs(base..'act2_ending/half_salute_child.png')
s:resize(704,704);s:saveAs(root..'/output/jamshid_pair/half_salute_child.png')
