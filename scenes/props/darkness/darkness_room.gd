extends Node2D
## Room puzzles and telegraphed attacks. Continuous escape rooms delegate
## pursuit and absorption to the real Darkshang actor.
const MANIFESTATION=preload("res://scenes/props/darkness/darkness_manifestation.gd")
const SECURITY_GATE=preload("res://scenes/props/security/SecurityGate.tscn")
const SECURITY_TERMINAL=preload("res://scenes/props/security/SecurityTerminal.tscn")
const CLOUD_SCENE=preload("res://scenes/props/darkness/DarkshangCloud.tscn")
const PIXEL_FONT=preload("res://assets/fonts/pixel5x7.fnt")
enum Phase { ABSENT, GATHER, PRESENT, FADE }
@export var recipe:Dictionary={}
var world:LdtkWorld
var player:Player
var active:=false
var phase:Phase=Phase.ABSENT
var phase_time:=0.0
var presence:=0.0
var age:=0.0
var committed:=false
var solved:=false
var step:=0
var still_time:=0.0
var last_pad:=-1
var pad_dwell:=0.0
var pad_fired:=false
var gate:StaticBody2D
var gate_shape:CollisionShape2D
var bridges:Array[StaticBody2D]=[]
var manifestation:Node2D
var warning_left:=-1.0
var attack_kind:=""
var attack_rect:=Rect2()
var attack_target:=Vector2.ZERO
var attack_life:=0.0
var attack_wait:=2.0
var attack_count:=0
var returns:=0
var pulse_direction:=-1.0
var seal_broken:=false
var seal_index:=0
var fired_this_presence:=false
var sweeps_survived:=0
var phase_door:StaticBody2D
var pressure_front:=0.0
var _cue:AudioStreamPlayer
var _cue_stream:AudioStreamWAV
var e:Dictionary
var chaser:Darkshang
var surge_wait:=8.0
var boss_position:=Vector2.ZERO
var clouds:Array[Node2D]=[]
var security_gate:StaticBody2D
var terminals:Array[Node2D]=[]
var origin:Vector2
var player_rest_z:=0
signal puzzle_solved
signal attack_telegraphed(kind:String,area:Rect2)
signal attack_became_active(kind:String)

func _ready()->void:
	e=recipe.get("encounter",{})
	if e.is_empty():return
	if e.mode=="security":
		_build_security()
	elif e.mode not in ["chase", "traversal"]:
		gate=_solid(Rect2(float(e.gate_x),0,8,recipe.height))
		gate_shape=gate.get_child(0)
	if e.mode=="phase":phase_door=_solid(Rect2(112 if recipe.direction<0 else 200,0,8,recipe.height))
	for b:Array in e.get("bridges",[]):bridges.append(_solid(Rect2(b[0],b[1],b[2],8)))
	manifestation=Node2D.new()
	manifestation.set_script(MANIFESTATION)
	manifestation.set("recognizable",bool(e.get("boss",false)) and not e.get("continuous_chase",false))
	manifestation.set("form",0 if e.get("continuous_chase",false) else int(e.form))
	manifestation.set("room_size",Vector2(recipe.width,recipe.height))
	manifestation.set("anchor",Vector2(e.anchor[0],e.anchor[1]))
	manifestation.z_as_relative=false
	manifestation.z_index=-1
	manifestation.material=material
	add_child(manifestation)
	_cue=AudioStreamPlayer.new()
	_cue.volume_db=-24
	if AudioServer.get_bus_index("SFX")>=0:_cue.bus="SFX"
	add_child(_cue)
	# A short breath/knock, synthesized locally, not a projectile sound.
	_cue_stream=AudioStreamWAV.new()
	_cue_stream.format=AudioStreamWAV.FORMAT_16_BITS
	_cue_stream.mix_rate=22050
	var bytes:=PackedByteArray();bytes.resize(4410*2)
	for i in 4410:
		var t:=float(i)/22050.0
		var v:=sin(t*TAU*86)*exp(-t*24)*sin(minf(t/.015,1.0)*PI/2)
		bytes.encode_s16(i*2,int(v*10000))
	_cue_stream.data=bytes
	_cue.stream=_cue_stream
	set_physics_process(false)
	z_index=2

