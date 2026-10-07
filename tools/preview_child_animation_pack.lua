local root=assert(app.params.root)
local s=app.open(root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
local pc=app.pixelColor;local tags={};for _,t in ipairs(s.tags) do tags[t.name]=t end
local groups={{'idle'},{'run'},{'takeoff','rise','apex','fall','land','recover'},{'dash'},{'swim'},{'climb'}}
local holds={rise=.3,apex=.12,fall=.3,land=.055,recover=.065}
local sequences={}
for i,group in ipairs(groups) do
 local q={};local total=0
 for _,name in ipairs(group) do local t=tags[name]
  for n=t.fromFrame.frameNumber,t.toFrame.frameNumber do
   local dt=holds[name] and holds[name]/(t.toFrame.frameNumber-t.fromFrame.frameNumber+1) or s.frames[n].duration
   total=total+dt;q[#q+1]={frame=n,ending=total}
  end
 end
 sequences[i]={frames=q,total=total}
end
local anim=Sprite(6*44,44)
for tick=0,95 do
 if tick>0 then anim:newEmptyFrame() end
 local im=Image(264,44,ColorMode.RGB);im:clear(pc.rgba(165,178,168,255))
 for col,q in ipairs(sequences) do
  local phase=(tick/24)%q.total;local n=q.frames[#q.frames].frame
  for _,f in ipairs(q.frames) do if phase<f.ending then n=f.frame;break end end
  local full=Image(88,88,ColorMode.RGB);full:drawSprite(s,n)
  for y=0,43 do for x=0,43 do
   local c=full:getPixel(x*2,y*2)
   if pc.rgbaA(c)>0 then
    local dx,dy=x,y
    im:putPixel((col-1)*44+dx,dy,c)
   end
  end end
 end
 anim:newCel(anim.layers[1],tick+1,im,Point(0,0));anim.frames[tick+1].duration=1/24
end
anim:resize(1056,176)
anim:saveAs(root..'/output/child_animation_pack/animations.gif')
print('Preview: idle / run / jump arc / dash / swim / climb')
