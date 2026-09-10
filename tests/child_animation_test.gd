extends Node
var failures := 0
func check(ok: bool, message: String):
 if not ok:
  failures += 1
  push_error(message)
func _ready():
 SaveGame.slot = -1
 LdtkWorld.debug_start_room = 'Act_2_Level_0'
 var world = load('res://ldtk/Act2World.tscn').instantiate()
 add_child(world)
 for i in 15: await get_tree().process_frame
 var frames = world.player.visual.sprite_frames
 check(frames.get_meta('child_hooshang',false), 'Act 2 must use the child library')
 for room in world.rooms:
  world._enter_room(room,true)
  check(world.player.visual.sprite_frames == frames, 'Room transition changed the child library')
 var texture = frames.get_frame_texture('idle',0)
 var bounds = texture.get_image().get_used_rect()
 check(abs(bounds.size.y*world.player.visual.scale.y-16.0)<1, 'Child standing height must match Jamshid at 16px')
 for animation in frames.get_animation_names():
  for i in frames.get_frame_count(animation):
   var im = frames.get_frame_texture(animation,i).get_image()
   var box = im.get_used_rect()
   check(box.position.x>0 and box.position.y>0 and box.end.x<im.get_width() and box.end.y<im.get_height(), 'Clipped body: '+str(animation))
 world.player.freeze()
 world.player.cutscene_rest(true,1)
 check(world.player.visual.animation == &'sit' and world.player.visual.is_playing(), 'Child seated breathing must keep playing')
 var old_frame = world.player.visual.frame
 await get_tree().create_timer(.22).timeout
 check(world.player.visual.frame != old_frame, 'Seated animation must actually advance')
 print('CHILD ANIMATION TEST: ',failures,' failures; checked every Act 2 room, frame bounds, size and seated playback')
 get_tree().quit(1 if failures else 0)
