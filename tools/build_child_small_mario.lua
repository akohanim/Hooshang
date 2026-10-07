-- Aseprite authoring pass: measured Small Mario silhouettes/poses, recoloured
-- into Hooshang's hair/cardigan/shirt/trousers. Reference data stays in output/.
-- Ordinary edits/export use the saved .aseprite, not this one-time recipe.
local root=assert(app.params.root)
local f=assert(io.open(root..'/output/child_small_mario/reference_poses.json'))
local refs=json.decode(f:read('*a'));f:close()
local pc=app.pixelColor
local function rgba(r,g,b) return pc.rgba(r,g,b,255) end
local ink=rgba(0,0,0);local white=rgba(255,255,255)
local palette={
 [1]=rgba(255,217,160),[2]=ink,[3]=rgba(87,48,36),
 [4]=rgba(142,81,43),[5]=rgba(206,141,72),
 [6]=rgba(255,200,139),[7]=white,
 [8]=rgba(22,22,30),[9]=rgba(79,77,92),
 [10]=rgba(68,38,45),[11]=rgba(153,82,48),[12]=rgba(201,126,72),
 [13]=rgba(43,42,56),[14]=rgba(218,130,84),[15]=rgba(255,210,161)}
local specs={
 {name='idle',poses={0},time=.6,loop=true},
 {name='run',poses={0,1},time=.1,loop=true},
 {name='jump',poses={11},time=.12},
 {name='fall',poses={36},time=.12,loop=true},
 {name='dash',poses={4,5},time=.06},
 {name='wall_slide',poses={13},time=.14,loop=true},
 {name='wall_jump',poses={11},time=.12},
 {name='climb',poses={21,21},time=.12,loop=true},
 {name='swim',poses={22,26,26,24},time=4/60,loop=true},
 {name='swim_idle',poses={28,28},time=.22,loop=true},
 {name='exit_water',poses={11,11,14,14,1,0},time=.072},
 {name='sit',poses={60,60},time=.18,loop=true},
 {name='ledge_climb',poses={11,11,14,14,1,0},time=.04}}
local s=Sprite(88,88);s.layers[1].name='Black outline - 1px'
local outline=s.layers[1];local outfit=s:newLayer();outfit.name='Clothing and shoes'
local face=s:newLayer();face.name='Face hair and hands'
local socks=s:newLayer();socks.name='Socks - 1px marks'
local function blank() return Image(88,88,ColorMode.RGB) end
local function put(im,x,y,c)
 for yy=y,y+1 do for xx=x,x+1 do im:putPixel(xx,yy,c) end end
end
local index=0;local ranges={};local summary={}
for _,spec in ipairs(specs) do
 local first=index+1
 for i,pose in ipairs(spec.poses) do
  index=index+1;if index>1 then s:newEmptyFrame() end
  local skin,clothes,edge,marks=blank(),blank(),blank(),blank()
  local grid=refs[pose+1].pixels
  local feet={}
  for y,row in ipairs(grid) do for x,id in ipairs(row) do
   if id>0 then
    local col=palette[id]
    -- Replace the cap emblem with dark hair shades; keep the head's outline
    -- and the exact eye/nose/cheek geometry. Shirt and trousers are surface edits.
    if y<=20 and (id==4 or id==5 or (id==1 and x>1 and row[x-1]==5)) then col=palette[9] end
    if y>=23 and (id==8 or id==9 or id==13) then
     col=id==8 and rgba(49,92,112) or (id==9 and rgba(151,210,218) or rgba(86,149,170))
    end
    if y>=28 and id>=10 and id<=12 then
     col=({[10]=rgba(40,29,46),[11]=rgba(77,46,78),[12]=rgba(115,70,102)})[id]
    end
    local draw_x=(spec.name=='climb' and i==2) and (16-x) or (x-1)
    local px,py=28+draw_x*2,(y-1)*2
    -- SMW itself raises the planted/passing pose by one native pixel.
    if spec.name=='run' and i==2 then py=py-2 end
    if spec.name=='sit' and i==2 and y<27 then py=py-2 end
    local target=(id==2) and edge or ((y<=23 or id==1 or id==6 or id==14) and skin or clothes)
    put(target,px,py,col)
    if y>=27 and (id==3 or id==4 or id==5) then table.insert(feet,{x=px,y=py}) end
   end
  end end
  -- One source-pixel safety contour around exposed coloured diagonals.
  local union=blank();union:drawImage(edge);union:drawImage(clothes);union:drawImage(skin)
  for y=1,86 do for x=1,86 do
   if pc.rgbaA(union:getPixel(x,y))==0 then
    local touch=false
    for yy=-1,1 do for xx=-1,1 do if pc.rgbaA(union:getPixel(x+xx,y+yy))>0 then touch=true end end end
    if touch then edge:putPixel(x,y,ink) end
   end
  end end
  table.sort(feet,function(a,b) return a.y>b.y or (a.y==b.y and a.x<b.x) end)
  local a=feet[1] or {x=40,y=59};local b
  for _,v in ipairs(feet) do if math.abs(v.x-a.x)>=6 then b=v;break end end
  b=b or {x=a.x+3,y=a.y}
  marks:putPixel(a.x,a.y,white);marks:putPixel(b.x,b.y,white)
  s:newCel(outline,index,edge,Point(0,0));s:newCel(outfit,index,clothes,Point(0,0))
  s:newCel(face,index,skin,Point(0,0));s:newCel(socks,index,marks,Point(0,0))
  s.frames[index].duration=spec.time
 end
 table.insert(ranges,{first=first,last=index,name=spec.name})
 table.insert(summary,{name=spec.name,reference_poses=spec.poses,duration=spec.time})
end
for _,r in ipairs(ranges) do local t=s:newTag(r.first,r.last);t.name=r.name end
s:saveAs(root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
f=io.open(root..'/output/child_small_mario/pose_mapping.json','w');f:write(json.encode(summary));f:close()
local review=Sprite(8*44,5*44);local bg=review.cels[1].image
for y=0,review.height-1 do for x=0,review.width-1 do bg:putPixel(x,y,rgba(207,205,182)) end end
for row,name in ipairs({'idle','run','jump','fall','swim'}) do
 for _,t in ipairs(s.tags) do if t.name==name then
  for n=t.fromFrame.frameNumber,t.toFrame.frameNumber do
   local full=blank();full:drawSprite(s,n)
   local native=Image(44,44,ColorMode.RGB)
   for y=0,43 do for x=0,43 do native:putPixel(x,y,full:getPixel(x*2,y*2)) end end
   bg:drawImage(native,Point((n-t.fromFrame.frameNumber)*44,(row-1)*44))
  end
 end end
end
review:resize(review.width*3,review.height*3);review:saveAs(root..'/output/child_small_mario/contact.png')
print('Small Mario structure: '..index..' authored frames, '..#specs..' tags')
