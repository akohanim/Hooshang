-- One-time editable-source revision: slimmer children and an upright seated pose.
-- Ordinary future exports use build_child_hooshang_frames/import_jamshid_aseprite.
local root=assert(app.params.root);local pc=app.pixelColor
local function blank() return Image(88,88,ColorMode.RGB) end
local function full(layer,f) local im=blank();local c=layer:cel(f);if c then im:drawImage(c.image,c.position) end;return im end
local function rect(im,x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do im:putPixel(xx,yy,c) end end end
for i,name in ipairs({'hooshang_child','jamshid'}) do
 local path=root..'/assets/characters/'..name..'/aseprite/'..(i==1 and 'young_hooshang_movement.aseprite' or 'jamshid_child_movement.aseprite')
 local s=app.open(path);local layers={};for _,l in ipairs(s.layers) do layers[l.name]=l end
 local outfit=layers['Clothing and shoes'];local face=layers['Face hair and hands'];local detail=layers['Interior black details'];local outline=layers['Black outline - gameplay pixel'];local socks=layers['Socks - 1px marks']
 assert(outfit and face and detail and outline and socks)
 local backup=root..'/output/castle_authoring_reset/'..name..'_before.aseprite';assert(not app.fs.isFile(backup),'Already authored; do not overwrite later edits');s:saveCopyAs(backup)
 local idle={};for _,l in ipairs(s.layers) do idle[l.name]=full(l,1) end
 local palette=blank();palette:drawSprite(s,1)
 local shirt=palette:getPixel(36,48);local shirtLight=palette:getPixel(40,48);local pants=palette:getPixel(46,54);local boot=palette:getPixel(34,50);local skin=palette:getPixel(46,40);local skinLight=palette:getPixel(40,52)
 for f=1,#s.frames do
  local sitting=f==59 or f==60;local images={}
  for _,l in ipairs(s.layers) do
   local im=full(l,f)
   if sitting then
    im=blank()
    if l==face or l==detail then
     -- Same recognisable face, held upright instead of folding over the knees.
     for y=0,45 do for x=0,87 do im:putPixel(x,y+4,idle[l.name]:getPixel(x,y)) end end
    elseif l==outfit then
     rect(im,36,50,12,8,shirt);rect(im,38,50,4,6,shirtLight)
     rect(im,36,56,12,4,pants);rect(im,44,58,12,3,pants)
     rect(im,36,60,7,2,boot);rect(im,54,59,6,3,boot)
    elseif l==socks then
     im:putPixel(39,59,pc.rgba(255,255,255,255));im:putPixel(55,58,pc.rgba(255,255,255,255))
    end
    if l==face then
     rect(im,46,51,4,5,skin);rect(im,48,53,6,3,skinLight)
     if f==60 then -- quiet blink, not a whole-body bob
      for y=40,41 do for x=42,43 do im:putPixel(x,y,skin) end end
     end
    end
   end
   local slim=blank()
   if l==socks then
    for y=0,87 do for x=0,87 do local c=im:getPixel(x,y);if pc.rgbaA(c)>0 then slim:putPixel(math.floor(44+(x-44)*.85+.5),y,c) end end end
   elseif l~=outline then
    for y=0,87 do for x=0,87 do local sx=math.floor(44+(x-44)/.85+.5);if sx>=0 and sx<88 then slim:putPixel(x,y,im:getPixel(sx,y)) end end end
   end
   images[l.name]=slim
  end
  -- Maintain a real gameplay-pixel contour after narrowing; no filtered scaling.
  local body=blank();for _,l in ipairs(s.layers) do if l~=outline and l~=socks then body:drawImage(images[l.name]) end end
  local ink=images[outline.name]
  for y=3,84 do for x=3,84 do if pc.rgbaA(body:getPixel(x,y))>0 then
   for dy=-2,2 do for dx=-2,2 do if math.abs(dx)+math.abs(dy)<=3 then ink:putPixel(x+dx,y+dy,pc.rgba(0,0,0,255)) end end end
  end end end
  -- The outline layer sits above colours in these saved files, so only draw outside.
  for y=0,87 do for x=0,87 do if pc.rgbaA(body:getPixel(x,y))>0 then ink:putPixel(x,y,0) end end end
  for _,l in ipairs(s.layers) do local c=l:cel(f);if c then s:deleteCel(c) end;s:newCel(l,f,images[l.name],Point(0,0)) end
 end
 s:saveAs(path);print('Revised '..name..': '..#s.frames..' frames, upright sit, source layers/tags/timing preserved')
end
