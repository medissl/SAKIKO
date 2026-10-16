extends CharacterBody3D
const Tuning = preload("res://scripts/config.gd")
var game: Node
var camera: Camera3D
var lamp: SpotLight3D
var spill: SpotLight3D
var pitch := 0.0
var walking := false
var stamina := 100.0
var exhausted := false
var recovery_timer := 0.0
var fatigue := 0.0
var footstep_count := 0
var is_running:=false
var stride_remaining:=.25
var pant: AudioStreamPlayer
var sway := Vector2.ZERO

func _ready() -> void:
	floor_snap_length=.30
	collision_layer = 1
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = .28
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = .85
	add_child(cs)
	camera = Camera3D.new()
	camera.position.y = 1.58
	camera.near = .06
	camera.fov = 64
	add_child(camera)
	lamp = SpotLight3D.new()
	lamp.position = Vector3(.16,-.12,-.1)
	lamp.light_color = Color("ced4c1")
	lamp.light_energy = 3.2
	lamp.spot_range = 20
	lamp.spot_angle = 26
	lamp.spot_attenuation = .8
	lamp.spot_angle_attenuation = 2.2
	lamp.light_size = .035
	lamp.light_projector = load("res://assets/textures/beam.png")
	lamp.shadow_enabled = true
	lamp.shadow_bias = .045
	camera.add_child(lamp)
	spill = SpotLight3D.new()
	spill.light_color = Color("a8afa1")
	spill.light_energy = .38
	spill.spot_range = 8
	spill.spot_angle = 68
	spill.spot_attenuation = .6
	spill.spot_angle_attenuation = 2.4
	spill.shadow_enabled = true
	lamp.add_child(spill)
	pant = AudioStreamPlayer.new()
	pant.stream = load("res://assets/audio/player_breath_male.mp3")
	pant.bus = "PlayerSFX"
	pant.volume_db = -60
	add_child(pant)
	pant.finished.connect(func():
		if fatigue>.02 and game.mode=="playing": pant.play())

func reset() -> void:
	stamina = 100
	exhausted = false
	recovery_timer = 0
	fatigue = 0
	stride_remaining=.25
	walking = false
	pant.stop()
	pant.volume_db = -60
	camera.position = Vector3(0,1.58,0)
	lamp.rotation = Vector3.ZERO
	lamp.light_energy = 3.2
	spill.light_energy = .38

func _unhandled_input(event: InputEvent) -> void:
	if game.mode != "playing": return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x*game.settings.sensitivity*.001
		pitch = clampf(pitch-event.relative.y*game.settings.sensitivity*.001,-1.45,1.45)
		camera.rotation.x = pitch
		sway += event.relative*.00012
	if event.is_action_pressed("flashlight"):
		lamp.visible = not lamp.visible
		game.sound("latch",-22)
	if event.is_action_pressed("interact"): game.interact()

func _physics_process(delta: float) -> void:
	if game.mode != "playing" or not game.input_focused:
		cancel_movement()
		return
	pant.stream_paused = false
	var input := Input.get_vector("left","right","forward","back")
	var dir := transform.basis*Vector3(input.x,0,input.y)
	var shift_held: bool=Input.is_action_pressed("sprint") or Input.is_action_pressed("sprint_left") or Input.is_action_pressed("sprint_right")
	var wants_run := shift_held and input.length()>.1 and not exhausted and stamina>0
	var speed := Tuning.SPRINT_SPEED if wants_run else Tuning.WALK_SPEED
	velocity.x = move_toward(velocity.x,dir.x*speed,delta*22)
	velocity.z = move_toward(velocity.z,dir.z*speed,delta*22)
	velocity.y -= 20*delta
	var before := global_position
	move_and_slide()
	var moved := Vector2(position.x-before.x,position.z-before.z).length()/maxf(delta,.0001)
	walking = input.length()>.1 and moved>.45 and is_on_floor()
	var running := wants_run and walking
	is_running=running
	update_stamina(delta,running)
	if walking:
		stride_remaining-=moved*delta
		if stride_remaining<=0:
			stride_remaining+=1.24 if running else 1.16
			game.footstep(running)
			footstep_count += 1
	else:
		stride_remaining=.25
		game.stop_player_steps()
	sway = sway.lerp(Vector2.ZERO,minf(1,delta*7))
	lamp.rotation = lamp.rotation.lerp(Vector3(clampf(sway.y,-.025,.025),clampf(sway.x,-.025,.025),0),minf(1,delta*9))

func cancel_movement() -> void:
	velocity.x=0
	velocity.z=0
	walking=false
	is_running=false
	stride_remaining=.25
	if pant: pant.stop()
	if game: game.stop_player_steps()

func update_stamina(delta: float,running: bool) -> void:
	if running:
		stamina = maxf(0,stamina-Tuning.STAMINA_DRAIN*delta)
		recovery_timer = Tuning.RECOVERY_DELAY
		if stamina<=0: exhausted = true
	else:
		recovery_timer = maxf(0,recovery_timer-delta)
		if recovery_timer<=0: stamina = minf(100,stamina+Tuning.STAMINA_RECOVERY*delta)
	if exhausted and stamina>=Tuning.RESTART_THRESHOLD: exhausted = false
	var effect := clampf((32-stamina)/32.0,0,1) if exhausted or stamina<20 else 0.0
	fatigue = move_toward(fatigue,effect,delta*.7)
	pant.volume_db = linear_to_db(maxf(.0001,fatigue*.22))+3.0
	if fatigue>.05 and not pant.playing and game.mode=="playing": pant.play()
	if fatigue<.015: pant.stop()
