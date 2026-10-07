extends Node
func _ready():
 var vp = SubViewport.new()
 vp.size = Vector2i(512,800)
 vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
 add_child(vp)
 var bg = Polygon2D.new()
 bg.polygon = PackedVector2Array([Vector2.ZERO,Vector2(512,0),Vector2(512,800),Vector2(0,800)])
 bg.color = Color(0.65,0.7,0.66)
 vp.add_child(bg)
 var frames = load('res://assets/characters/hooshang_child/act2_frames.tres')
 var actions = ['idle','run','sprint','skid','takeoff','rise','apex','fall','land','recover','dash','wall_slide','wall_jump','climb','climb_down','climb_idle','swim','swim_idle','exit_water','ledge_climb','sit','crouch','wall_land']
 for row in actions.size():
  for col in 8:
   var actor = Node2D.new()
   actor.position = Vector2(32+64*col,25+32*row)
   vp.add_child(actor)
   var squash = Node2D.new()
   squash.name = 'SpriteSquash'
   actor.add_child(squash)
   var sprite = AnimatedSprite2D.new()
   sprite.name = 'Visual'
   sprite.sprite_frames = frames
   sprite.animation = actions[row]
   sprite.frame = mini(col,frames.get_frame_count(actions[row])-1)
   sprite.scale = Vector2.ONE * frames.get_meta("visual_scale")
   sprite.offset = frames.get_meta("visual_offset")
   # The child swim is already authored side-on and stays upright.
   squash.add_child(sprite)
   actor.add_child(load('res://scenes/characters/hooshang/SockPixels.tscn').instantiate())
 for col in 8:
  var jam = load('res://scenes/characters/jamshid/Jamshid.tscn').instantiate()
  jam.position = Vector2(32+64*col,25+32*23+6)
  vp.add_child(jam)
  jam.visual.pause()
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var im = vp.get_texture().get_image()
 im.resize(1024,1600,Image.INTERPOLATE_NEAREST)
 im.save_png('res://assets/characters/hooshang_child/act2/review.png')
 get_tree().quit()
