extends Node
func _ready():
 var vp = SubViewport.new()
 vp.size = Vector2i(448,448)
 vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
 add_child(vp)
 var bg = Polygon2D.new()
 bg.polygon = PackedVector2Array([Vector2.ZERO,Vector2(448,0),Vector2(448,448),Vector2(0,448)])
 bg.color = Color(0.65,0.7,0.66)
 vp.add_child(bg)
 var frames = load('res://assets/characters/hooshang_child/act2_frames.tres')
 var actions = ['idle','run','jump','fall','dash','wall_slide','wall_jump','climb','swim','swim_idle','exit_water','sit']
 for row in actions.size():
  for col in 7:
   var sprite = AnimatedSprite2D.new()
   sprite.sprite_frames = frames
   sprite.animation = actions[row]
   sprite.frame = mini(col,frames.get_frame_count(actions[row])-1)
   sprite.scale = Vector2(.39,.39)
   sprite.offset = Vector2(0,-7)
   sprite.position = Vector2(32+64*col,25+32*row)
   if row in [8,9]: sprite.rotation = PI/2
   vp.add_child(sprite)
 for col in 7:
  var jam = load('res://scenes/characters/jamshid/Jamshid.tscn').instantiate()
  jam.position = Vector2(32+64*col,25+32*12+6)
  vp.add_child(jam)
  jam.visual.pause()
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var im = vp.get_texture().get_image()
 im.resize(896,896,Image.INTERPOLATE_NEAREST)
 im.save_png('res://assets/characters/hooshang_child/act2/review.png')
 get_tree().quit()
