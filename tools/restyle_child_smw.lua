-- One-time art direction pass, executed entirely by Aseprite's raster API.
-- Future hand edits: edit the .aseprite, then build_child_hooshang_frames.py.
-- Preserve the 88px canvas, .39 runtime scale, baseline, tags and socks contract.
local root=assert(app.params.root)
local path=root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite'
local source=app.open(root..'/output/child_smw/before.aseprite')
local specs={}
for _,t in ipairs(source.tags) do table.insert(specs,{name=t.name,count=t.toFrame.frameNumber-t.fromFrame.frameNumber+1,dir=t.aniDir}) end
local pc=app.pixelColor
local function c(r,g,b) return pc.rgba(r,g,b,255) end
local P={ink=c(0,0,0),hair=c(28,29,40),hairMid=c(48,49,65),hairHi=c(77,77,94),
 skin=c(239,163,94),skinHi=c(255,203,135),skinShade=c(192,105,66),eye=c(255,248,215),
 jacket=c(151,79,46),jacketHi=c(191,111,62),jacketShade=c(102,52,42),
 shirt=c(137,200,211),shirtHi=c(198,233,225),shirtShade=c(73,131,159),
 pants=c(75,49,78),pantsHi=c(112,67,95),pantsShade=c(47,34,58),
 shoe=c(113,53,35),shoeHi=c(182,94,48),sole=c(60,35,37),white=c(255,255,255)}
local function blank() return Image(88,88,ColorMode.RGB) end
local function rect(im,x,y,w,h,color)
 x=math.floor(x+.5);y=math.floor(y+.5)
 for yy=y,y+h-1 do for xx=x,x+w-1 do if xx>=0 and yy>=0 and xx<88 and yy<88 then im:putPixel(xx,yy,color) end end end
end
local function oval(im,x,y,w,h,color)
 for yy=0,h-1 do for xx=0,w-1 do
  if ((xx+.5-w/2)/(w/2))^2+((yy+.5-h/2)/(h/2))^2<=1 then rect(im,x+xx,y+yy,1,1,color) end
 end end
end
local function line(im,a,b,w,color)
 local steps=math.max(math.abs(a[1]-b[1]),math.abs(a[2]-b[2]))
 for i=0,steps do local t=steps==0 and 0 or i/steps
  rect(im,a[1]+(b[1]-a[1])*t-math.floor(w/2),a[2]+(b[2]-a[2])*t-math.floor(w/2),w,w,color)
 end
end
local s=Sprite(88,88)
s.layers[1].name='Black outline - 1px'
local layers={outline=s.layers[1]}
for _,v in ipairs({{'rear','Rear limbs'},{'body','Young Hooshang movement'},{'head','Face and hair'},{'front','Front limbs'},{'socks','Socks - 1px marks'}}) do
 layers[v[1]]=s:newLayer();layers[v[1]].name=v[2]
end
local function arm(im,shoulder,elbow,hand,front)
 line(im,shoulder,elbow,5,front and P.jacket or P.jacketShade)
 line(im,elbow,hand,4,front and P.jacketHi or P.jacket)
 oval(im,hand[1]-3,hand[2]-3,6,6,P.jacketShade)
 oval(im,hand[1]-2,hand[2]-2,5,5,front and P.skin or P.skinShade)
 if front then rect(im,hand[1],hand[2]-2,2,2,P.skinHi) end
end
local function leg(im,hip,knee,foot,front,socks)
 line(im,hip,knee,5,front and P.pants or P.pantsShade)
 line(im,knee,{foot[1],foot[2]-3},4,front and P.pants or P.pantsShade)
 if front then line(im,{hip[1]+1,hip[2]},{knee[1]+1,knee[2]-1},2,P.pantsHi) end
 oval(im,foot[1]-2,foot[2]-3,6,4,front and P.shoe or P.sole)
 rect(im,foot[1]-2,foot[2],6,1,P.sole)
 if front then rect(im,foot[1],foot[2]-3,3,2,P.shoeHi) end
 table.insert(socks,{foot[1],foot[2]-4})
