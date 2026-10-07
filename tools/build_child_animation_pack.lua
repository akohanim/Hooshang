-- Expand the approved child design; do not regenerate character geometry/palette.
-- Input is the saved pre-expansion Aseprite snapshot. All edits are native pixels.
local root=assert(app.params.root)
local src=app.open(root..'/output/child_animation_pack/approved_design.aseprite')
local pc=app.pixelColor
local function blank() return Image(88,88,ColorMode.RGB) end
local tags={};for _,t in ipairs(src.tags) do tags[t.name]=t.fromFrame.frameNumber end
local specs={}
local function frame(tag,i,time,edit) return {source=tags[tag]+(i or 1)-1,time=time or .1,edit=edit or {}} end
local function clip(name,frames) specs[#specs+1]={name=name,frames=frames} end
clip('idle',{frame('idle',1,2.4),frame('idle',1,.065,{blink=1}),frame('idle',1,.085,{blink=2}),frame('idle',1,.065,{blink=1}),frame('idle',1,.85)})
clip('run',{frame('run',1,.1),frame('run',2,.1)})
clip('sprint',{frame('dash',1,.05),frame('dash',2,.05,{dy=-2})})
clip('skid',{frame('wall_slide',1,.07),frame('wall_slide',1,.07,{lean=-1})})
clip('takeoff',{frame('idle',1,.025,{compress=.90}),frame('jump',1,.035)})
clip('rise',{frame('jump',1,.12)})
clip('jump',{frame('jump',1,.06,{lean=1}),frame('jump',1,.12)})
clip('apex',{frame('jump',1,.1,{compress=.94})})
clip('fall',{frame('fall',1,.08,{compress=.95}),frame('fall',1,.14)})
clip('land',{frame('idle',1,.025,{compress=.84}),frame('idle',1,.030,{compress=.90})})
clip('recover',{frame('idle',1,.030,{compress=.95}),frame('idle',1,.035)})
clip('dash',{frame('dash',1,.035,{lean=3}),frame('dash',2,.055,{lean=5}),frame('dash',1,.060,{lean=4})})
clip('wall_slide',{frame('wall_slide',1,.18),frame('wall_slide',1,.18,{compress=.97})})
clip('wall_jump',{frame('jump',1,.04,{lean=4}),frame('jump',1,.06,{lean=2}),frame('jump',1,.12)})
clip('climb',{frame('climb',1,.12),frame('climb',1,.08,{dy=-1}),frame('climb',2,.12),frame('climb',2,.08,{dy=-1})})
clip('climb_down',{frame('climb',2,.12,{dy=-1}),frame('climb',2,.08),frame('climb',1,.12,{dy=-1}),frame('climb',1,.08)})
clip('climb_idle',{frame('climb',1,.4)})
-- Measured underwater cycle: reach 12 ticks, pull 4, kick 8 at 60 Hz.
clip('swim',{frame('swim',4,4/60),frame('swim',2,4/60),frame('swim',3,4/60),frame('swim',1,12/60)})
clip('swim_idle',{frame('swim',1,.4),frame('swim',1,.4)})
clip('exit_water',{frame('jump',1,.07,{lean=3}),frame('jump',1,.07,{lean=1}),frame('exit_water',3,.09,{compress=.88}),frame('exit_water',4,.09),frame('run',2,.08),frame('idle',1,.1)})
clip('ledge_climb',{frame('jump',1,.04,{lean=3}),frame('jump',1,.04,{lean=1}),frame('ledge_climb',3,.04,{compress=.88}),frame('ledge_climb',4,.04),frame('run',2,.04),frame('idle',1,.04)})
clip('sit',{frame('sit',1,.18),frame('sit',2,.18)})
clip('crouch',{frame('sit',1,.2)})
clip('wall_land',{frame('sit',1,.12),frame('sit',2,.18)})
local s=Sprite(88,88);s:deleteLayer(s.layers[1])
local layers={}
for _,l in ipairs(src.layers) do local dst=s:newLayer();dst.name=l.name;layers[l.name]=dst end
local n=0;local manifest={}
for _,spec in ipairs(specs) do
 local first=n+1
 for _,f in ipairs(spec.frames) do
  n=n+1;if n>1 then s:newEmptyFrame() end
  local ims={}
  for _,layer in ipairs(src.layers) do
   local im=blank();local cel=layer:cel(f.source)
   if layer.name~='Black outline - 1px' then
    for y=0,cel.image.height-1 do for x=0,cel.image.width-1 do
     local c=cel.image:getPixel(x,y)
     if pc.rgbaA(c)>0 then
      local sx,sy=x+cel.position.x,y+cel.position.y
      local dy=64-math.floor((64-sy)*(f.edit.compress or 1))+(f.edit.dy or 0)
      local dx=sx+math.floor((f.edit.lean or 0)*math.max(0,60-sy)/36)
      assert(dx>0 and dx<87 and dy>0 and dy<87,'Clipped authored frame')
      im:putPixel(dx,dy,c)
     end
    end end
   end
   ims[layer.name]=im
  end
  if f.edit.blink then
   local skin=ims['Face hair and hands'];local detail=ims['Interior black details']
   for y=34,37 do for x=42,49 do
    local c=detail:getPixel(x,y)
    if pc.rgbaA(c)>0 and (f.edit.blink==2 or y<36) then
     detail:putPixel(x,y,0);skin:putPixel(x,y,pc.rgba(255,200,139,255))
    end
   end end
   if f.edit.blink==2 then for _,x0 in ipairs({42,46}) do for x=x0,x0+1 do detail:putPixel(x,37,pc.rgba(87,48,36,255)) end end end
  end
  local body=blank()
  for _,l in ipairs(src.layers) do if l.name~='Black outline - 1px' and l.name~='Socks - 1px marks' then body:drawImage(ims[l.name]) end end
  local ring=ims['Black outline - 1px']
  for y=1,86 do for x=1,86 do
   if pc.rgbaA(body:getPixel(x,y))==0 then
    local adjacent=false
    for dy=-1,1 do for dx=-1,1 do if pc.rgbaA(body:getPixel(x+dx,y+dy))>0 then adjacent=true end end end
    if adjacent then ring:putPixel(x,y,pc.rgba(0,0,0,255)) end
   end
  end end
  for _,l in ipairs(src.layers) do s:newCel(layers[l.name],n,ims[l.name],Point(0,0)) end
  s.frames[n].duration=f.time
 end
 manifest[#manifest+1]={name=spec.name,first=first,last=n}
end
for _,r in ipairs(manifest) do local t=s:newTag(r.first,r.last);t.name=r.name end
s:saveAs(root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
local out=assert(io.open(root..'/output/child_animation_pack/tags.json','w'));out:write(json.encode(manifest));out:close()
print('Authored '..n..' editable frames in '..#specs..' tags, using approved design')
