-- Render review material and audit every cel in Aseprite, including .39 scale.
local root=app.params.root
local s=app.open(root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
local pc=app.pixelColor
local body,outline
for _,layer in ipairs(s.layers) do
 if layer.name=='Black outline - 1px' then outline=layer end
 if layer.name=='Young Hooshang movement' then body=layer end
end
assert(body and outline,'Expected 1px outline layer')
local function visible(c) return pc.rgbaA(c)>0 end
local function isBlack(c) return pc.rgbaR(c)==0 and pc.rgbaG(c)==0 and pc.rgbaB(c)==0 end
local function audit(im)
 local bad=0
 for y=1,im.height-2 do for x=1,im.width-2 do
  local c=im:getPixel(x,y)
  if visible(c) and not isBlack(c) then
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1},{-1,-1},{1,-1},{-1,1},{1,1}}) do
    if not visible(im:getPixel(x+d[1],y+d[2])) then bad=bad+1; break end
   end
  end
 end end
 return bad
end
local function native(im,phase)
 local small=Image(35,35,ColorMode.RGB)
 for y=0,34 do for x=0,34 do
  local sx,sy=math.floor((x+phase)/.39),math.floor((y+phase)/.39)
  if sx<88 and sy<88 then small:putPixel(x,y,im:getPixel(sx,sy)) end
 end end
 return small
end
local report={frames=#s.frames,source_gaps=0,outline_width_errors=0}
local contact=Sprite(8*38,#s.tags*38)
local bg=contact.cels[1].image
for y=0,bg.height-1 do for x=0,bg.width-1 do
 local c=(math.floor(x/8)+math.floor(y/8))%2==0 and 170 or 192
 bg:putPixel(x,y,pc.rgba(c,c,c,255))
end end
for n=1,#s.frames do
 local im=Image(88,88,ColorMode.RGB); im:drawSprite(s,n)
 report.source_gaps=report.source_gaps+audit(im)
 local ink=Image(88,88,ColorMode.RGB); local art=Image(88,88,ColorMode.RGB)
 ink:drawImage(outline:cel(n).image,outline:cel(n).position)
 art:drawImage(body:cel(n).image,body:cel(n).position)
 for y=1,86 do for x=1,86 do
  local expected=false
  if not visible(art:getPixel(x,y)) then
   for dy=-1,1 do for dx=-1,1 do
    if visible(art:getPixel(x+dx,y+dy)) then expected=true end
   end end
  end
  local c=ink:getPixel(x,y)
  if visible(c)~=expected or (visible(c) and not isBlack(c)) then report.outline_width_errors=report.outline_width_errors+1 end
 end end
end
for row,t in ipairs(s.tags) do
 for n=t.fromFrame.frameNumber,t.toFrame.frameNumber do
  local im=Image(88,88,ColorMode.RGB); im:drawSprite(s,n)
  bg:drawImage(native(im,0),Point((n-t.fromFrame.frameNumber)*38+1,(row-1)*38+1))
 end
 if t.name=='run' or t.name=='jump' or t.name=='wall_jump' or t.name=='swim' then
  local anim=Sprite(35,35)
  for n=t.fromFrame.frameNumber,t.toFrame.frameNumber do
   local f=n-t.fromFrame.frameNumber+1
   if f>1 then anim:newEmptyFrame() end
   local im=Image(88,88,ColorMode.RGB); im:drawSprite(s,n)
   local frame=Image(35,35,ColorMode.RGB); frame:clear(pc.rgba(180,185,175,255)); frame:drawImage(native(im,0))
   anim:newCel(anim.layers[1],f,frame,Point(0,0)); anim.frames[f].duration=s.frames[n].duration
  end
  anim:resize(210,210)
  anim:saveAs(root..'/output/child_outline/'..t.name..'.gif')
 end
end
contact:resize(contact.width*3,contact.height*3)
contact:saveAs(root..'/output/child_outline/all_frames.png')
local f=io.open(root..'/output/child_outline/audit.json','w'); f:write(json.encode(report)); f:close()
print(json.encode(report))
assert(report.source_gaps==0 and report.outline_width_errors==0,'Outline must be exactly one source pixel')
