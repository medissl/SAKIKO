extends RefCounted
var game: Node
var phase:=1
var chair_done:=false
var portrait_seen:=false
var reveal_requested:=false
var reveal_time:=-1.0
var reveal_finished:=false
var reveal_seen:=false
var reveal_wait:=0.0
var notice_hold:=0.0
var reveal_fill: SpotLight3D

func clear_reveal_light() -> void:
	if is_instance_valid(reveal_fill): reveal_fill.queue_free()
	reveal_fill=null
var tape_pending:=false
var tape_silence:=0.0
var chase_started:=false
var pressure_cooldown:=0.0
var chase_duration:=0.0

func reset() -> void:
	clear_reveal_light()
	phase=1
	chair_done=false
	portrait_seen=false
	reveal_requested=false
	reveal_time=-1
	reveal_finished=false
	reveal_seen=false
	reveal_wait=0
	notice_hold=0
	tape_pending=false
	tape_silence=0
	chase_started=false
	pressure_cooldown=0
	chase_duration=0
	if game and game.enemy: game.enemy.set_presence(1.0)

func staff_completion() -> void:
	var p: Node=game.progression.story_puzzles
	if chair_done or not p.utility_inventory.has("upper") or not p.utility_inventory.has("festival") or not game.keys[0].get_meta("collected",false): return
	chair_done=true
	phase=2
	game.world_sound("creak",Vector3(13,1,4),-18,.85)

func portrait_closed() -> void:
	if portrait_seen: return
	portrait_seen=true
	reveal_requested=true
	game.hum.volume_db=-30
	game.hum.play()

func outside_view(point: Vector3) -> bool:
	var eye: Vector3=game.player.camera.global_position
	return (-game.player.camera.global_basis.z).dot((point-eye).normalized())<.1 or not game.clear_line(eye,point)

func prepare_tape() -> void:
	if chase_started: return
	clear_reveal_light()
	reveal_requested=false
	reveal_finished=true
	# Fixed backstage anchor, never a visible insertion into an empty corridor.
	var anchor:=Vector3(36,5.7,10)
	if outside_view(anchor):
		game.enemy.set_presence(1.0)
		game.enemy.position=anchor
		game.enemy.hide()
		game.path.clear()

func tape_finished() -> void:
	if chase_started: return
	tape_pending=true
	tape_silence=0

func update(delta: float) -> void:
	if game.mode!="playing": return
	pressure_cooldown=maxf(0,pressure_cooldown-delta)
	if game.ai_state=="chase": chase_duration+=delta
	elif chase_duration>0:
		if chase_duration>=6: pressure_cooldown=60
		chase_duration=0
	if reveal_requested and reveal_time<0 and not game.player_voice.has_event("P07"):
		# Only stage at the far end of a long corridor, after leaving the exhibit.
		var anchor:=Vector3(46 if game.player.position.x<28 else 10,5.7,26)
		if game.player.position.z>24.2 and game.player.position.z<27.8 and absf(anchor.x-game.player.position.x)>23 and outside_view(anchor):
			game.enemy.position=anchor
			game.enemy.set_presence(.65)
			game.enemy.velocity=Vector3.ZERO
			game.enemy.show()
			# A fixed courtyard-window bounce makes the silhouette legible without
			# emissive skin or brightening the school. It never follows the creature.
			reveal_fill=SpotLight3D.new()
			game.add_child(reveal_fill)
			reveal_fill.position=Vector3(anchor.x+(2.8 if anchor.x<28 else -2.8),6.8,24.12)
			reveal_fill.look_at(anchor)
			reveal_fill.light_color=Color("93aabd")
			reveal_fill.light_energy=.32
			reveal_fill.spot_range=5.8
			reveal_fill.spot_angle=44
			reveal_fill.shadow_enabled=false
			reveal_time=0
			game.enemy.look_at(Vector3(game.player.position.x,5.7,game.player.position.z))
	if reveal_time>=0 and not reveal_finished and not chase_started and not game.progression.story_puzzles.played:
		reveal_wait+=delta
		# The distant blink begins when actually noticed, not behind the exhibit wall.
		var eye: Vector3=game.player.camera.global_position
		var alignment: float=(-game.player.camera.global_basis.z).dot((game.enemy.position-eye).normalized())
		if alignment>.985 and game.clear_line(eye,game.enemy.position): notice_hold+=delta
		else: notice_hold=0
		if notice_hold>=.25: reveal_seen=true
		if reveal_seen or reveal_wait>=45: reveal_time+=delta
		if reveal_time>=1.1 and reveal_time<1.1+delta: game.enemy.slow_blink()
		if reveal_time>2.7:
			if game.path.is_empty() and reveal_time<3.5: game.navigate(Vector3(46 if game.enemy.position.x>28 else 10,5.7,22))
			move_reveal(delta)
			if game.enemy.position.z<24 and not game.clear_line(game.player.camera.global_position,game.enemy.position):
				game.enemy.hide()
				clear_reveal_light()
				reveal_finished=true
				game.path.clear()
	if tape_pending and not chase_started:
		tape_silence+=delta
		if tape_silence>1.8 and tape_silence<1.8+delta:
			game.progression.positional_voice(game.enemy.position,game.sounds.player_breath_male if game.sounds.has("player_breath_male") else game.sounds.sakiko_humming,-24,4)
		if tape_silence>=3.2:
			chase_started=true
			phase=3
			tape_pending=false
			game.enemy.show()
			game.progression.hunt_enabled=true
			game.ai_state="investigate"
			game.state_time=0
			game.grace=0
			game.navigate(Vector3(45,5.7,9.5))
			game.save_checkpoint("tape")

func move_reveal(delta: float) -> void:
	if game.path.is_empty(): return
	var offset: Vector3=game.path[0]-game.enemy.position
	if offset.length()<.18: game.path.remove_at(0); return
	var direction: Vector3=offset.normalized()
	game.enemy.velocity=direction*1.35
	game.enemy.rotation.y=lerp_angle(game.enemy.rotation.y,atan2(-direction.x,-direction.z),delta*3)
	game.enemy.move_and_slide()

func snapshot() -> Dictionary:
	return {"phase":phase,"chair_done":chair_done,"portrait_seen":portrait_seen,"reveal_finished":reveal_finished,"chase_started":chase_started}

func restore(data: Dictionary) -> void:
	clear_reveal_light()
	phase=data.phase
	chair_done=data.chair_done
	portrait_seen=data.portrait_seen
	reveal_finished=data.reveal_finished or portrait_seen
	reveal_requested=false
	reveal_time=-1
	chase_started=data.chase_started
	game.enemy.set_presence(1.0)
	tape_pending=false
	pressure_cooldown=60
