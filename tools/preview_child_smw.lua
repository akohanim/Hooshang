-- Aseprite-only before/after review. Left: previous child; right: current child.
local root=assert(app.params.root)
local before=app.open(app.params.before or root..'/output/child_smw/before.aseprite')
local after=app.open(root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
local function tag(s,name) for _,t in ipairs(s.tags) do if t.name==name then return t end end end
local function sample(s,n)
 local full=Image(88,88,ColorMode.RGB);full:drawSprite(s,n)
 local im=Image(35,35,ColorMode.RGB)
 for y=0,34 do for x=0,34 do im:putPixel(x,y,full:getPixel(math.min(87,math.floor(x/.39)),math.min(87,math.floor(y/.39)))) end end
 return im
end
local function background(w,h)
 local im=Image(w,h,ColorMode.RGB)
 for y=0,h-1 do for x=0,w-1 do im:putPixel(x,y,app.pixelColor.rgba(213,204,175,255)) end end
 return im
end
local gif=Sprite(88,42)
for i=1,8 do
 if i>1 then gif:newEmptyFrame() end
 local im=background(88,42)
 im:drawImage(sample(before,tag(before,'run').fromFrame.frameNumber+i-1),Point(3,2))
 im:drawImage(sample(after,tag(after,'run').fromFrame.frameNumber+i-1),Point(47,2))
 gif:newCel(gif.layers[1],i,im,Point(0,0));gif.frames[i].duration=after.frames[tag(after,'run').fromFrame.frameNumber+i-1].duration
end
gif:resize(528,252);gif:saveAs(root..'/output/child_smw/'..(app.params.output or 'run_comparison.gif'))
local sheet=Sprite(8*44,5*44)
local im=background(sheet.width,sheet.height)
for row,name in ipairs({'idle','run','jump','fall','swim'}) do
 local t=tag(after,name);local count=t.toFrame.frameNumber-t.fromFrame.frameNumber+1
 for i=1,math.min(8,count) do im:drawImage(sample(after,t.fromFrame.frameNumber+i-1),Point((i-1)*44+4,(row-1)*44+4)) end
end
sheet:newCel(sheet.layers[1],1,im,Point(0,0));sheet:resize(sheet.width*3,sheet.height*3);sheet:saveAs(root..'/output/child_smw/movement.png')
-- Enlarged editable source pose for checking facial clusters.
local pose=Sprite(40,46)
local full=Image(88,88,ColorMode.RGB);full:drawSprite(after,1)
pose:newCel(pose.layers[1],1,Image(full,Rectangle(26,21,40,46)),Point(0,0))
pose:resize(240,276);pose:saveAs(root..'/output/child_smw/idle_detail.png')
