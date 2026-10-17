extends RefCounted
var game: Node
var reveal_requested:=false
var reveal_finished:=false
var reveal_seen:=false
var notice_hold:=0.0
var reveal_time:=-1.0
var reveal_wait:=0.0
var reveal_fill: SpotLight3D
var chase_started:=false
var pressure_cooldown:=0.0
var chase_duration:=0.0
var approach_time:=0.0
var pursuit_clock:=-1.0
var retreating:=false
var later_presence:=false
func clear_reveal_light() -> void:
	if is_instance_valid(reveal_fill): reveal_fill.queue_free()
	reveal_fill=null
func reset() -> void:
	clear_reveal_light()
	reveal_requested=false
	reveal_finished=false
	reveal_seen=false
	notice_hold=0
	reveal_time=-1
	reveal_wait=0
	chase_started=false
	pressure_cooldown=0
	approach_time=0
	pursuit_clock=-1
	retreating=false
	later_presence=false
	if game and game.enemy: game.enemy.allow_idle_blink=true
	if game and game.enemy: game.enemy.face_material.set_shader_parameter("face_variant",1.0)
func staff_completion() -> void: pass
func prepare_tape() -> void: pass
func tape_finished() -> void: pass
func portrait_closed() -> void:
	if game.progression.story_puzzles.stage!=3 or reveal_finished: return
	reveal_requested=true
	game.progression.story_puzzles.flags.portrait=true
	game.progression.story_puzzles.advance(4)
func outside_view(point: Vector3) -> bool:
	var camera: Camera3D=game.player.camera
	return not camera.is_position_in_frustum(point) or not game.clear_line(camera.global_position,point)
func update(delta: float) -> void:
	if game.mode!="playing": return
	pressure_cooldown=maxf(0,pressure_cooldown-delta)
	if approach_time>0:
		approach_time-=delta
		if approach_time<=0: game.grace=0
	if retreating:
		if game.path.is_empty():
			retreating=false
		else: move_reveal(delta,1.5)
	# A missed look is telemetry, never a story lock. The downstairs approach ends this section.
	if reveal_requested and not reveal_finished and game.player.position.y<2.5:
		finish_watcher(not reveal_seen)
	if chase_started and game.progression.story_puzzles.stage>=6 and pressure_cooldown<=0 and not later_presence and game.ai_state not in ["chase","investigate","search"]:
		# The same actor approaches via the green stairs, never behind the closed shutter.
		later_presence=true
		game.ai_state="middle_approach"
		game.navigate(Vector3(10,5.7,10))
	var flow: Node=game.progression.story_puzzles
	if flow.stage>=6 and game.enemy.visible and game.enemy.position.y>4.5 and game.enemy.position.distance_to(flow.WINCH_POINT)<16 and not flow.flags.get("middle_warning",false):
		flow.flags.middle_warning=true
		var cue: AudioStreamPlayer3D=game.world_sound("sakiko_humming",game.enemy.position,-9,1.8)
		cue.bus="Ghost"
		cue.unit_size=5
		cue.max_distance=18
		cue.reparent(game.enemy,true)
	if not reveal_requested or reveal_finished: return
	reveal_wait+=delta
	var p: Vector3=game.player.position
	if reveal_time<0:
		var anchor:=Vector3(46,5.7,26)
		var first_view: bool=p.y>3.5 and p.z>24 and p.z<28 and p.x<29 and p.x>23 and not game.progression.story_puzzles.flags.get("first_view_missed",false)
		var second_view:=p.y>3.5 and p.z>24 and p.z<28 and p.x>=33 and p.x<43
		if second_view: anchor=Vector3(10,5.7,26)
		# Keep the earlier distant composition. Never stage a near replacement.
		second_view=second_view and absf(anchor.x-p.x)>=23
		if (first_view or second_view) and outside_view(anchor):
			game.enemy.position=anchor
			game.enemy.allow_idle_blink=false
			game.enemy.face_material.set_shader_parameter("face_variant",0.0)
			game.enemy.set_presence(.65)
			game.enemy.show()
			game.enemy.look_at(Vector3(p.x,5.7,p.z))
			reveal_time=0
			reveal_fill=SpotLight3D.new()
			game.add_child(reveal_fill)
			reveal_fill.position=Vector3(anchor.x+(2.8 if anchor.x<28 else -2.8),6.8,24.12)
			reveal_fill.look_at(anchor)
			reveal_fill.light_color=Color("93aabd")
			reveal_fill.light_energy=.32
			reveal_fill.spot_range=5.8
			reveal_fill.spot_angle=44
		if reveal_wait>20 and not game.progression.story_puzzles.flags.get("sighting_cue",false):
			game.progression.story_puzzles.flags.sighting_cue=true
			game.world_sound("creak",anchor,-13,.85)
		return
	var camera: Camera3D=game.player.camera
	var face: Vector3=game.enemy.position
	var alignment: float=(-camera.global_basis.z).dot((face-camera.global_position).normalized())
	if camera.is_position_in_frustum(face) and alignment>.65 and game.clear_line(camera.global_position,face): notice_hold+=delta
	if notice_hold>=2: reveal_seen=true
	# A player walking toward her sees a withdrawal, never an advancing close-up.
	if not reveal_seen and camera.global_position.distance_to(face)>18: return
	reveal_time+=delta
	if reveal_time>=.15 and reveal_time<.15+delta: game.enemy.slow_blink()
	if reveal_time>1.2:
		if game.path.is_empty() and reveal_time<1.2+delta*2: game.navigate(Vector3(46 if game.enemy.position.x>28 else 10,5.7,22))
		move_reveal(delta,1.35)
		if game.enemy.position.z<24 and not game.clear_line(camera.global_position,game.enemy.position):
			finish_watcher(not reveal_seen)