func bind(to:LdtkWorld)->void:
	world=to;player=to.player;origin=get_parent().global_position
	player_rest_z=player.z_index

func enter()->void:
	active=true;visible=true;age=0;phase=Phase.ABSENT;phase_time=0
	# Seals and warnings must never occlude the body used to read a dodge.
	player.z_index=3
	presence=0;committed=false;solved=false;seal_broken=false;seal_index=0;fired_this_presence=false;sweeps_survived=0;step=0;still_time=0;last_pad=-1;pad_dwell=0;pad_fired=false
	warning_left=-1;attack_life=0;attack_wait=2;attack_count=0
	boss_position=Vector2(e.anchor[0],e.anchor[1])
	_clear_clouds()
	pressure_front=float(recipe.width) if recipe.direction<0 else 0.0
	if gate_shape!=null:gate_shape.set_deferred("disabled",false)
	surge_wait=float(e.get("surge_interval",8.0))
	_update_bridges()
	if security_gate!=null:
		get_parent().set_meta("exit_locked",true)
		security_gate.set_access(false)
		_update_terminals(Vector2.INF)
	set_physics_process(true)

func leave()->void:
	_clear_clouds()
	active=false;visible=false;warning_left=-1;attack_life=0
	if player!=null:player.z_index=player_rest_z
	_cue.stop()
	set_physics_process(false)

func reset_after_death()->void:
	if not active:return
	var banked_step:=step
	var banked_seal:=seal_broken
	var banked_seal_index:=seal_index
	var banked_solved:=solved
	var checkpoint_active:=world._checkpoint.distance_to(world.spawn_point_for(get_parent()))>16
	enter()
	if checkpoint_active or security_gate!=null:
		step=banked_step;seal_broken=banked_seal;seal_index=banked_seal_index
		if banked_solved:_solve()
		if security_gate!=null:_update_terminals(Vector2.INF)

func _solid(rect:Rect2)->StaticBody2D:
	var body:=StaticBody2D.new();body.collision_layer=1;body.collision_mask=0
	body.position=rect.get_center()
	var shape:=CollisionShape2D.new();shape.shape=RectangleShape2D.new();shape.shape.size=rect.size
	body.add_child(shape);add_child(body)
	return body

func _physics_process(delta:float)->void:
	if not active or player==null:return
	if world._transitioning or player.input_locked or player.state==Player.State.DEAD:return
	# Precision rooms use the existing structural dressing, but movement and
	# musical locks own their pacing. Do not overwrite NoteSequence lighting.
	if e.mode=="traversal":
		queue_redraw()
		return
	age+=delta
	var p:=player.global_position-origin
	var spawn:=world.spawn_point_for(get_parent())-origin
	if (p.x-spawn.x)*float(recipe.direction)>=16:committed=true
	if e.get("continuous_chase",false):
		committed=is_instance_valid(chaser) and not chaser._holding_entry
		phase=Phase.PRESENT;presence=1
		if committed:
			surge_wait-=delta
			if surge_wait<=0 and chaser.gap()>72 and player.state!=Player.State.CLIMB:
				chaser.surge(.22,.12)
				surge_wait=float(e.surge_interval)
	elif committed:_cycle(delta)
	_update_phase_door()
	_puzzle(p,delta)
	if e.get("boss",false):_move_boss(p,delta)
	_attack(p,delta)
	manifestation.set("presence",presence)
	manifestation.set("fading",phase==Phase.FADE)
	manifestation.set("warning",warning_left>=0)
	# V10 uses the world's authored ambient tint like an ordinary room.
	# Other encounters breathe from dim blue into darkness with his presence.
	var calm:=Color(.17,.19,.24)
	world.get_node("CanvasModulate").color=world._ambient_color if str(get_parent().name)=="Level_V10" or security_gate!=null or e.get("continuous_chase",false) else calm.lerp(Color(.075,.075,.12),presence)
	if world._music!=null:
		world._music.volume_db=lerpf(world._music.volume_db,world._music_base_db-(1-presence)*5,minf(delta*2,1))
	queue_redraw()

