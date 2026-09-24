-- Two white ankle pixels per cel, authored in Aseprite. Silhouette unchanged.
local root=app.params.root
local path=root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite'
local s=app.open(path)
local body
for _,l in ipairs(s.layers) do
 assert(l.name~='Socks - 1px marks','Socks already have an editable layer; edit that layer instead of rerunning this one-time recipe')
 if l.name=='Young Hooshang movement' then body=l end
end
assert(body,'Missing body artwork')
local pc=app.pixelColor
local white=pc.rgba(255,255,255,255)
local function fit(x,y) return {44+(x-44)*.88,63+(y-66)*.88} end
local feet={{34,63,55,65},{38,65,51,63},{45,65,41,61},{50,64,35,62},{55,65,34,63},{51,63,38,65},{41,61,45,65},{35,62,50,64}}
local dash={{{27,58},{39,59}},{{29,58},{39,57}},{{30,58},{39,57}},{{29,58},{39,57}},{{29,58},{37,57}},{{27,58},{40,59}},{{31,59},{39,57}}}
local climb={{{44,59},{50,49}},{{47,59},{51,49}},{{48,59},{50,49}},{{49,59},{50,49}},{{48,59},{50,49}},{{48,59},{50,49}},{{48,59},{50,49}}}
local exit={{{25,57},{26,60}},{{29,57},{30,60}},{{25,60},{34,59}},{{25,59},{36,59}},{{27,59},{37,59}},{{36,58},{44,59}},{{42,59},{46,59}}}
local kick={0,2,3,2,0,-2,-3,-2}
local function targets(name,i)
 if name=='run' then local p=feet[i]; return {fit(p[1],p[2]-2),fit(p[3],p[4]-2)} end
 if name=='jump' then return {fit(41,62),fit(46,58)} end
 if name=='fall' then return {fit(40,62),fit(49,62)} end
 if name=='wall_jump' then
  local rear={{35,61},{40,59},{41,62}}; local front={{49,58},{48,56},{46,58}}
  return {fit(rear[i][1],rear[i][2]),fit(front[i][1],front[i][2])}
 end
 if name=='swim' then return {fit(41+kick[i],62),fit(48-kick[i],62)} end
 if name=='swim_idle' then return {fit(39+(i>2 and 1 or 0),60),fit(48-(i>2 and 1 or 0),59)} end
 if name=='dash' then return dash[i] end
 if name=='climb' then return climb[i] end
 if name=='exit_water' then return exit[i] end
 if name=='wall_slide' then return {{46,(i==3 or i==4) and 58 or 59},{48,51}} end
 if name=='sit' then return {{49,59},{52,60}} end
 return {{42,59},{46,59}}
end
-- Sample positions at pixel centers for the live sprite's 88px canvas,
-- .39 scale and (0,-7) offset; keep the one-pixel marks legible in-game.
local sampled_x,sampled_y={},{}
for n=-18,18 do
 sampled_x[math.floor((n+.5)/.39+44)]=true
 sampled_y[math.floor((n+.5)/.39+51)]=true
end
local manifest={}
for _,tag in ipairs(s.tags) do
 for n=tag.fromFrame.frameNumber,tag.toFrame.frameNumber do
  local cel=body:cel(n); local im=Image(cel.image); local coords={}; local used={}
  for _,target in ipairs(targets(tag.name,n-tag.fromFrame.frameNumber+1)) do
   local best,score=nil,math.huge
   for y=math.floor(target[2])-2,math.ceil(target[2])+2 do
    for x=math.floor(target[1])-2,math.ceil(target[1])+2 do
     local c=im:getPixel(x-cel.position.x,y-cel.position.y)
     local r,g,b=pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)
     if pc.rgbaA(c)>0 and r+g+b>0 and not used[x..','..y] then
      local pants=b>=g and b>=r*.65
      local distance=(x-target[1])^2+(y-target[2])^2
      local value=distance+(pants and 0 or 5)
      if sampled_x[x] and sampled_y[y] then value=value-12 end
      if value<score then best={x,y}; score=value end
     end
    end
   end
   assert(best,'No ankle pixel for '..tag.name)
   im:putPixel(best[1]-cel.position.x,best[2]-cel.position.y,white)
   used[best[1]..','..best[2]]=true
   table.insert(coords,best)
  end
  local changed=0
  for y=0,im.height-1 do for x=0,im.width-1 do
   local a,b=cel.image:getPixel(x,y),im:getPixel(x,y)
   assert(pc.rgbaA(a)==pc.rgbaA(b),'Silhouette changed')
   if a~=b then changed=changed+1; assert(b==white,'Unexpected color edit') end
  end end
  assert(changed==2,'Expected exactly two sock pixels per frame: '..n)
  cel.image=im
  table.insert(manifest,{animation=tag.name,frame=n,ankles=coords})
 end
end
s:saveAs(path)
local f=io.open(root..'/assets/characters/hooshang_child/aseprite/sock_pixels.json','w')
f:write(json.encode(manifest)); f:close()
print('Added exactly two white sock pixels to all '..#s.frames..' frames; alpha, outline, and proportions unchanged')