func finish_watcher(missed: bool) -> void:
	game.enemy.hide()
	game.enemy.allow_idle_blink=true
	game.enemy.face_material.set_shader_parameter("face_variant",1.0)
	clear_reveal_light()
	game.path.clear()
	var flow: Node=game.progression.story_puzzles
	if missed and game.player.position.y>3.5 and not flow.flags.get("first_view_missed",false):
		flow.flags.first_view_missed=true
		reveal_time=-1
		notice_hold=0
		return
	reveal_finished=true
	flow.flags.sighting=not missed
	flow.flags.watcher_missed=missed
	game.save_checkpoint("CP3")

func move_reveal(delta: float, speed: float) -> void:
	if game.path.is_empty(): return
	var offset: Vector3=game.path[0]-game.enemy.position
	if offset.length()<.18: game.path.remove_at(0); return
	var direction: Vector3=offset.normalized()
	game.enemy.velocity=direction*speed
	game.enemy.rotation.y=lerp_angle(game.enemy.rotation.y,atan2(-direction.x,-direction.z),delta*3)
	game.enemy.move_and_slide()
func start_pursuit() -> void:
	if chase_started: return
	var anchor:=Vector3(51.4,1.5,17.8)
	# East approach is behind the corridor corner. Never insert in the player's view.
	if not outside_view(anchor): return
	var flow: Node=game.progression.story_puzzles
	chase_started=true
	pursuit_clock=game.clock
	flow.flags.chase_started=true
	game.enemy.position=anchor
	game.enemy.show()
	game.enemy.allow_idle_blink=true
	game.enemy.face_material.set_shader_parameter("face_variant",1.0)
	game.enemy.set_presence(1)
	game.player.stamina=100
	game.player.exhausted=false
	game.progression.hunt_enabled=true
	game.ai_state="approach"
	game.last_seen=Vector3(45,1.5,9.8)
	game.navigate(game.last_seen)
	approach_time=4.5
	game.grace=0
	game.state_time=0
	game.world_sound("creak",anchor,-7,.85)
	game.toast("Break her line of sight. Close doors behind you.",5)
func disengage() -> void:
	var flow: Node=game.progression.story_puzzles
	game.ai_state="withdraw"
	game.state_time=0
	game.path.clear()
	game.navigate(Vector3(46,1.5,26))
	retreating=true
	pressure_cooldown=55
	if not flow.flags.get("escape_done",false):
		flow.flags.escape_done=true
		flow.advance(6,"CP5")
		game.player_voice.say("She lost you. Keep moving.")
func snapshot() -> Dictionary:
	return {"sighting":reveal_finished,"chase_started":chase_started,"later_presence":later_presence}
func restore(data: Dictionary) -> void:
	reset()
	reveal_finished=data.get("sighting",false)
	chase_started=data.get("chase_started",false)
	later_presence=data.get("later_presence",false)
	pressure_cooldown=55
