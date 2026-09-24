-- Authoring pass for young Hooshang. All raster work runs inside Aseprite.
local root=app.params.root or '/Users/ari/Hooshang_claude'
local base=root..'/assets/characters/hooshang_child/'
local before=root..'/output/child_animation_fix/before_packed/'
local names={'idle','run','jump','fall','dash','wall_slide','wall_jump','climb','swim','swim_idle','exit_water','sit'}
local original={}
for _,n in ipairs(names) do original[n]={}; for f=0,6 do original[n][f+1]=Image{fromFile=before..n..'/frame_'..string.format('%03d',f)..'.png'} end end
local function blank() return Image(88,88,ColorMode.RGB) end
local function crop(im,x,y,w,h,dx,dy) local out=blank(); out:drawImage(Image(im,Rectangle(x,y,w,h)),Point(dx or x,dy or y)); return out end
local function paste(dst,im,x,y,w,h,dx,dy) dst:drawImage(Image(im,Rectangle(x,y,w,h)),Point(dx or x,dy or y)) end
local function col(r,g,b) return app.pixelColor.rgba(r,g,b,255) end
local pantsDark=col(36,19,39); local pants=col(58,29,55); local pantsHi=col(78,39,65)
local shoe=col(94,42,14); local shoeHi=col(143,65,21); local jacket=col(101,60,43); local jacketHi=col(137,81,55); local skin=col(222,132,65); local skinHi=col(255,174,90)
local function line(im,x1,y1,x2,y2,width,c)
 local steps=math.max(math.abs(x2-x1),math.abs(y2-y1)); for t=0,steps do local a=steps==0 and 0 or t/steps; local x=math.floor(x1+(x2-x1)*a+.5); local y=math.floor(y1+(y2-y1)*a+.5); for dy=-math.floor(width/2),math.ceil(width/2)-1 do for dx=-math.floor(width/2),math.ceil(width/2)-1 do if x+dx>=0 and x+dx<88 and y+dy>=0 and y+dy<88 then im:putPixel(x+dx,y+dy,c) end end end end
end
local function leg(im,hip,knee,foot,front)
 local c=front and pants or pantsDark; line(im,hip[1],hip[2],knee[1],knee[2],5,c); line(im,knee[1],knee[2],foot[1],foot[2]-2,4,c); line(im,hip[1],hip[2],knee[1],knee[2],2,front and pantsHi or pants); line(im,foot[1]-1,foot[2],foot[1]+2,foot[2],2,shoe); line(im,foot[1],foot[2]-1,foot[1]+2,foot[2]-1,1,shoeHi)
end
local function arm(im,shoulder,elbow,hand)
 line(im,shoulder[1],shoulder[2],elbow[1],elbow[2],4,jacket); line(im,elbow[1],elbow[2],hand[1],hand[2],3,jacketHi); line(im,hand[1],hand[2],hand[1],hand[2]-1,3,skin); im:putPixel(hand[1]+1,hand[2]-1,skinHi)
