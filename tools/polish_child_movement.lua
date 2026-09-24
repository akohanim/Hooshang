-- One-time art revision, run by Aseprite. Uses the saved pre-outline source;
-- ordinary future exports use export_child_movement.lua, never this recipe.
local root = app.params.root or app.fs.filePath(app.fs.filePath(app.scriptPath))
local source = root..'/output/child_outline/before.aseprite'
local s = app.open(source)
local body = s.layers[1]
local black = app.pixelColor.rgba(0,0,0,255)
local function rgba(r,g,b) return app.pixelColor.rgba(r,g,b,255) end
local function blank() return Image(88,88,ColorMode.RGB) end
local function read(n) local im=blank(); im:drawSprite(s,n); return im end
local tags={}; for _,t in ipairs(s.tags) do tags[t.name]=t end
local idle=read(tags.idle.fromFrame.frameNumber)
local function line(im,x1,y1,x2,y2,width,color)
 local count=math.max(math.abs(x2-x1),math.abs(y2-y1))
 for i=0,count do
  local t=count==0 and 0 or i/count
  local x,y=math.floor(x1+(x2-x1)*t+.5),math.floor(y1+(y2-y1)*t+.5)
  for dy=-math.floor(width/2),math.ceil(width/2)-1 do
   for dx=-math.floor(width/2),math.ceil(width/2)-1 do im:putPixel(x+dx,y+dy,color) end
  end
 end
end
local function leg(im,h,k,f,front)
 local shade=front and rgba(58,29,55) or rgba(36,19,39)
 line(im,h[1],h[2],k[1],k[2],5,shade)
 line(im,k[1],k[2],f[1],f[2]-2,4,shade)
 line(im,h[1],h[2],k[1],k[2],2,front and rgba(78,39,65) or rgba(58,29,55))
 line(im,f[1]-1,f[2],f[1]+2,f[2],2,rgba(94,42,14))
 line(im,f[1],f[2]-1,f[1]+2,f[2]-1,1,rgba(143,65,21))
end
local function arm(im,h,k,f)
 line(im,h[1],h[2],k[1],k[2],4,rgba(101,60,43))
 line(im,k[1],k[2],f[1],f[2],3,rgba(137,81,55))
 line(im,f[1],f[2],f[1],f[2]-1,3,rgba(222,132,65))
 im:putPixel(f[1]+1,f[2]-1,rgba(255,174,90))
end
local function torso(im)
 im:drawImage(Image(idle,Rectangle(37,25,15,27)),Point(37,25))
end
local revised={}
-- Feet remain on their authored contact rows; only upper-body compression
-- follows the eight contact/down/passing/up poses.
local bob={0,1,-1,-2,0,1,-1,-2}
for i=1,8 do
 local n=tags.run.fromFrame.frameNumber+i-1
 local old=read(n); local im=blank()
 for y=0,87 do for x=0,87 do
  local c=old:getPixel(x,y)
  if app.pixelColor.rgbaA(c)>0 then im:putPixel(x,y+(y<=52 and bob[i] or 0),c) end
 end end
 if bob[i]<0 then
  for y=52+bob[i],53 do for x=41,47 do im:putPixel(x,y,old:getPixel(x,52)) end end
 end
 revised[n]=im
end
-- Clear push-off, tuck, rise: the upper body stays vertical throughout.
local rear={{35,63},{40,61},{41,64}}
local front={{49,60},{48,58},{46,60}}
for i=1,3 do
 local im=blank()
 leg(im,{44,51},{39+(i-1)*2,56},rear[i],false)
 leg(im,{46,51},{51,55},front[i],true)
 arm(im,{42,42},{37,45},{33+(i-1)*3,41-(i-1)*2})
 torso(im)
 arm(im,{46,41},{52,38},{53,34-(i-1)})
 revised[tags.wall_jump.fromFrame.frameNumber+i-1]=im
end
-- Arms alternate half a stroke apart; the rear arm is behind the head.
-- The visible hand stays outside the face. Feet kick in opposition.
local hands={{54,27},{58,32},{59,40},{56,48},{51,52},{52,46},{53,38},{54,31}}
local kick={0,2,3,2,0,-2,-3,-2}
for i=1,8 do
 local im=blank(); local h=hands[i]; local back=hands[(i+3)%8+1]
 leg(im,{44,51},{42,57},{41+kick[i],64},false)
 leg(im,{46,51},{47,57},{48-kick[i],64},true)
 arm(im,{42,41},{back[1]-15,math.floor((41+back[2])/2)},{back[1]-15,back[2]+1})
 torso(im)
 arm(im,{47,41},{math.floor((47+h[1])/2)+2,math.floor((41+h[2])/2)},{h[1],h[2]})
 revised[tags.swim.fromFrame.frameNumber+i-1]=im
end
local outlined=s:newLayer(); outlined.name='Black outline - gameplay weight'
outlined.stackIndex=1
-- Reserve space INSIDE the existing standing footprint for an outline that
-- survives .39 nearest sampling. Three source pixels become about one game
-- pixel. The outer boot baseline stays at y=66; no runtime scale/offset change.
for n=1,#s.frames do
 local old=revised[n] or read(n); local fitted=blank(); local border=blank()
 for y=0,87 do for x=0,87 do
  local sx=math.floor((x-44)/.88+44+.5)
  local sy=math.floor((y-63)/.88+66+.5)
  if sx>=0 and sx<88 and sy>=0 and sy<88 then fitted:putPixel(x,y,old:getPixel(sx,sy)) end
 end end
 for y=0,87 do for x=0,87 do
  if app.pixelColor.rgbaA(fitted:getPixel(x,y))>0 then
   for dy=-3,3 do for dx=-3,3 do
    local px,py=x+dx,y+dy
    assert(px>0 and px<87 and py>0 and py<87,'Outline clips canvas')
    border:putPixel(px,py,black)
   end end
  end
 end end
 s:newCel(body,n,fitted,Point(0,0))
 s:newCel(outlined,n,border,Point(0,0))
end
s:saveAs(root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
print('Polished run/wall-jump/swim and outlined all '..#s.frames..' Aseprite frames')