func _cycle(delta:float)->void:
	if solved and e.mode!="phase" and phase==Phase.ABSENT:return
	phase_time+=delta
	match phase:
		Phase.ABSENT:
			presence=0
			var wait:float=(.65 if e.get("boss",false) else 2.0) if age<3 else float(e.absent)
			if phase_time>=wait and e.mode!="sequence" and not (e.mode=="still" and int(e.form)==0):
				_set_phase(Phase.GATHER)
		Phase.GATHER:
			var gather_time:float=.8 if e.get("boss",false) else 1.4
			presence=clampf(phase_time/gather_time,0,1)
			if phase_time>=gather_time:_set_phase(Phase.PRESENT)
		Phase.PRESENT:
			presence=1
			if phase_time>=float(e.present):_set_phase(Phase.FADE)
		Phase.FADE:
			presence=1-clampf(phase_time/1.2,0,1)
			if phase_time>=1.2:_set_phase(Phase.ABSENT)
	if solved and e.mode in ["watch","still","final"] and phase!=Phase.ABSENT and phase!=Phase.FADE:_set_phase(Phase.FADE)

func _set_phase(next:Phase)->void:
	phase=next;phase_time=0
	if next==Phase.PRESENT:fired_this_presence=false;attack_wait=.4 if e.get("boss",false) else 2.0
	if next==Phase.GATHER:
		returns+=1
		manifestation.set("iteration",returns+int(recipe.get("appearance_variant",0)))
	if next in [Phase.GATHER,Phase.FADE]:_cue.play()
	if next==Phase.ABSENT:
		if solved and gate_shape!=null:gate_shape.set_deferred("disabled",true)
		warning_left=-1;attack_life=0
	_update_bridges()

func _update_phase_door()->void:
	if phase_door==null:return
	var closed:=phase!=Phase.PRESENT and phase!=Phase.FADE
	var rect:=Rect2(phase_door.global_position-Vector2(4,float(recipe.height)/2),Vector2(8,recipe.height))
	# Never materialize collision inside a body. The warning has already asked
	# them to leave; the seam waits until they actually clear its footprint.
	if closed and rect.intersects(player.hitbox_rect()):closed=false
	phase_door.get_child(0).set_deferred("disabled",not closed)

func _update_bridges()->void:
	for i in bridges.size():
		var b:Array=e.bridges[i]
		var on:=phase==Phase.PRESENT if int(b[3])==1 else phase==Phase.ABSENT
		# During the departure warning a deck stays until the announced transition.
		if phase==Phase.FADE and int(b[3])==1:on=true
		bridges[i].get_child(0).set_deferred("disabled",not on)

func _puzzle(p:Vector2,delta:float)->void:
	if security_gate!=null:
		_security_puzzle(p,delta)
		return
	if solved:return
	var mode:String=e.mode
	if mode in ["watch","still"] or (mode=="final" and seal_broken):
		var at:=Vector2(e.still[0],e.still[1])
		if p.distance_to(at)<25 and player.is_on_floor() and absf(player.velocity.x)<3 and (mode!="final" or phase==Phase.ABSENT) and (mode!="watch" or phase==Phase.PRESENT):
			still_time+=delta
		else:still_time=maxf(0,still_time-delta*2)
		if still_time>=float(e.still_seconds):_solve()
	elif mode=="sequence":
		var touched:=-1
		for i in e.pads.size():
			var q:=Vector2(e.pads[i][0],e.pads[i][1]-6)
			if p.distance_to(q)<14 and player.is_on_floor():touched=i
		if touched!=last_pad:
			pad_dwell=0;pad_fired=false
		last_pad=touched
		if touched>=0 and absf(player.velocity.x)<4:
			pad_dwell+=delta
			if pad_dwell>=.35 and not pad_fired:
				pad_fired=true
				if touched==step:step+=1;_cue.pitch_scale=1+step*.16;_cue.play()
				else:step=0;_cue.pitch_scale=.7;_cue.play()
				if step>=e.pads.size():_solve()
	elif mode=="phase":
		if step<e.phase_pads.size():
			var pad:Array=e.phase_pads[step]
			var matching:=phase==Phase.PRESENT if int(pad[2])==1 else phase==Phase.ABSENT
			if matching and player.is_on_floor() and p.distance_to(Vector2(pad[0],pad[1]-6))<15:
				step+=1;_cue.play()
				if step==e.phase_pads.size():_solve()
	elif mode=="sweep":
		if seal_broken and sweeps_survived>0:_solve()
	elif seal_broken:_solve()

