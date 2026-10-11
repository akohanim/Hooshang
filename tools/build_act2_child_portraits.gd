extends SceneTree
## Pack imagegen-authored faces into the same registered portrait loops as Act 1.
## Generated rows are explicitly measured; only authored eye/mouth regions move.
const SOURCE := "res://assets/portraits/source/act2_children_v2/"
const LOOPS := "res://assets/portraits/loops/"
const SIZE := 512
const SPEAKERS := {
	"childhooshang": {"states":["neutral","happy","sad","surprised","annoyed","vulnerable"],"rows":[0,280,544,808],"height":280,"dir":"res://assets/characters/hooshang_child/faces_v2/"},
	"jamshid": {"states":["friendly","joyful","worried","sad","determined","excited"],"rows":[0,256,512,768],"height":256,"dir":"res://assets/characters/jamshid/portraits_v2/"}
}
func _initialize() -> void:
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LOOPS+"manifest.json"))
	for speaker:String in SPEAKERS:
		var spec:Dictionary=SPEAKERS[speaker]
		var source:=Image.load_from_file(SOURCE+speaker+"_source.png")
		source.convert(Image.FORMAT_RGBA8)
		DirAccess.make_dir_recursive_absolute(spec.dir)
		for col in 6:
			var key:String=speaker+"_"+spec.states[col]
			var cells:Array[Image]=[]
			for row in 4:
				var cell:=Image.create(256,spec.height,false,Image.FORMAT_RGBA8)
				cell.fill(Color8(55,50,46))
				cell.blit_rect(source,Rect2i(col*256,spec.rows[row],256,mini(spec.height,source.get_height()-spec.rows[row])),Vector2i.ZERO)
				cell.resize(SIZE,SIZE,Image.INTERPOLATE_NEAREST)
				cells.append(cell)
			var master:Image=cells[0]
			var sheet:=Image.create(SIZE*4,SIZE,false,Image.FORMAT_RGBA8)
			for frame in 4:
				var art:=master.duplicate() as Image
				if frame>0:
					var shift:=register(master,cells[frame])
					var registered:=master.duplicate() as Image
					registered.blit_rect(cells[frame],Rect2i(0,0,SIZE,SIZE),shift)
					patch(art,registered,Rect2i(64,204,384,148) if frame==3 else Rect2i(128,366,260,108))
					print(key," frame ",frame," registration ",shift)
				sheet.blit_rect(art,Rect2i(0,0,SIZE,SIZE),Vector2i(frame*SIZE,0))
				if frame==0:art.save_png(spec.dir+key+".png")
			sheet.save_png(LOOPS+key+"_sheet.png")
			manifest[key]={"sheet":key+"_sheet.png","frames":4,"frame_size":[SIZE,SIZE],"fps":8,"loop":true,"rest":0,"talk":[1,2],"blink":3,"authored_roles":true,"pixel_art":true,"source":"act2_children_v2","voice_key":"jamshid_joyful" if key=="jamshid_excited" else key}
	FileAccess.open(LOOPS+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  ",false)+"\n")
	quit()

func register(master:Image,pose:Image) -> Vector2i:
	var best:=INF
	var result:=Vector2i.ZERO
	for y in range(-48,49,2):
		for x in range(-20,21,2):
			var score:=0.0
			for yy in range(340,370,4):
				for xx in range(244,274,4):
					var a:=master.get_pixel(xx,yy)
					var b:=pose.get_pixel(xx-x,yy-y)
					score+=pow(a.r-b.r,2)+pow(a.g-b.g,2)+pow(a.b-b.b,2)
			if score<best:best=score;result=Vector2i(x,y)
	return result

func patch(target:Image,source:Image,rect:Rect2i) -> void:
	var center:=Vector2(rect.get_center())
	var radii:=Vector2(rect.size)*0.5
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var point:=(Vector2(x,y)-center)/radii
			var edge:=(1.0-point.length())*minf(radii.x,radii.y)
			target.set_pixel(x,y,target.get_pixel(x,y).lerp(source.get_pixel(x,y),smoothstep(0.0,6.0,edge)))
