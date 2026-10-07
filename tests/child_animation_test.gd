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
 check(frames.get_frame_count('run') == 2, 'Small Mario reference uses two distinct walking poses')
 for clip in ['idle','run','sprint','skid','takeoff','rise','apex','fall','land','recover','dash','wall_slide','wall_jump','climb','climb_down','climb_idle','swim','swim_idle','exit_water','ledge_climb','sit','crouch']:
  check(frames.has_animation(clip), 'Missing playable animation: '+clip)
 for clip in ['idle','run','sprint','dash','climb','swim','land','recover']:
  var distinct := {}
  for i in frames.get_frame_count(clip):
   distinct[hash(frames.get_frame_texture(clip,i).get_image().get_data())] = true
  check(distinct.size() >= 2, 'Animation must contain visible pose changes: '+clip)
 for clip in ['takeoff','rise','apex','fall','land','recover','dash','wall_jump','exit_water','ledge_climb']:
  check(not frames.get_animation_loop(clip), 'Action must hold its ending pose: '+clip)
 check(not frames.get_animation_loop('jump'), 'Jump must hold its airborne pose instead of repeating takeoff')
 var stroke = frames.get_frame_texture('swim',0).get_image()
 var resting = frames.get_frame_texture('swim_idle',0).get_image()
 check(stroke.get_data() != resting.get_data(), 'Resting float must not reuse the active stroke artwork')
 check(resting.get_data() == frames.get_frame_texture('swim',3).get_image().get_data(), 'Resting swim holds the reference glide pose')
 check(absf(frames.get_frame_duration('swim',0)-4.0/60.0) <= 0.001, 'Pull lasts four SNES ticks')
 check(is_equal_approx(frames.get_frame_duration('swim',3),12.0/60.0), 'Glide lasts twelve SNES ticks')
 for room in world.rooms:
  world._enter_room(room,true)
  check(world.player.visual.sprite_frames == frames, 'Room transition changed the child library')
 var texture = frames.get_frame_texture('idle',0)
 var bounds = texture.get_image().get_used_rect()
 # The standing silhouette is 15px; every ground stride fits the 16px
 # corridor above the collider's feet, including its raised running pose.
 check(is_equal_approx(bounds.size.y*world.player.visual.scale.y,15.0), 'Child standing silhouette is 15px tall')
 for clip in ['idle','run','sprint','skid']:
  for i in frames.get_frame_count(clip):
   var image = frames.get_frame_texture(clip,i).get_image()
   var used = image.get_used_rect()
   var top = (Vector2(used.position)-Vector2(image.get_size())/2.0+world.player.visual.offset)*world.player.visual.scale
   var bottom = (Vector2(used.end)-Vector2(image.get_size())/2.0+world.player.visual.offset)*world.player.visual.scale
   check(top.y >= -10.0 and bottom.y <= 6.0, 'Ground pose fits a 16px opening at the feet: %s/%d' % [clip,i])
 for animation in frames.get_animation_names():
  for i in frames.get_frame_count(animation):
   var im = frames.get_frame_texture(animation,i).get_image()
   var box = im.get_used_rect()
   check(box.position.x>0 and box.position.y>0 and box.end.x<im.get_width() and box.end.y<im.get_height(), 'Clipped body: '+str(animation))
   check(_black_outline_intact(im), 'Black outline missing: %s frame %d' % [animation,i])
   # The editable outline survives the 0.375 reduction; the render test
   # checks the actual gameplay pixels in every pose and both facings.
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
 player.state = Player.State.RUN
 player.velocity = Vector2(player.max_run_speed,0)
 Input.action_press('move_right')
 player._update_visual()
 check(player.visual.animation == &'sprint', 'Full speed selects child sprint')
 Input.action_release('move_right')
 Input.action_press('move_left')
 player._update_visual()
 check(player.visual.animation == &'skid' and not player.visual.flip_h, 'Reversal brakes facing travel direction')
 Input.action_release('move_left')
 player.state = Player.State.IDLE
 player.landing_anim_timer = player.landing_anim_time + player.recovery_anim_time
 player._update_visual()
 check(player.visual.animation == &'land', 'Impact selects child landing compression')
 player.landing_anim_timer = player.recovery_anim_time * 0.5
 player._update_visual()
 check(player.visual.animation == &'recover', 'Landing settles through recovery')
 player.landing_anim_timer = 0.0
 player.state = Player.State.CLIMB
 player.velocity = Vector2.ZERO
 player._update_visual()
 check(player.visual.animation == &'climb_idle' and not player.visual.is_playing(), 'Ladder hold pauses on a planted pose')
 player.velocity.y = 20.0
 player._update_visual()
 check(player.visual.animation == &'climb_down', 'Ladder descent uses down cycle')
 player.state = Player.State.JUMP
 player.velocity.y = -80.0
 player.takeoff_anim_timer = player.takeoff_anim_time
 player._update_visual()
 check(player.visual.animation == &'takeoff', 'Launch starts the takeoff clip')
 player.takeoff_anim_timer = 0.0
 player._update_visual()
 check(player.visual.animation == &'rise', 'Rising keeps the reaching pose')
 player.velocity.y = 0.0
 player._update_visual()
 check(player.visual.animation == &'apex', 'Arc top selects apex')
 player.velocity.y = 80.0
 player._update_visual()
 check(player.visual.animation == &'fall', 'Descent selects fall')
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
  check(is_zero_approx(player.visual.rotation), 'SMW child swimming keeps head upright: '+str(direction))
  check(player.visual.flip_h == (direction.x<0 if not is_zero_approx(direction.x) else player.facing<0), 'Child swim mirrors horizontal direction and preserves facing vertically')
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