func _solve()->void:
	if solved:return
	solved=true
	if e.get("boss",false) and not e.get("continuous_chase",false):
		warning_left=-1;attack_life=0;_clear_clouds()
		_set_phase(Phase.FADE)
	if security_gate!=null:
		get_parent().set_meta("exit_locked",false)
		security_gate.set_access(true)
	if e.mode in ["pulse","mark","sweep"] and phase!=Phase.ABSENT:
		_set_phase(Phase.FADE)
	elif gate_shape!=null:gate_shape.set_deferred("disabled",true)
	_cue.pitch_scale=1.5;_cue.play()
	puzzle_solved.emit()

func _attack(p:Vector2,delta:float)->void:
	if e.get("continuous_chase",false) and (not is_instance_valid(chaser) or not chaser.powers_available()):return
	if not committed:return
	if e.get("boss",false):
		_boss_attack(p,delta)
		return
	if warning_left>=0:
		warning_left-=delta
		if warning_left<=0:
			warning_left=-1
			attack_life=6.5 if attack_kind=="pulse" else .65
			attack_became_active.emit(attack_kind)
			_cue.pitch_scale=.65;_cue.play()
		return
	if attack_life>0:
		attack_life-=delta
		if attack_life<=0 and attack_kind=="sweep" and player.state!=Player.State.DEAD:sweeps_survived+=1
		if attack_kind=="pulse":attack_rect.position.x+=pulse_direction*62*delta
		if e.has("seal") and not seal_broken:
			var at:=seal_at()
			var seal:=Rect2(at-Vector2(8,8),Vector2(16,16))
			var required:String=e.targets[seal_index][2] if e.has("targets") else ""
			if attack_rect.intersects(seal) and (required=="" or required==attack_kind):
				seal_index+=1
				seal_broken=not e.has("targets") or seal_index>=e.targets.size()
		var hitbox:=player.hitbox_rect()
		hitbox.position-=origin
		if attack_rect.intersects(hitbox):player.die()
		return
	if phase!=Phase.PRESENT or not e.has("attacks") or fired_this_presence:return
	attack_wait-=delta
	if attack_wait>0:return
	fired_this_presence=true
	attack_wait=3.2
	var attacks:Array=e.attacks
	attack_kind=attacks[attack_count%attacks.size()];attack_count+=1
	attack_target=p.snapped(Vector2(8,8))
	if attack_kind=="pulse":
		pulse_direction=-1 if p.x<float(e.anchor[0]) else 1
		attack_rect=Rect2(Vector2(float(e.anchor[0]),attack_target.y-4),Vector2(18,8))
	elif attack_kind=="mark":attack_rect=Rect2(attack_target+Vector2(-20,-8),Vector2(40,16))
	else:
		# Always the LOW band. The raised decks remain safe, visible escape options.
		attack_rect=Rect2(8,144,float(recipe.width)-16,24)
	warning_left=1.4 if attack_kind!="sweep" else 1.8
	attack_telegraphed.emit(attack_kind,attack_rect)
	_cue.pitch_scale=1;_cue.play()

func seal_at()->Vector2:
	if e.has("targets"):
		var target:Array=e.targets[mini(seal_index,e.targets.size()-1)]
		return Vector2(target[0],target[1])
	return Vector2(e.seal[0],e.seal[1])

