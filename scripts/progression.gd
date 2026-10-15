extends Node
const Tuning = preload("res://scripts/config.gd")
var game: Node
var story_puzzles: Node
var evidence: Node
var targets: Array[Dictionary] = []
var solved := [false,false,false]
var discovered := false
var stamina_bar: ProgressBar
var reticle: Label
var eyelids: ColorRect
var exhaustion: ColorRect
var intro_caption: Label
var intro_time := 0.0
var intro_chime := false
var intro_dark := false
var intro_audio: AudioStreamPlayer
var giggle: AudioStreamPlayer3D
var giggle_timer := 7.0
var scream_cooldown := 0.0
var exit_origins: Array[Vector3] = []
var voice: AudioStreamPlayer3D
var cry: AudioStreamPlayer3D
var voice_clock := 14.0
var voice_duration := 0.0
var encounter_time := 0.0
var encounters := [false,false,false]
var last_keys := 0

func positional_voice(point: Vector3,stream: AudioStream,volume: float,seconds: float) -> void:
	voice.position = point
	voice.stream = stream
	voice.volume_db = volume
	voice.pitch_scale = .86
	voice.play()
	voice_duration = seconds

func build(g: Node) -> void:
	game = g
	evidence = preload("res://scripts/evidence.gd").new()
	add_child(evidence)
	evidence.build(game)
	story_puzzles = preload("res://scripts/festival_puzzles.gd").new()
	add_child(story_puzzles)
	story_puzzles.build(game,evidence)
	for p in game.exit_panels: exit_origins.append(p.position)

func setup_ui() -> void:
	exhaustion = ColorRect.new()
	exhaustion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	exhaustion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var effect = ShaderMaterial.new()
	effect.shader = load("res://shaders/exhaustion.gdshader")
	exhaustion.material = effect
	game.gui.add_child(exhaustion)
	game.gui.move_child(exhaustion,0)
	stamina_bar = ProgressBar.new()
	stamina_bar.position = Vector2(38,65)
	stamina_bar.size = Vector2(145,4)
	stamina_bar.scale.y = .18
	stamina_bar.show_percentage = false
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color("8a756a")
	stamina_bar.add_theme_stylebox_override("fill",fill)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(.18,.21,.2,.5)
	stamina_bar.add_theme_stylebox_override("background",bg)
	game.gui.add_child(stamina_bar)
	reticle = game.text_label("·",22)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-8,-15)
	reticle.size = Vector2(16,30)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyelids = ColorRect.new()
	eyelids.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eyelids.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lid_mat = ShaderMaterial.new()
	lid_mat.shader = load("res://shaders/eyelids.gdshader")
	eyelids.material = lid_mat
	game.gui.add_child(eyelids)
	intro_caption = game.text_label("E / SPACE / ESC  -  Skip introduction",16)
	intro_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	intro_caption.position = Vector2(-260,-48)
	intro_caption.size = Vector2(520,30)
	intro_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_audio = AudioStreamPlayer.new()
	intro_audio.bus = "Ambience"
	add_child(intro_audio)
	giggle = AudioStreamPlayer3D.new()
	giggle.stream = game.sounds.sakiko_laugh
	giggle.bus = "Ghost"
	giggle.max_distance = 19
	giggle.unit_size = 2
	giggle.volume_db = -20
	game.enemy.add_child(giggle)
	voice = AudioStreamPlayer3D.new()
	voice.bus = "Ghost"
	voice.unit_size = 7
	voice.max_distance = 28
	game.world.add_child(voice)
	cry = AudioStreamPlayer3D.new()
	cry.stream = game.sounds.sakiko_scream
	cry.bus = "Ghost"
	cry.unit_size = 8
	cry.max_distance = 34
	cry.pitch_scale = .82
	cry.volume_db = -7
	game.enemy.add_child(cry)

func reset() -> void:
	scream_cooldown = 0
	giggle_timer = 12
	giggle.stop()
	voice.stop()
	cry.stop()
	voice_clock = 14
	voice_duration = 0
	encounter_time = 0
	encounters = [false,false,false]
	last_keys = 0
	discovered = false
	story_puzzles.reset()
	solved = story_puzzles.solved
	for i in range(game.exit_panels.size()): game.exit_panels[i].position = exit_origins[i]
	finish_intro(false)

func objective() -> String:
	var suffix: String = "  |  Carrying "+story_puzzles.piece_name(story_puzzles.held) if story_puzzles.held>=0 else ""
	if game.collected==4: return "Return to the entrance  -  4/4  |  J journal"
	if discovered or game.collected>0: return "Find the entrance keys  -  %d/4  |  J journal%s" % [game.collected,suffix]
	return "Find a way out  |  J journal"+suffix

func targeted() -> Dictionary:
	return story_puzzles.targeted()

func interact(item: Dictionary) -> void:
	story_puzzles.interact(item)

func solve(index: int) -> void:
	story_puzzles.solve(index)