end
local function upper(body,head,dx,dy,blink)
 -- Short cardigan, blue collar and a deliberately open front.
 oval(body,37+dx,43+dy,15,11,P.jacketShade)
 rect(body,38+dx,43+dy,12,9,P.jacket)
 rect(body,38+dx,44+dy,3,6,P.jacketHi)
 rect(body,43+dx,43+dy,7,8,P.shirtShade)
 rect(body,44+dx,43+dy,5,7,P.shirt)
 rect(body,42+dx,43+dy,3,3,P.shirtHi)
 rect(body,48+dx,43+dy,3,2,P.shirtHi)
 -- Rounded three-quarter face with forehead, cheeks and two compact eyes.
 oval(head,34+dx,29+dy,21,15,P.skinShade)
 oval(head,37+dx,29+dy,18,14,P.skin)
 oval(head,40+dx,29+dy,13,10,P.skinHi)
 oval(head,34+dx,35+dy,5,6,P.skin)
 rect(head,35+dx,37+dy,2,2,P.skinShade)
 rect(head,53+dx,36+dy,3,3,P.skin)
 -- The curl sweeps down one side; highlights follow the sweep, not bars.
 oval(head,34+dx,25+dy,20,9,P.hair)
 oval(head,39+dx,25+dy,13,6,P.hair)
 rect(head,37+dx,25+dy,5,3,P.hair)
 oval(head,33+dx,28+dy,8,9,P.hair)
 rect(head,36+dx,33+dy,3,4,P.hair)
 oval(head,37+dx,26+dy,10,5,P.hairMid)
 oval(head,41+dx,25+dy,9,4,P.hairMid)
 rect(head,40+dx,26+dy,4,2,P.hairHi)
 oval(head,46+dx,28+dy,7,4,P.hair)
 rect(head,48+dx,30+dy,3,2,P.hair)
 rect(head,49+dx,32+dy,2,1,P.hair)
 -- Actual runtime samples source rows 34, 36, 39 and 42 here.
 -- Keep row 36 skin-coloured: pupils must not connect to the hair at native size.
 rect(head,39+dx,34+dy,13,3,P.skinHi)
 if blink then
  rect(head,40+dx,39+dy,4,1,P.skinShade)
  rect(head,47+dx,39+dy,5,1,P.skinShade)
 else
  rect(head,40+dx,38+dy,4,3,P.eye)
  rect(head,42+dx,38+dy,2,3,P.hair)
  rect(head,47+dx,38+dy,5,3,P.eye)
  rect(head,50+dx,38+dy,2,3,P.hair)
 end
 rect(head,45+dx,38+dy,2,3,P.skin)
 rect(head,44+dx,42+dy,5,1,P.skinShade)
 rect(head,49+dx,41+dy,2,1,P.skinShade)

end

local stride={
 {{37,56},{33,62},{49,55},{54,62}},
 {{39,57},{37,63},{48,54},{52,60}},
 {{42,57},{42,63},{51,52},{48,57}},
 {{48,55},{52,61},{41,54},{35,59}},
 {{49,55},{54,62},{37,56},{33,62}},
 {{48,54},{52,60},{39,57},{37,63}},
 {{50,52},{48,57},{43,57},{43,63}},
 {{41,54},{35,59},{48,55},{52,61}}}