func _draw()->void:
	if recipe.is_empty():return
	var w:float=recipe.width;var h:float=recipe.height
	# Cables visibly attach every suspended deck to the architecture.
	for r:Array in recipe.route:
		for x in [r[0]+4,r[0]+r[2]-5]:
			draw_line(Vector2(x,maxf(8,r[1]-48)),Vector2(x,r[1]),Color(.2,.25,.3,.55),1)
	for b:Array in e.get("bridges",[]):
		var rect:=Rect2(b[0],b[1],b[2],8)
		var on:=phase==Phase.PRESENT if int(b[3])==1 else phase==Phase.ABSENT
		draw_rect(rect,Color(.28,.35,.43,.9 if on else .18),on)
		for x in range(int(b[0]),int(b[0]+b[2]),8):draw_line(Vector2(x,b[1]),Vector2(x+7,b[1]+7),Color(.48,.56,.63,.7 if on else .12),1)
	if phase_door!=null:
		var dx:=phase_door.position.x-4
		var solid:=phase!=Phase.PRESENT and phase!=Phase.FADE
		draw_rect(Rect2(dx,8,8,h-16),Color(.24,.27,.36,.8 if solid else .1))
		for y in range(12,int(h)-8,12):draw_line(Vector2(dx,y),Vector2(dx+7,y+4),Color(.48,.52,.65,.65 if solid else .12),1)
	if security_gate==null and gate_shape!=null and not gate_shape.disabled:
		var gx:float=e.gate_x
		draw_rect(Rect2(gx,8,8,h-16),Color(.12,.16,.22))
		for y in range(12,int(h)-8,8):draw_line(Vector2(gx,y),Vector2(gx+7,y+5),Color(.48,.42,.33),1)
	if security_gate!=null:_draw_security_instructions()
	if e.has("pads"):
		var previous:=Vector2(recipe.route[0][0]+recipe.route[0][2]/2,recipe.route[0][1]-20)
		for i in e.pads.size():
			var pad:Array=e.pads[i];var at:=Vector2(pad[0],pad[1]-2)
			var c:=Color(.63,.69,.51) if step>i else Color(.42,.43,.39)
			var corner:=Vector2(at.x,previous.y-12)
			draw_polyline(PackedVector2Array([previous,Vector2(previous.x,corner.y),corner,at]),Color(c,.6),1)
			draw_rect(Rect2(at-Vector2(10,1),Vector2(20,3)),c)
			draw_circle(at-Vector2(0,8),2,c)
			previous=at
		draw_polyline(PackedVector2Array([previous,Vector2(previous.x,previous.y-24),Vector2(float(e.gate_x)+4,previous.y-24)]),Color(.47,.49,.42,.6),1)
	for i in e.get("phase_pads",[]).size():
		var pad:Array=e.phase_pads[i]
		var c:=Color(.6,.7,.61) if step>i else Color(.44,.48,.61)
		draw_arc(Vector2(pad[0],pad[1]-8),6,0,TAU,16,c,1)
		if int(pad[2])==1:draw_circle(Vector2(pad[0],pad[1]-8),3,c)
	if e.has("still"):
		var at:=Vector2(e.still[0],e.still[1])
		draw_arc(at-Vector2(0,15),10,0,TAU,24,Color(.35,.37,.38),1)
		for x in [-3,2]:draw_line(at+Vector2(x,-20),at+Vector2(x,-12),Color(.57,.58,.48),1)
		draw_arc(at-Vector2(0,15),10,-PI/2,-PI/2+TAU*minf(1,still_time/float(e.still_seconds)),24,Color(.68,.64,.46),1)
		draw_line(at+Vector2(-12,6),at+Vector2(12,6),Color(.48,.49,.4),1)
	if e.has("seal") and not seal_broken:
		var at:=seal_at()
		draw_rect(Rect2(at-Vector2(8,8),Vector2(16,16)),Color(.2,.18,.24))
		draw_line(at-Vector2(6,6),at+Vector2(6,6),Color(.67,.46,.42),2)
		draw_line(at+Vector2(-6,6),at+Vector2(6,-6),Color(.67,.46,.42),2)
	if warning_left>=0:
		if e.get("boss",false) and attack_kind=="pulse":
			var tip:=attack_rect.get_center()
			draw_line(tip,tip+Vector2(pulse_direction*48,0),Color(.85,.36,.35,.7),1)
		# A hatching pattern plus a draining border: readable without color alone.
		draw_rect(attack_rect,Color(.66,.48,.5,.25))
		draw_rect(attack_rect,Color(.8,.63,.55),false,1)
		for x in range(int(attack_rect.position.x),int(attack_rect.end.x),6):draw_line(Vector2(x,attack_rect.position.y),Vector2(x+4,attack_rect.end.y),Color(.7,.54,.55,.4),1)
	elif attack_life>0:
		if attack_kind=="pulse":
			var p:=attack_rect.position
			var fog:=PackedVector2Array([Vector2(0,4),Vector2(3,1),Vector2(7,2),Vector2(9,0),Vector2(14,1),Vector2(18,5),Vector2(15,8),Vector2(2,8)])
			for i in fog.size():fog[i]+=p
			draw_colored_polygon(fog,Color(.03,.025,.05,.95))
			draw_polyline(fog,Color(.49,.38,.5,.8),1)
			for i in 4:draw_rect(Rect2(p+Vector2(-pulse_direction*(i*4),4+(i%2)),Vector2(5,2)),Color(.12,.09,.17,.5-i*.08))
		else:
			draw_rect(attack_rect,Color(.035,.025,.055,.93))
			draw_rect(attack_rect.grow(1),Color(.6,.41,.51,.65),false,1)
			for x in range(int(attack_rect.position.x),int(attack_rect.end.x),5):
				var y:=attack_rect.position.y+2+int(sin(age*8+x)*2)
				draw_line(Vector2(x,attack_rect.end.y),Vector2(x+2,y),Color(.2,.15,.26),1)


