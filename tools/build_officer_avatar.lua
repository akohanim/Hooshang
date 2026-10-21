-- One-time native Aseprite authoring tool. Ordinary edits belong in the .aseprite
-- source; use import_officer_aseprite.py to export WITHOUT regenerating the art.
local root=app.params.root or '/Users/ari/Hooshang_claude'
local base=root..'/assets/characters/officer/'
app.fs.makeAllDirectories(base..'aseprite')
app.fs.makeAllDirectories(base..'sprites')
local reference=Image{fromFile=base..'portraits/officer_stern.png'}
local rgba=app.pixelColor.rgba
local function rgb(p)return app.pixelColor.rgbaR(p),app.pixelColor.rgbaG(p),app.pixelColor.rgbaB(p)end
-- Extract spaced dominant colors from the approved portrait, rather than
-- tinting the old turquoise placeholder. Art geometry is native pixel drawing.
local function ramp(box,predicate,count)
 local counts={}
 for y=box[2],box[4] do for x=box[1],box[3] do
  local p=reference:getPixel(x,y);local r,g,b=rgb(p)
  if predicate(r,g,b) then counts[p]=(counts[p] or 0)+1 end
 end end
 local ranked={};for p,n in pairs(counts) do ranked[#ranked+1]={p=p,n=n} end
 table.sort(ranked,function(a,b)if a.n==b.n then return a.p<b.p end return a.n>b.n end)
 local selected={}
 for _,v in ipairs(ranked) do
  local r,g,b=rgb(v.p);local distinct=true
  for _,p in ipairs(selected) do local rr,gg,bb=rgb(p);if (r-rr)^2+(g-gg)^2+(b-bb)^2<200 then distinct=false;break end end
  if distinct then selected[#selected+1]=v.p end
  if #selected==count then break end
 end
 assert(#selected==count,'Portrait ramp has too few colors')
 table.sort(selected,function(a,b)local r,g,bb=rgb(a);local rr,gg,bbb=rgb(b);return r+g+bb<rr+gg+bbb end)
 return selected
end
local olive=ramp({10,15,490,165},function(r,g,b)return g>=r-3 and r>b*1.25 and g>b*1.3 and g<110 and r>25 end,6)
local skin=ramp({140,170,365,315},function(r,g,b)return r>175 and g>65 and g<190 and r>g*1.4 and g>b*1.3 end,6)
local beard=ramp({125,305,390,435},function(r,g,b)return r>15 and r<115 and math.max(r,g,b)-math.min(r,g,b)<35 end,5)
local gold=ramp({220,20,295,100},function(r,g,b)return r>190 and g>100 and g<225 and r>g*1.1 and g>b*1.4 end,4)
local cream=ramp({195,435,310,488},function(r,g,b)return r>170 and g>130 and b>80 and r>g and g>b and r-g<70 end,4)
local grey=ramp({190,360,310,428},function(r,g,b)return r>105 and r<160 and math.max(r,g,b)-math.min(r,g,b)<40 end,3)
local ink=beard[1]
local function pixel(im,x,y,c)if x>=0 and x<32 and y>=0 and y<48 then im:drawPixel(x,y,c) end end
local function rect(im,x1,y1,x2,y2,c)for y=y1,y2 do for x=x1,x2 do pixel(im,x,y,c) end end end
local function line(im,x1,y1,x2,y2,c)
 local dx,dy=math.abs(x2-x1),-math.abs(y2-y1);local sx=x1<x2 and 1 or -1;local sy=y1<y2 and 1 or -1;local err=dx+dy
 while true do pixel(im,x1,y1,c);if x1==x2 and y1==y2 then break end;local e=err*2;if e>=dy then err=err+dy;x1=x1+sx end;if e<=dx then err=err+dx;y1=y1+sy end end
end
local function poly(im,points,c)
 for y=0,47 do
  local intersections={}
  for i,a in ipairs(points) do local b=points[i%#points+1]
   if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then intersections[#intersections+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2]) end
  end
  table.sort(intersections)
  for i=1,#intersections-1,2 do for x=math.ceil(intersections[i]),math.floor(intersections[i+1]) do pixel(im,x,y,c) end end
 end
 for i,a in ipairs(points) do local b=points[i%#points+1];line(im,a[1],a[2],b[1],b[2],c) end
end
local s=Sprite(32,48,ColorMode.RGB)
local names={'Far arm','Trousers and boots','Olive tunic and brass','Face beard and peaked cap','Near arm and gesture'}
local layers={};s:deleteLayer(s.layers[1])
for _,name in ipairs(names) do layers[name]=s:newLayer();layers[name].name=name end
local tags={{name='idle',count=4,duration=.25},{name='walk',count=8,duration=.10},{name='talk',count=4,duration=.14}}
local frame=0
local ranges={}
for _,tag in ipairs(tags) do
 local first=frame+1
 for pose=0,tag.count-1 do
  frame=frame+1;while #s.frames<frame do s:newEmptyFrame() end
  s.frames[frame].duration=tag.duration
  local walking=tag.name=='walk';local talking=tag.name=='talk'
  local bob=walking and ({0,-1,-1,0,0,-1,-1,0})[pose+1] or 0
  local stride=walking and ({-2,-3,-2,0,2,3,2,0})[pose+1] or 0
  local lift=walking and ({0,0,-1,-2,-1,0,0,0})[pose+1] or 0
  local images={};for _,name in ipairs(names) do images[name]=Image(32,48,ColorMode.RGB) end
  local im=images['Trousers and boots']
  -- Opposed strides, bent knees, boot soles remain on one floor plane.
  for _,leg in ipairs({{18,-stride,walking and (lift==0 and -1 or 0) or 0},{12,stride,lift}}) do
   local x,step,up=leg[1],leg[2],leg[3]
   poly(im,{{x-1,36+bob},{x+4,36+bob},{x+3+step,44+up},{x-1+step,44+up}},ink)
   line(im,x+1,38+bob,x+1+step,43+up,olive[2]);line(im,x+2,39+bob,x+2+step,44+up,olive[3])
   rect(im,x-3+step,44+up,x+3+step,47+up,ink)
   line(im,x-2+step,44+up,x+2+step,44+up,beard[4]);line(im,x-2+step,45+up,x+step,45+up,grey[1])
  end
  im=images['Far arm']
  local swing=walking and math.floor(stride/2) or 0
  poly(im,{{21,26+bob},{25,27+bob},{26-swing,35+bob},{23-swing,37+bob},{21,31+bob}},ink)
  line(im,23,28+bob,24-swing,34+bob,olive[3]);rect(im,23-swing,35+bob,25-swing,37+bob,skin[2])
  im=images['Olive tunic and brass']
  poly(im,{{10,25+bob},{21,25+bob},{24,29+bob},{23,38+bob},{8,38+bob},{8,29+bob}},ink)
  poly(im,{{11,26+bob},{20,26+bob},{22,29+bob},{21,36+bob},{10,36+bob},{10,29+bob}},olive[3])
  rect(im,11,28+bob,14,35+bob,olive[5]);line(im,10,29+bob,10,35+bob,olive[6])
  poly(im,{{12,25+bob},{20,25+bob},{16,31+bob}},cream[3])
  poly(im,{{15,26+bob},{17,26+bob},{17,30+bob},{16,32+bob},{15,30+bob}},ink)
  line(im,11,27+bob,14,31+bob,olive[2]);line(im,21,27+bob,18,31+bob,olive[1])
  rect(im,8,26+bob,11,27+bob,gold[2]);pixel(im,9,26+bob,gold[4])
  rect(im,21,26+bob,24,27+bob,gold[2]);pixel(im,22,26+bob,gold[4])
  rect(im,11,32+bob,14,33+bob,olive[2]);line(im,11,32+bob,14,32+bob,olive[6]);pixel(im,12,33+bob,gold[2])
  rect(im,18,32+bob,21,33+bob,olive[2]);pixel(im,19,32+bob,gold[3])
  rect(im,9,36+bob,22,38+bob,ink);rect(im,14,36+bob,17,38+bob,gold[2]);rect(im,15,37+bob,16,37+bob,beard[2])
  im=images['Face beard and peaked cap']
  local function r(x1,y1,x2,y2,c)rect(im,x1,y1+bob,x2,y2+bob,c)end
  local function p(x,y,c)pixel(im,x,y+bob,c)end
  local function l(x1,y1,x2,y2,c)line(im,x1,y1+bob,x2,y2+bob,c)end
  -- Warm skin, substantial jaw beard, grey strands at sideburns and chin.
  poly(im,{{10,10+bob},{22,10+bob},{24,14+bob},{23,22+bob},{20,26+bob},{13,26+bob},{9,22+bob},{8,16+bob}},ink)
  r(10,11,21,21,skin[3]);r(11,12,17,19,skin[5]);r(22,14,24,18,skin[2]);p(23,15,skin[5])
  r(8,16,10,18,skin[2]);r(8,17,9,18,skin[5]);p(7,18,skin[1])
  r(10,11,11,14,beard[2]);r(21,11,22,15,beard[2])
  l(11,14,14,15,ink);l(17,15,20,14,ink)
  local blink=tag.name=='idle' and pose==3
  if blink then l(11,16,13,16,beard[2]);l(17,16,19,16,beard[2])
  else r(11,16,14,17,cream[4]);r(17,16,20,17,cream[4]);r(11,16,12,17,ink);r(17,16,18,17,ink);p(12,16,cream[4]);p(18,16,cream[4]) end
  l(10,18,9,19,skin[2]);p(9,19,skin[6]);p(10,20,skin[1]);p(15,18,skin[6])
  poly(im,{{10,18+bob},{12,20+bob},{19,20+bob},{21,18+bob},{23,18+bob},{23,23+bob},{20,26+bob},{13,26+bob},{10,24+bob}},beard[2])
  r(12,20,20,22,ink);r(13,22,19,23,skin[2]);p(14,22,skin[5])
  l(12,20,15,19,ink);l(16,19,20,20,ink)
  if talking and pose%2==1 then r(14,22,18,23,ink);r(15,23,17,23,skin[1]) else l(14,22,18,22,beard[3]) end
  p(10,21,beard[4]);p(11,23,beard[3]);p(22,21,beard[4]);p(21,24,beard[3])
  p(12,24,grey[1]);p(14,24,beard[5]);p(15,25,grey[2]);p(17,24,grey[1]);p(18,25,grey[3]);p(20,23,beard[5]);p(22,19,grey[1])
  -- Olive peaked cap with gold band, central badge, dark polished visor.
  poly(im,{{8,4+bob},{12,2+bob},{22,2+bob},{26,5+bob},{25,9+bob},{7,9+bob},{6,6+bob}},ink)
  poly(im,{{9,4+bob},{13,3+bob},{21,3+bob},{24,5+bob},{24,7+bob},{8,7+bob}},olive[4])
  l(10,4,20,3,olive[6]);r(8,7,24,8,gold[1]);l(9,7,23,7,gold[3])
  r(15,4,17,6,gold[2]);p(16,3,gold[4]);p(16,5,gold[4]);p(14,5,gold[1]);p(18,5,gold[1])
  poly(im,{{7,9+bob},{24,9+bob},{22,11+bob},{7,11+bob},{5,10+bob}},ink)
  l(8,9,21,9,beard[4]);l(8,10,14,10,beard[3]);p(24,8,gold[4])
  im=images['Near arm and gesture']
  if talking then
   poly(im,{{9,27+bob},{10,31+bob},{7,32+bob},{3,29+bob},{4,26+bob}},ink)
   line(im,8,28+bob,5,28+bob,olive[5]);line(im,5,28+bob,3,27+bob,olive[3])
   rect(im,1,25+bob,4,27+bob,skin[2]);line(im,0,25+bob,4,25+bob,skin[5]);pixel(im,3,26+bob,skin[6])
  else
   poly(im,{{8,27+bob},{11,28+bob},{10+swing,35+bob},{7+swing,37+bob},{6,32+bob}},ink)
   line(im,8,29+bob,8+swing,34+bob,olive[5]);line(im,7,29+bob,7+swing,33+bob,olive[6])
   rect(im,7+swing,35+bob,10+swing,37+bob,skin[2]);line(im,7+swing,35+bob,9+swing,35+bob,skin[5])
  end
  for _,name in ipairs(names) do s:newCel(layers[name],frame,images[name],Point(0,0)) end
 end
 local t=s:newTag(first,frame);t.name=tag.name;t.aniDir=AniDir.FORWARD
 ranges[#ranges+1]={tag=t,first=first,last=frame}
end
-- Aseprite extends tags when appending at their last frame. Restore authored
-- ranges after all frames exist so idle/walk never absorb later animations.
for _,range in ipairs(ranges) do range.tag.fromFrame=range.first;range.tag.toFrame=range.last end
s:saveAs(base..'aseprite/officer_movement.aseprite')
print('Authored officer: 32x48, '..#s.frames..' frames, 5 editable layers, idle/walk/talk tags')
