local root=app.params.root;local pc=app.pixelColor
for i,name in ipairs({'hooshang_child','jamshid'}) do
 local path=root..'/assets/characters/'..name..'/aseprite/'..(i==1 and 'young_hooshang_movement.aseprite' or 'jamshid_child_movement.aseprite')
 local old=app.open(root..'/output/castle_authoring_reset/'..name..'_before.aseprite');local im=Image(88,88);im:drawSprite(old,1);local wrong=im:getPixel(34,50);local boot=im:getPixel(36,58)
 local s=app.open(path);local l;for _,q in ipairs(s.layers) do if q.name=='Clothing and shoes' then l=q end end
 for f=59,60 do local c=l:cel(f);for y=0,c.image.height-1 do for x=0,c.image.width-1 do if y+c.position.y>=59 and c.image:getPixel(x,y)==wrong then c.image:putPixel(x,y,boot) end end end end;s:saveAs(path)
end