func _build_security()->void:
	var deck:Array=recipe.route.back()
	security_gate=SECURITY_GATE.instantiate()
	security_gate.position=Vector2(float(recipe.width)-32 if recipe.direction>0 else 0,float(deck[1])-32)
	add_child(security_gate)
	gate=security_gate
	gate_shape=security_gate.get_node("Barrier")
	get_parent().set_meta("exit_locked",true)
	# The gate has its own EXIT header, so the older sign must not overlap it.
	var entities:=get_parent().get_node_or_null("Entities")
	if entities!=null:
		for exit in entities.get_children():
			if exit.is_in_group("exit"):
				for visual in exit.get_children():
					if visual is CanvasItem and not visual is CollisionShape2D:visual.hide()
	for i in e.terminals.size():
		var at:Array=e.terminals[i]
		var terminal:Node2D=SECURITY_TERMINAL.instantiate()
		terminal.position=Vector2(at[0],at[1])
		terminal.number=i+1
		terminal.touch_mode=e.get("touch_terminals",false)
		add_child(terminal)
		terminals.append(terminal)
	_update_terminals(Vector2.INF)

func _security_puzzle(p:Vector2,delta:float)->void:
	if not solved:
		var at:Array=e.terminals[step]
		var close:=absf(p.x-float(at[0]))<10 and absf(p.y-(float(at[1])-6))<5
		if close and (e.get("touch_terminals",false) or (player.is_on_floor() and absf(player.velocity.x)<3)):
			pad_dwell+=delta
		else:pad_dwell=0
		if close and pad_dwell>=float(e.charge_seconds):
			step+=1;pad_dwell=0
			_cue.pitch_scale=1+step*.15;_cue.play()
			if step==terminals.size():_solve()
	_update_terminals(p)

func _update_terminals(p:Vector2)->void:
	for i in terminals.size():
		var terminal:Node2D=terminals[i]
		var near:=p.distance_to(terminal.position-Vector2(0,6))<40
		terminal.next_number=mini(step+1,terminals.size())
		terminal.show_state(i==step and not solved,i<step,pad_dwell/maxf(.001,float(e.charge_seconds)),near)
	security_gate.set_progress(step,terminals.size())

