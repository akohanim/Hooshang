local root=assert(app.params.root)
local f=io.open(root..'/output/child_small_mario/reference_poses.json');local refs=json.decode(f:read('*a'));f:close()
f=io.open('/tmp/hooshang-smw-study/art_frames.json');local ref=json.decode(f:read('*a'));f:close()
local s=app.open(root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
local tags={};for _,t in ipairs(s.tags) do tags[t.name]=t end
local rgb=app.pixelColor.rgba
local colors={};for k,v in pairs(ref.palette) do colors[tonumber(k)]=rgb(v[1],v[2],v[3],255) end
local gif=Sprite(80,42)
for i,pose in ipairs({0,1}) do
 if i>1 then gif:newEmptyFrame() end
 local im=Image(80,42,ColorMode.RGB)
 for y=0,41 do for x=0,79 do im:putPixel(x,y,rgb(218,213,191,255)) end end
 for y,row in ipairs(refs[pose+1].pixels) do for x,v in ipairs(row) do if v>0 then im:putPixel(12+x,2+y-(i==2 and 1 or 0),colors[v]) end end end
 local full=Image(88,88,ColorMode.RGB);full:drawSprite(s,tags.run.fromFrame.frameNumber+i-1)
 for y=0,43 do for x=0,43 do
  local c=full:getPixel(x*2,y*2)
  if app.pixelColor.rgbaA(c)>0 and 30+x<80 and 2+y<42 then im:putPixel(30+x,2+y,c) end
 end end
 gif:newCel(gif.layers[1],i,im,Point(0,0));gif.frames[i].duration=.1
end
gif:resize(560,294);gif:saveAs(root..'/output/child_small_mario/reference_comparison.gif')
-- A source-resolution close-up; the game uses one pixel for each 2x2 cluster.
local pose=Sprite(40,48);local full=Image(88,88,ColorMode.RGB);full:drawSprite(s,1)
pose:newCel(pose.layers[1],1,Image(full,Rectangle(24,20,40,48)),Point(0,0))
pose:resize(240,288);pose:saveAs(root..'/output/child_small_mario/idle_detail.png')
