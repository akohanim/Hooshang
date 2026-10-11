extends Node
## Both children use square authored emotional loops, the same speech/blink
## lifecycle as Act 1, and distinct child voice pools. Optional native UI captures.
const SCRIPT := preload("res://resources/dialogue/act2_author_script.tres")
var failures := 0
func frames(n:int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _ready() -> void:
	SaveGame.unbind()
	var capture:= "--capture" in OS.get_cmdline_user_args()
	if capture:
		LdtkWorld.debug_start_room="Act_2_Level_14"
		Screen.load_scene("res://ldtk/Act2World.tscn")
		await frames(20)
		DirAccess.make_dir_recursive_absolute("res://output/act2_dialogue")
	var box:DialogueBox=Dialogue
	box.chars_per_second=10
	for speaker in ["childhooshang","jamshid"]:
		var faces:Dictionary=Act2Beats.CHILD_FACES if speaker=="childhooshang" else Jamshid.FACES
		for emotion:String in faces:
			var face:Texture2D=faces[emotion]
			var key:String=speaker+"_"+emotion
			check(face.get_size()==Vector2(512,512),key+" close-up square")
			var spoken := ""
			var script_speaker:String="HOOSHANG" if speaker=="childhooshang" else "JAMSHID"
			for chapter in ["wall","palace","cell","carpet"]:
				for line:Dictionary in SCRIPT.scenes[chapter]:
					if line.speaker==script_speaker and line.get("face","")==emotion and line.text.length()>spoken.length():spoken=line.text
			check(not spoken.is_empty(),key+" has an actual authored line")
			box.say("Hooshang" if speaker=="childhooshang" else "Jamshid",spoken,Color.WHITE,face,DialogueBox.Side.LEFT if speaker=="childhooshang" else DialogueBox.Side.RIGHT,DialogueBox.VSide.BOTTOM)
			for tick in 180:
				await frames(1)
				if box._revealing and box.text_label.scale.y>0.99:break
			check(box._revealing and box.text_label.get_total_character_count()>0,key+" text is visible before animation checks")
			check(box.portrait_loop.visible and not box._loop.is_empty(),key+" loop is actually displayed")
			check(box._voice_key.begins_with(speaker+"_"),key+" retains child voice identity")
			var sheet:Image=Image.load_from_file("res://assets/portraits/loops/"+key+"_sheet.png")
			var rest:Image=sheet.get_region(Rect2i(0,0,512,512))
			for i in [1,2,3]:
				var pose:Image=sheet.get_region(Rect2i(i*512,0,512,512))
				check(pose.get_data()!=rest.get_data(),key+" authored pose "+str(i)+" changes pixels")
				check(pose.get_region(Rect2i(0,0,512,190)).get_data()==rest.get_region(Rect2i(0,0,512,190)).get_data(),key+" pose "+str(i)+" holds hair still")
			box._blink_t=-1;box._blink_left=10;box._loop_left=0
			box._animate_loop(0.2)
			var atlas:AtlasTexture=box.portrait_loop.texture
			check(int(atlas.region.position.x/512) in [1,2],key+" speaks while text reveals")
			box._pause_left=0.5;box._animate_loop(0.01)
			check(atlas.region.position.x==0,key+" rests during a breath")
			box._pause_left=0;box._finish_reveal_instantly();box._animate_loop(0.01)
			check(atlas.region.position.x==0,key+" rests when sentence completes")
			box._blink_left=0;box._animate_loop(0.01);box._animate_loop(0.01)
			check(atlas.region.position.x==1536,key+" blinks independently")
			if capture:
				box._blink_t=-1;box._blink_left=10;box._show_frame(box.portrait_loop,0)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://output/act2_dialogue/"+key+".png")
			while box._active:
				box.line_finished.emit();await frames(3)
			await frames(20)
	for chapter in ["wall","palace","cell","carpet"]:
		var used:Dictionary={}
		for line:Dictionary in SCRIPT.scenes[chapter]:
			if line.speaker not in ["HOOSHANG","JAMSHID"]:continue
			var states:Dictionary=Act2Beats.CHILD_FACES if line.speaker=="HOOSHANG" else Jamshid.FACES
			check(states.has(line.get("face","")),chapter+" line has an authored available expression")
			used[line.face]=true
		check(used.size()>1,chapter+" develops more than one emotional state")
	print("ACT2 CHILD PORTRAITS: ",failures," failures")
	get_tree().quit(1 if failures else 0)