func _draw_security_instructions()->void:
	var deck:Array=recipe.route[0]
	var p:=Vector2(8 if recipe.direction>0 else float(recipe.width)-(136 if terminals.size()>3 else 92),40 if e.get("boss",false) else float(deck[1])-48)
	draw_rect(Rect2(p,Vector2(128 if terminals.size()>3 else 84,28)),Color("182637"))
	draw_rect(Rect2(p,Vector2(128 if terminals.size()>3 else 84,28)),Color("668597"),false,1)
	draw_string(PIXEL_FONT,p+Vector2(3,8),"EXIT POWER",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("b2e4e9"))
	var order:=""
	for i in terminals.size():order+=(" - " if i>0 else "")+str(i+1)
	draw_string(PIXEL_FONT,p+Vector2(3,17),order,HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("78e7f2"))
	draw_string(PIXEL_FONT,p+Vector2(3,26),("TOUCH EACH POINT" if e.get("touch_terminals",false) else "STAND STILL"),HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("c1cbd1"))


func _clear_clouds()->void:
	for cloud in clouds:
		if is_instance_valid(cloud):
			cloud.set_physics_process(false);cloud.hide();cloud.queue_free()
	clouds.clear()

func _move_boss(p:Vector2,delta:float)->void:
	if e.get("continuous_chase",false):
		if is_instance_valid(chaser):boss_position=chaser.global_position-origin
		return
	var before:=boss_position
	# Pursuit comes from behind the route. He commits to a firing position
	# during the warning, so the attack cannot swivel after its tell.
	if committed and not solved and warning_left<0 and attack_life<=0:
		var target:=Vector2(clampf(p.x-float(recipe.direction)*72,28,float(recipe.width)-28),clampf(p.y+6,56,float(recipe.height)-24))
		boss_position=boss_position.move_toward(target,float(e.boss_speed)*delta)
	manifestation.set("anchor",boss_position)
	manifestation.set("velocity",(boss_position-before)/maxf(delta,.001))

func _boss_attack(p:Vector2,delta:float)->void:
	if solved and not e.get("continuous_chase",false):return
	clouds=clouds.filter(func(c):return is_instance_valid(c) and not c.is_queued_for_deletion())
	if warning_left>=0:
		warning_left-=delta
		if warning_left<=0:
			warning_left=-1
			if attack_kind=="pulse":
				var cloud:Node2D=CLOUD_SCENE.instantiate()
				cloud.position=attack_rect.get_center()
				cloud.direction=pulse_direction
				cloud.speed=float(e.cloud_speed)
				cloud.player=player
				cloud.room_bounds=world.room_rect(get_parent())
				add_child(cloud);clouds.append(cloud)
				attack_life=0
			else:attack_life=.5
			attack_wait=float(e.attack_interval)
			attack_became_active.emit(attack_kind)
			_cue.pitch_scale=.65;_cue.play()
		return
	if attack_life>0:
		attack_life-=delta
		var hitbox:=player.hitbox_rect();hitbox.position-=origin
		if attack_rect.intersects(hitbox):player.die()
		return
	if phase!=Phase.PRESENT:return
	attack_wait-=delta
	if attack_wait>0 or clouds.size()>=2:return
	var attacks:Array=e.attacks
	attack_kind=attacks[attack_count%attacks.size()];attack_count+=1
	attack_target=p.snapped(Vector2(8,8))
	if attack_kind=="pulse":
		pulse_direction=-1 if p.x<boss_position.x else 1
		attack_rect=Rect2(boss_position+Vector2(pulse_direction*18-8,-11),Vector2(16,10))
	elif attack_kind=="mark":attack_rect=Rect2(attack_target+Vector2(-16,-8),Vector2(32,16))
	else:attack_rect=Rect2(8,144,float(recipe.width)-16,24)
	warning_left=float(e.telegraph)+(0.3 if attack_kind=="sweep" else 0)
	attack_telegraphed.emit(attack_kind,attack_rect)
	_cue.pitch_scale=.8;_cue.play()
