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
 check(frames.get_frame_count('run') >= 8 and frames.get_frame_count('run') <= 12, 'Run must have a complete 8–12 frame stride cycle')
 check(not frames.get_animation_loop('jump'), 'Jump must hold its airborne pose instead of repeating takeoff')
 var stroke = frames.get_frame_texture('swim',0).get_image()
 var resting = frames.get_frame_texture('swim_idle',0).get_image()
 check(stroke.get_data() != resting.get_data(), 'Resting float must not reuse the active stroke artwork')
 for room in world.rooms:
  world._enter_room(room,true)
  check(world.player.visual.sprite_frames == frames, 'Room transition changed the child library')
 var texture = frames.get_frame_texture('idle',0)
 var bounds = texture.get_image().get_used_rect()
 # Removing the oversized contour leaves the colored body unchanged; the
 # one-source-pixel edge gives about 15px total at the original .39 scale.
 check(abs(bounds.size.y*world.player.visual.scale.y-15.0)<1, 'Child standing height with the thin contour must stay about 15px')
 for animation in frames.get_animation_names():
  for i in frames.get_frame_count(animation):
   var im = frames.get_frame_texture(animation,i).get_image()
   var box = im.get_used_rect()
   check(box.position.x>0 and box.position.y>0 and box.end.x<im.get_width() and box.end.y<im.get_height(), 'Clipped body: '+str(animation))
   check(_black_outline_intact(im), 'Black outline missing: %s frame %d' % [animation,i])
   # Outline width is one ASEPRITE pixel. Do not thicken it to compensate
   # for nearest sampling; the Aseprite layer audit checks its exact width.
 world.player.freeze()
 world.player.cutscene_rest(true,1)
 check(world.player.visual.animation == &'sit' and world.player.visual.is_playing(), 'Child seated breathing must keep playing')
 var old_frame = world.player.visual.frame
 await get_tree().create_timer(.22).timeout
 check(world.player.visual.frame != old_frame, 'Seated animation must actually advance')
 # Check the child library through the real controller, not a separately
 # rotated review sprite: the old preview hid incorrect in-game swimming.
 var player = world.player
 player.set_physics_process(false)
 player.input_locked = false
 player.wall_jump_timer = 0.0
 for state in [Player.State.JUMP, Player.State.FALL]:
  player.state = state
  player._update_visual()
  check(is_zero_approx(player.visual.rotation), 'Jump and fall must stay upright')
 player.state = Player.State.SWIM
 player._swim_paddling = true
 for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1,-1).normalized()]:
  for i in 120:
   player._tick_swim_orientation(1.0/60.0, direction.x, direction.y)
  player._update_visual()
  var head_direction = Vector2.UP.rotated(player.visual.rotation)
  check(head_direction.dot(direction)>0.999, 'Child swim must lead with head: '+str(direction))
  check(player.visual.flip_h == (direction.x<0), 'Child swim must mirror leftward strokes')
  check(player.visual.animation == &'swim', 'Steering must play the active stroke')
 player._swim_paddling = false
 for i in 120:
  player._tick_swim_orientation(1.0/60.0, 0.0, 0.0)
 player._update_visual()
 check(player.visual.animation == &'swim_idle', 'No swim input must play the resting float')
 check(is_zero_approx(player.visual.rotation), 'Resting float returns upright')
 player.state = Player.State.EXIT_WATER
 player._swim_visual_angle = PI/2
 player._update_visual()
 check(is_zero_approx(player.visual.rotation), 'Authored child climb-out must not be rotated twice')
 print('CHILD ANIMATION TEST: ',failures,' failures; checked Act 2 rooms, frame bounds, size, stride, seated playback and swim orientation')
 get_tree().quit(1 if failures else 0)

func _black_outline_intact(im: Image) -> bool:
 for y in range(1,im.get_height()-1):
  for x in range(1,im.get_width()-1):
   var c = im.get_pixel(x,y)
   if c.a == 0.0 or (c.r == 0.0 and c.g == 0.0 and c.b == 0.0):
    continue
   for dy in range(-1,2):
    for dx in range(-1,2):
     if im.get_pixel(x+dx,y+dy).a == 0.0:
      return false
 return true
