extends Node
const OUT="res://output/castle_authoring_reset"
func frames(n: int) -> void:
 for i in n:await get_tree().physics_frame
func shot(name: String) -> void:
 await get_tree().process_frame
 RenderingServer.force_draw()
 var im=Screen.viewport.get_texture().get_image()
 im.save_png(OUT+"/"+name+"_native.png")
 im.resize(1280,720,Image.INTERPOLATE_NEAREST)
 im.save_png(OUT+"/"+name+".png")
func _ready() -> void:
 SaveGame.unbind()
 LdtkWorld.debug_start_room="Act_2_Level_1"
 Screen.load_scene("res://ldtk/Act2World.tscn")
 await frames(30)
 var world=Screen.current
 var beats=world.get_node("Act2Beats")
 beats._played=true
 var npc=beats._speaker
 world.player.global_position=npc.global_position+Vector2(24,-6)
 world.player.freeze()
 world.player.cutscene_rest(false,-1)
 world.player.camera.position_smoothing_enabled=false
 await frames(10)
 await shot("fishing_standing")
 world.player.cutscene_rest(true,-1)
 await frames(15)
 await shot("fishing_seated")
 for room in world.rooms:
  if not str(room.name).begins_with("Prison_"):continue
  world._enter_room(room,true)
  world.player.respawn(world.spawn_point_for(room))
  await frames(30)
  world.player.freeze()
  world.player.global_position=room.global_position+Vector2(264 if str(room.name)=="Prison_Hub" else world.room_rect(room).size.x*.5,world.room_rect(room).size.y-14)
  await frames(5)
  await shot(str(room.name))
 print("CASTLE AUTHORING PREVIEW COMPLETE")
 get_tree().quit()