func begin_intro() -> void:
	game.mode = "intro"
	game.menu.visible = false
	game.hud.visible = false
	game.prompt.visible = false
	game.message.visible = false
	game.enemy.visible = false
	game.breath.stop()
	game.player.lamp.visible = false
	intro_time = 0
	intro_chime = false
	intro_dark = false
	game.expansion.set_day(true)
	game.player.position = Vector3(-15.17,0,-13.4)
	game.player.rotation = Vector3.ZERO
	game.player.camera.position.y = 1.23
	game.player.camera.look_at(Vector3(-21.5,1.5,-12))
	eyelids.visible = true
	intro_caption.visible = true
	intro_audio.stream = game.sounds.classroom
	intro_audio.volume_db = -14
	intro_audio.play()
	game.curtain.modulate.a = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func finish_intro(play := true) -> void:
	if eyelids:
		eyelids.visible = false
		eyelids.material.set_shader_parameter("closure",0)
		intro_caption.visible = false
		intro_audio.stop()
	game.expansion.set_day(false)
	if play:
		game.player.position = Vector3(-15.17,0,-12.35)
		game.player.rotation = Vector3.ZERO
		game.player.pitch = 0
		game.player.camera.position.y = 1.58
		game.player.camera.rotation = Vector3(0,PI/2,0)
		game.player.rotation.y = PI/2
		game.player.camera.rotation = Vector3.ZERO
		game.player.lamp.visible = true
		game.player.velocity = Vector3.ZERO
		game.enemy.visible = true
		game.grace = 18
		game.breath.play()
		game.resume_game()
		game.toast("The classroom is empty. Find the entrance.  |  E interact · F light · SHIFT sprint",7)

func _unhandled_input(event: InputEvent) -> void:
	if game.mode=="intro" and (event.is_action_pressed("interact") or event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.physical_keycode==KEY_SPACE)):
		finish_intro()
		get_viewport().set_input_as_handled()
	elif game.mode=="puzzle" and event.is_action_pressed("pause"):
		game.resume_game()
		get_viewport().set_input_as_handled()

func spotted() -> void:
	if scream_cooldown<=0:
		voice.stop()
		cry.play()
		scream_cooldown = Tuning.SCREAM_COOLDOWN

func _process(delta: float) -> void:
	if not stamina_bar: return
	var playing: bool = game.mode=="playing"
	stamina_bar.visible = playing
	reticle.visible = playing
	exhaustion.visible = playing
	if playing:
		encounter_time += delta
		voice_clock -= delta
		voice_duration -= delta
		if voice_duration<=0: voice.stop()
		if voice_clock<=0 and game.ai_state!="chase":
			var ahead: Vector3 = game.player.camera.global_position-game.player.camera.global_basis.z*8
			positional_voice(Vector3(ahead.x,1.5,game.player.position.z),game.sounds.sakiko_humming,-17,6)
			voice_clock = randf_range(30,48)
		if not encounters[0] and encounter_time>9 and game.player.position.z> -7:
			encounters[0] = true
			positional_voice(Vector3(-7,1.0,-5),game.sounds.close,-13,2)
		if not encounters[1] and game.player.position.x>28:
			encounters[1] = true
			positional_voice(Vector3(43,1.5,-6),game.sounds.sakiko_humming,-12,7)
			voice_clock = 35
		if game.collected>last_keys:
			last_keys = game.collected
			var behind: Vector3 = game.player.camera.global_position+game.player.camera.global_basis.z*6
			positional_voice(behind,game.sounds.sakiko_laugh if last_keys>1 else game.sounds.close,-13,4)
			voice_clock = 28
		stamina_bar.value = game.player.stamina
		exhaustion.material.set_shader_parameter("fatigue",game.player.fatigue)
		exhaustion.material.set_shader_parameter("reduced",game.settings.reduced)
		var target: Dictionary = game.interactable()
		reticle.text = "◇" if not target.is_empty() else "·"
		reticle.modulate = Color("ae6761") if not target.is_empty() else Color("9a9d91")
		scream_cooldown = maxf(0,scream_cooldown-delta)
		giggle_timer -= delta
		var distance: float = game.enemy.position.distance_to(game.player.position)
		var obstructed: bool = not game.clear_line(game.enemy.position,game.player.camera.global_position)
		game.breath.volume_db = -25 if obstructed else -17
		giggle.volume_db = -29 if obstructed else -14
		if giggle_timer<0 and distance<19 and distance>2 and game.ai_state!="chase":
			giggle.play()
			giggle_timer = randf_range(18,30)
	else:
		giggle.stop()
		voice.stop()
		cry.stop()
	if game.mode=="intro":
		intro_time += delta
		var t: float = intro_time
		var close := 0.0
		if t<7:
			var glance := PI/2+sin(t*.85+.9)*.85*(1-smoothstep(4.6,7.0,t))
			game.player.camera.rotation.y = lerp_angle(game.player.camera.rotation.y,glance,delta*1.5)
			game.player.camera.rotation.x = sin(t*.4)*.035
			close = maxf(exp(-pow((t-2.8)/.21,2))*.8,exp(-pow((t-5.1)/.5,2))*.94)
		elif t<9:
			close = clampf((t-7)/1.5,0,1)
			game.player.camera.rotation.x = lerpf(0,-.26,(t-7)/2)
			intro_audio.volume_db = -14-(t-7)*20
		elif t<12:
			close = 1
			if not intro_dark:
				intro_dark = true
				game.expansion.set_day(false)
				intro_audio.stop()
			if not intro_chime and t>9.5:
				intro_chime = true
				intro_audio.stream = game.sounds.chime
				intro_audio.volume_db = -15
				intro_audio.play()
		else:
			close = clampf(1-(t-12)/2.1,0,1)
			close = maxf(close,.65*exp(-pow((t-14.3)/.19,2)))
			game.player.camera.rotation.x = lerpf(-.26,0,clampf((t-12)/3,0,1))
			var stand := smoothstep(13.4,15.0,t)
			game.player.position.z = lerpf(-13.4,-12.35,stand)
			game.player.camera.position.y = lerpf(1.23,1.58,stand)
		eyelids.material.set_shader_parameter("closure",close)
		if t>15: finish_intro()