end
local frames={}; for _,n in ipairs(names) do frames[n]={}; for f=1,7 do frames[n][f]=Image(original[n][f]) end end
-- Idle: one stable head and jacket silhouette, a one-pixel breath and blink.
frames.idle={}; for f=1,6 do local im=Image(original.idle[1]); if f==3 or f==4 then paste(im,original.idle[1],37,38,15,13,37,37) end if f==5 then im:putPixel(47,33,col(117,66,36)) end frames.idle[f]=im end
-- Run: eight alternating contact/down/passing/up poses, stable upper body.
local knees={{39,57,50,57},{41,58,48,56},{44,58,45,56},{47,56,40,57},{50,57,39,57},{48,56,41,58},{45,56,44,58},{40,57,47,56}}
local feet={{34,63,55,65},{38,65,51,63},{45,65,41,61},{50,64,35,62},{55,65,34,63},{51,63,38,65},{41,61,45,65},{35,62,50,64}}
frames.run={}; for f=1,8 do local im=blank(); local k=knees[f]; local p=feet[f]; leg(im,{43,52},{k[1],k[2]},{p[1],p[2]},false); leg(im,{45,52},{k[3],k[4]},{p[3],p[4]},true); paste(im,original.run[1],28,25,29,28); frames.run[f]=im end
-- Jump: upright head/torso, leading fist and readable knee tuck. No somersault or standing reset.
frames.jump={}; for f=1,4 do local im=blank(); leg(im,{44,50},{42,56},{41,64},false); leg(im,{46,51},{50,55},{46,60},true); paste(im,original.idle[1],37,25,15,27); arm(im,{46,41},{51,38},{51,33+(f==1 and 2 or 0)}); frames.jump[f]=im end
-- Fall: upright descent, lowered feet, outstretched arms for balance.
frames.fall={}; for f=1,4 do local im=blank(); leg(im,{44,51},{41,57},{40,64},false); leg(im,{46,51},{47,58},{49,64},true); paste(im,original.idle[1],37,25,15,26); arm(im,{43,42},{38,46},{35,43+(f>2 and 1 or 0)}); arm(im,{47,41},{52,44},{55,41+(f>2 and 1 or 0)}); frames.fall[f]=im end
-- Wall jump reuses the vertical takeoff silhouette; controller supplies actual trajectory.
frames.wall_jump={Image(frames.jump[1]),Image(frames.jump[2]),Image(frames.jump[3])}
-- Swim source is head-up, matching the controller's local-up orientation contract.
frames.swim={}; for f=1,7 do local src=original.swim[f]; local im=blank(); for y=0,87 do for x=0,87 do local c=src:getPixel(x,y); if app.pixelColor.rgbaA(c)>0 then local nx=y+1; local ny=95-x; if nx>=0 and nx<88 and ny>=0 and ny<88 then im:putPixel(nx,ny,c) end end end end frames.swim[f]=im end
-- Quiet float: upright torso and small alternating foot paddles, distinct from stroke.
frames.swim_idle={}; for f=1,4 do local im=blank(); leg(im,{44,51},{41,57},{39+(f>2 and 1 or 0),62},false); leg(im,{46,51},{49,56},{48-(f>2 and 1 or 0),61},true); paste(im,original.idle[1],37,25,15,26); arm(im,{43,42},{38,46},{35,45}); arm(im,{47,42},{51,46},{54,44}); frames.swim_idle[f]=im end
-- Pass 2: retain a stable swimmer body, animate limbs rather than rescaling the silhouette.
frames.swim={}
for f=1,8 do
 local im=blank(); local phase=(f-1)*math.pi/4
 leg(im,{44,51},{42,57},{41+math.floor(math.sin(phase)*3),64},false)
 leg(im,{46,51},{48,57},{48-math.floor(math.sin(phase)*3),64},true)
 local hx=49+math.floor(math.sin(phase)*9); local hy=38-math.floor(math.cos(phase)*12)
 arm(im,{44,41},{40,34},{39,29})
 paste(im,original.idle[1],37,25,15,27)
 arm(im,{46,41},{math.floor((46+hx)/2)+2,math.floor((41+hy)/2)},{hx,hy})
 frames.swim[f]=im
end
-- Run arm swing counterbalances the leg stride. Head, face and jacket retain their identity.
for f=1,8 do
 local im=blank(); local k=knees[f]; local p=feet[f]
 leg(im,{43,52},{k[1],k[2]},{p[1],p[2]},false); leg(im,{45,52},{k[3],k[4]},{p[3],p[4]},true)
 local swing=math.floor(math.sin((f-1)*math.pi/4)*4)
 arm(im,{43,42},{39-swing,46},{38-swing,43})
 paste(im,original.run[1],37,25,15,16)
 paste(im,original.run[1],40,41,9,12)
 arm(im,{44,43},{42+swing,48},{46+swing,46})
 frames.run[f]=im
end
-- Calm wall contact: preserve planted hands and head, one-pixel trailing foot movement.
for f=1,7 do frames.wall_slide[f]=Image(original.wall_slide[1]); if f==3 or f==4 then paste(frames.wall_slide[f],original.wall_slide[1],37,58,15,8,37,57) end end
local spr=Sprite(88,88); spr.layers[1].name='Young Hooshang movement'
local timing={idle=180,run=80,jump=70,fall=120,dash=29,wall_slide=140,wall_jump=70,climb=90,swim=140,swim_idle=220,exit_water=72,sit=180}
local index=0; local ranges={}
for _,n in ipairs(names) do local first=index+1; for _,im in ipairs(frames[n]) do index=index+1; if index>1 then spr:newEmptyFrame() end spr:newCel(spr.layers[1],index,im,Point(0,0)); spr.frames[index].duration=timing[n]/1000 end table.insert(ranges,{name=n,first=first,last=index}) end
for _,r in ipairs(ranges) do local tag=spr:newTag(r.first,r.last); tag.name=r.name; if r.name=='climb' or r.name=='wall_slide' or r.name=='sit' then tag.aniDir=AniDir.PING_PONG end end
spr:saveAs(base..'aseprite/young_hooshang_movement.aseprite')
local sheet=Sprite(8*88,#names*88); for row,n in ipairs(names) do for f,im in ipairs(frames[n]) do sheet.cels[1].image:drawImage(im,Point((f-1)*88,(row-1)*88)) end end sheet:saveAs(root..'/output/child_animation_fix/pass2.png')
print('Aseprite pass 2: '..index..' frames saved; preview rows '..table.concat(names,', '))
