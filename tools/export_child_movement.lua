-- Re-export approved editable source. Never regenerate poses from old image strips.
local root=app.params.root or '/Users/ari/Hooshang_claude'
local base=root..'/assets/characters/hooshang_child/'
local s=app.open(base..'aseprite/young_hooshang_movement.aseprite')
local sock_layer
for _,layer in ipairs(s.layers) do if layer.name=='Socks - 1px marks' then sock_layer=layer end end
assert(sock_layer,'Missing Aseprite socks layer')
local socks={}
for n=1,#s.frames do
 local cel=assert(sock_layer:cel(n),'Missing socks cel')
 local marks={}
 for y=0,cel.image.height-1 do for x=0,cel.image.width-1 do
  local c=cel.image:getPixel(x,y)
  if app.pixelColor.rgbaA(c)>0 then
   assert(c==app.pixelColor.rgba(255,255,255,255),'Sock marks must be white')
   table.insert(marks,{x+cel.position.x,y+cel.position.y})
  end
 end end
 assert(#marks==2,'Expected exactly two Aseprite sock pixels on frame '..n)
 socks[n]=marks
end
local metadata={}; local sock_manifest={}; local preview=Sprite(8*44,#s.tags*44); local full=Sprite(8*88,#s.tags*88)
for row,t in ipairs(s.tags) do
 app.fs.makeAllDirectories(base..'act2/packed/'..t.name)
 local entry={name=t.name,frames={}}
 for n=t.fromFrame.frameNumber,t.toFrame.frameNumber do table.insert(sock_manifest,{animation=t.name,frame=n,ankles=socks[n]}) end
 local order={}; for n=t.fromFrame.frameNumber,t.toFrame.frameNumber do table.insert(order,n) end
 if t.aniDir==AniDir.PING_PONG then for n=t.toFrame.frameNumber-1,t.fromFrame.frameNumber+1,-1 do table.insert(order,n) end end
 for orderIndex,n in ipairs(order) do
  -- The runtime draws these Aseprite marks at one GAME pixel. Baking them
  -- into the shrinking body texture as well would double them on some angles.
  sock_layer.isVisible=false
  local im=Image(88,88,ColorMode.RGB); im:drawSprite(s,n); local i=orderIndex-1
  im:saveAs(base..'act2/packed/'..t.name..'/frame_'..string.format('%03d',i)..'.png')
  sock_layer.isVisible=true
  im=Image(88,88,ColorMode.RGB); im:drawSprite(s,n)
  assert(socks[n] and #socks[n]==2,'Missing sock positions for frame '..n)
  local marks=socks[n]
  table.insert(entry.frames,{duration=s.frames[n].duration,socks={{marks[1][1],marks[1][2]},{marks[2][1],marks[2][2]}}})
  if i<8 then full.cels[1].image:drawImage(im,Point(i*88,(row-1)*88)) end
  -- Each authored 2x2 source cluster becomes exactly one native gameplay pixel.
  local small=Image(44,44,ColorMode.RGB); for y=0,43 do for x=0,43 do local sx=math.min(87,x*2); local sy=math.min(87,y*2); small:putPixel(x,y,im:getPixel(sx,sy)) end end
  if i<8 then preview.cels[1].image:drawImage(small,Point(i*44,(row-1)*44)) end
 end
 table.insert(metadata,entry)
end
local f=io.open(base..'aseprite/movement_export.json','w'); f:write(json.encode(metadata)); f:close()
f=io.open(base..'aseprite/sock_pixels.json','w'); f:write(json.encode(sock_manifest)); f:close()
full:saveAs(root..'/output/child_animation_fix/final_contact.png'); preview:saveAs(root..'/output/child_animation_fix/native_contact.png'); preview:resize(preview.width*3,preview.height*3); preview:saveAs(root..'/output/child_animation_fix/native_contact_3x.png')
print('Exported '..#s.tags..' animation tags from Aseprite source')