local index=0
local ranges={}
for _,spec in ipairs(specs) do
 local first=index+1
 for i=1,spec.count do
  index=index+1;if index>1 then s:newEmptyFrame() end
  local im={};for key,_ in pairs(layers) do im[key]=blank() end
  local socks={};local dx,dy=0,0
  local rk,rf,fk,ff={40,56},{40,62},{47,56},{48,62}
  local re,rh,fe,fh={35,47},{36,50},{51,47},{51,50}
  local duration=.12;local blink=false
  local name=spec.name
  if name=='idle' then
   dy=0;blink=i==5
   duration=({.65,.16,.24,.55,.075,.12})[i]
  elseif name=='run' then
   local p=stride[i];rk,rf,fk,ff=p[1],p[2],p[3],p[4]
   dy=0;dx=0
   local arms={
    {{51,44},{53,40},{40,48},{36,45}},
    {{48,44},{51,41},{42,49},{39,46}},
    {{43,44},{40,42},{50,47},{53,44}},
    {{36,44},{34,41},{54,44},{56,39}},
    {{35,46},{33,43},{54,43},{56,39}},
    {{38,47},{36,44},{52,45},{54,42}},
    {{47,47},{50,44},{42,48},{39,45}},
    {{51,44},{53,40},{40,48},{36,44}}}
   re,rh,fe,fh=table.unpack(arms[i])
   duration=({.085,.07,.06,.085,.085,.07,.06,.085})[i]
  elseif name=='jump' or name=='wall_jump' then
   local poses={
    {{39,55},{36,62},{49,55},{52,62},{34,48},{32,45},{53,43},{55,39},2},
    {{38,52},{34,57},{50,51},{48,55},{33,44},{30,40},{54,37},{54,30},0},
    {{40,52},{38,56},{51,51},{48,54},{34,44},{32,41},{54,38},{56,33},0},
    {{40,54},{38,59},{50,54},{51,59},{33,43},{31,40},{55,42},{58,38},0}}
   local p=poses[i];rk,rf,fk,ff,re,rh,fe,fh,dy=table.unpack(p)
   duration=i==1 and .045 or .075
  elseif name=='fall' then
   local poses={
    {{40,54},{37,59},{49,54},{51,59},{32,45},{29,41},{56,44},{57,37}},
    {{40,55},{38,61},{49,55},{52,61},{33,46},{30,43},{56,46},{59,40}},
    {{40,56},{39,62},{48,56},{51,62},{34,48},{31,45},{55,47},{58,43}},
    {{40,55},{38,61},{49,55},{52,61},{33,46},{30,43},{56,46},{59,40}}}
   rk,rf,fk,ff,re,rh,fe,fh=table.unpack(poses[i])
  elseif name=='dash' then
   dx=6;dy=3;rk={37,55};rf={30+(i%2),58};fk={41,56};ff={35,62}
   re={40,46};rh={35,43};fe={57,47};fh={60,44};duration=.029
  elseif name=='wall_slide' then
   dx=2;dy=1;rk={43,55};rf={45,62};fk={50,51};ff={53,55}
   re={53,37};rh={57,33};fe={54,43};fh={58,40};duration=.14
  elseif name=='climb' then
   local a=math.floor(math.sin((i-1)*math.pi/3)*3)
   rk={40,53+a};rf={38,57+a};fk={51,53-a};ff={53,57-a}
   re={35,36-a};rh={36,31-a};fe={54,36+a};fh={55,31+a};duration=.09
  elseif name=='swim' then
   local p=(i-1)*math.pi/4;local a=math.floor(math.sin(p)*4)
   rk={40,55};rf={37+a,61};fk={48,55};ff={50-a,61}
   rh={math.floor(36+8*math.sin(p)),math.floor(40-12*math.cos(p))}
   fh={math.floor(52+8*math.sin(p+math.pi)),math.floor(40-12*math.cos(p+math.pi))}
   re={(38+rh[1])/2,(43+rh[2])/2};fe={(49+fh[1])/2+2,(43+fh[2])/2};duration=.1
  elseif name=='swim_idle' then
   dy=i%2;rk={38,55};rf={35+i%2,59};fk={51,54};ff={53-i%2,58}
   re={33,45};rh={31,42};fe={55,45};fh={58,42};duration=.2
  elseif name=='sit' then
   dy=7+(i==3 and 1 or 0);rk={44,60};rf={49,62};fk={50,58};ff={56,62}
   re={36,56};rh={38,60};fe={52,55};fh={53,58};duration=.18;blink=i==5
  elseif name=='exit_water' or name=='ledge_climb' then
   local t=(i-1)/(spec.count-1);dy=math.floor(8*(1-t));dx=math.floor(-3*(1-t))
   rk={39,56+dy/2};rf={36+math.floor(t*4),62};fk={49,53+dy/2};ff={52-math.floor(t*4),57+math.floor(t*5)}
   re={35,47+dy};rh={37,53+dy};fe={53,44+dy};fh={56,47+dy}
   duration=name=='ledge_climb' and .04 or .072
  end
  leg(im.rear,{40+dx,51+dy},rk,rf,false,socks)
  arm(im.rear,{38+dx,43+dy},re,rh,false)
  upper(im.body,im.head,dx,dy,blink)
  leg(im.front,{47+dx,51+dy},fk,ff,true,socks)
  arm(im.front,{49+dx,43+dy},fe,fh,true)
  -- Outline the union, leaving internal colour clusters clean and editable.
  local union=blank()
  for _,key in ipairs({'rear','body','head','front'}) do union:drawImage(im[key]) end
  for y=1,86 do for x=1,86 do
   if pc.rgbaA(union:getPixel(x,y))==0 then
    local adjacent=false
    for yy=-1,1 do for xx=-1,1 do if pc.rgbaA(union:getPixel(x+xx,y+yy))>0 then adjacent=true end end end
    if adjacent then im.outline:putPixel(x,y,P.ink) end
   end
  end end
  for _,p in ipairs(socks) do im.socks:putPixel(p[1],p[2],P.white) end
  for key,layer in pairs(layers) do s:newCel(layer,index,im[key],Point(0,0)) end
  s.frames[index].duration=duration
 end
 table.insert(ranges,{first=first,last=index,name=spec.name,dir=spec.dir})
end
for _,r in ipairs(ranges) do local tag=s:newTag(r.first,r.last);tag.name=r.name;tag.aniDir=r.dir end
s:saveAs(path)
print('Re-authored '..index..' child frames in '..#specs..' editable tags; six layers.')
