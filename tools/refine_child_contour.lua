-- One-time native Aseprite refinement of the saved child artwork.
local root=assert(app.params.root)
local path=root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite'
local s=app.open(path)
local pc=app.pixelColor
local outline,face,clothes
for _,l in ipairs(s.layers) do
 if l.name:find('Black outline') then outline=l end
 if l.name=='Face hair and hands' then face=l end
 if l.name=='Clothing and shoes' then clothes=l end
end
assert(outline and face and clothes)
local function blank() return Image(88,88,ColorMode.RGB) end
local function opaque(im,x,y) return x>=0 and y>=0 and x<88 and y<88 and pc.rgbaA(im:getPixel(x,y))>0 end
local function canvas(layer,n) local im=blank();local c=layer:cel(n);im:drawImage(c.image,c.position);return im end
local details=s:newLayer();details.name='Interior black details'
for n=1,#s.frames do
 local tag,localframe
 for _,t in ipairs(s.tags) do if n>=t.fromFrame.frameNumber and n<=t.toFrame.frameNumber then tag=t.name;localframe=n-t.fromFrame.frameNumber+1 end end
 local color=canvas(face,n);local outfit=canvas(clothes,n);local black=canvas(outline,n)
 -- Bring the nose, mouth and brow back to the cheek plane. Back-facing
 -- climbing poses have no projecting nose and keep their existing face.
 if tag~='climb' then
  local shift=(tag=='run' and localframe==2) and -2 or 0
  local x0,y0,y1=52,30+shift,45+shift
  if tag=='sit' then x0=54;y0=46;y1=57 end
  for y=y0,y1 do for x=x0,65 do
   color:putPixel(x,y,0);outfit:putPixel(x,y,0);black:putPixel(x,y,0)
  end end
 end
 local colored=blank();colored:drawImage(outfit);colored:drawImage(color)
 -- Flood empty space and exposed black, stopping at colored body pixels.
 -- This removes stacked reference contour + safety ring, while retaining
 -- enclosed eyes and facial details. Rebuild only one source-pixel border.
 local exterior={};local q={{0,0}};exterior[0]=true;local qi=1
 while qi<=#q do
  local p=q[qi];qi=qi+1
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
   local x,y=p[1]+d[1],p[2]+d[2];local k=y*88+x
   if x>=0 and y>=0 and x<88 and y<88 and not exterior[k] and not opaque(colored,x,y) then exterior[k]=true;q[#q+1]={x,y} end
  end
 end
 local interior=blank();local body=blank();body:drawImage(colored)
 for y=0,87 do for x=0,87 do
  if opaque(black,x,y) and not exterior[y*88+x] then interior:putPixel(x,y,black:getPixel(x,y));body:putPixel(x,y,black:getPixel(x,y)) end
 end end
 local ring=blank()
 for y=1,86 do for x=1,86 do
  if not opaque(body,x,y) then
   local adjacent=false
   for dy=-1,1 do for dx=-1,1 do if opaque(body,x+dx,y+dy) then adjacent=true end end end
   if adjacent then ring:putPixel(x,y,pc.rgba(0,0,0,255)) end
  end
 end end
 s:newCel(face,n,color,Point(0,0));s:newCel(clothes,n,outfit,Point(0,0))
 s:newCel(details,n,interior,Point(0,0));s:newCel(outline,n,ring,Point(0,0))
end
s:saveAs(path)
print('Refined all '..#s.frames..' frames: single source-pixel contour, flattened nose')
