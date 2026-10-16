extends Node
const Tuning = preload("res://scripts/config.gd")
var encounters_controller=preload("res://scripts/school_encounters.gd").new()
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
var intro_stand := false
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
var first_discovery := false
var hunt_enabled := false
var discovery_time := 0.0
var sighting_time := -1.0
var intro_look := Vector2.ZERO
var classroom_filter: AudioEffectLowPassFilter
var lesson_panel: PanelContainer
var lesson_dialogue: Label
const INTRO_DURATION := 145.0
const LESSON_END := 125.0

func positional_voice(point: Vector3,stream: AudioStream,volume: float,seconds: float) -> void:
	voice.position = point
	voice.stream = stream
	voice.volume_db = volume-(10 if absf(point.y-game.player.camera.global_position.y)>2.5 else 0)
	voice.pitch_scale = .86
	voice.play()
	voice_duration = seconds

func build(g: Node) -> void:
	game = g
	encounters_controller.game=g
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
	stamina_bar.anchor_left = .26
	stamina_bar.anchor_right = .74
	stamina_bar.anchor_top = 1
	stamina_bar.anchor_bottom = 1
	stamina_bar.offset_left = 0
	stamina_bar.offset_right = 0
	stamina_bar.offset_top = -10
	stamina_bar.offset_bottom = -6
	stamina_bar.max_value = 100
	stamina_bar.show_percentage = false
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(.34,.12,.13,.70)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	stamina_bar.add_theme_stylebox_override("fill",fill)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(.018,.012,.014,.64)
	bg.border_color = Color(.20,.075,.08,.36)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	stamina_bar.add_theme_stylebox_override("background",bg)
	game.gui.add_child(stamina_bar)
	reticle = game.text_label("·",22)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.offset_left=-8
	reticle.offset_right=8
	reticle.offset_top=-15
	reticle.offset_bottom=15
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyelids = ColorRect.new()
	eyelids.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eyelids.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lid_mat = ShaderMaterial.new()
	lid_mat.shader = load("res://shaders/eyelids.gdshader")
	eyelids.material = lid_mat
	game.gui.add_child(eyelids)
	intro_caption = game.text_label("E / SPACE / ESC  -  Skip lesson",16)
	intro_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	intro_caption.offset_left=-260
	intro_caption.offset_right=260
	intro_caption.offset_top=-48
	intro_caption.offset_bottom=-18
	intro_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lesson_panel=PanelContainer.new()
	lesson_panel.anchor_left=.19
	lesson_panel.anchor_right=.81
	lesson_panel.anchor_top=1
	lesson_panel.anchor_bottom=1
	lesson_panel.offset_top=-156
	lesson_panel.offset_bottom=-76
	lesson_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var backing:=StyleBoxFlat.new()
	backing.bg_color=Color(.015,.02,.018,.91)
	backing.content_margin_left=22
	backing.content_margin_right=22
	backing.content_margin_top=12
	backing.content_margin_bottom=12
	lesson_panel.add_theme_stylebox_override("panel",backing)
	game.gui.add_child(lesson_panel)
	lesson_dialogue=game.text_label("",19,lesson_panel)
	lesson_dialogue.add_theme_font_override("font",game.serif)
	lesson_dialogue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	lesson_dialogue.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	lesson_panel.hide()
	intro_audio = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("Classroom")<0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count-1,"Classroom")
		AudioServer.set_bus_send(AudioServer.bus_count-1,"Ambience")
	classroom_filter = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Classroom"),classroom_filter)
	AudioServer.add_bus_effect(AudioServer.get_bus_index("TeacherVoice"),classroom_filter)
	intro_audio.bus = "Classroom"
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
	first_discovery=false
	hunt_enabled = false
	discovery_time = 0
	sighting_time = -1
	discovered = false
	story_puzzles.reset()
	encounters_controller.reset()
	solved = story_puzzles.solved
	for i in range(game.exit_panels.size()): game.exit_panels[i].position = exit_origins[i]
	finish_intro(false)

func objective() -> String:
	if discovered or game.collected>0: return "Keys  %d / 4" % game.collected
	return ""

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
	intro_look = Vector2.ZERO
	game.expansion.time = 0
	classroom_filter.cutoff_hz = 18000
	stamina_bar.hide()
	reticle.hide()
	exhaustion.hide()
	game.interaction_hints.hide()
	game.player.velocity = Vector3.ZERO
	intro_chime = false
	intro_dark = false
	intro_stand = false
	game.expansion.set_day(true)
	game.player.position = game.layout.SEATED
	game.player.rotation = Vector3.ZERO
	game.player.camera.position.y = 1.23
	game.player.rotation.y = PI/2
	game.player.camera.rotation = Vector3.ZERO
	eyelids.visible = true
	intro_caption.visible = true
	intro_audio.stream = load("res://assets/audio/classroom_foley.wav")
	if intro_audio.stream is AudioStreamWAV:
		intro_audio.stream.loop_end=int(intro_audio.stream.get_length()*intro_audio.stream.mix_rate)
		intro_audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	intro_audio.pitch_scale = 1.0
	intro_audio.volume_db = 0
	intro_audio.play()
	game.curtain.modulate.a = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func finish_intro(play := true) -> void:
	if eyelids:
		lesson_panel.hide()
		eyelids.visible = false
		eyelids.material.set_shader_parameter("closure",0)
		intro_caption.visible = false
		intro_audio.stop()
	game.expansion.set_day(false)
	if play:
		game.player.position = game.layout.NIGHT
		game.player.rotation = Vector3.ZERO
		game.player.pitch = 0
		game.player.camera.position.y = 1.58
		game.player.camera.rotation = Vector3(0,PI/2,0)
		game.player.rotation.y = PI/2
		game.player.camera.rotation = Vector3.ZERO
		game.player.lamp.visible = true
		game.player.lamp.light_energy = 3.2
		game.player.spill.light_energy = .38
		game.player.velocity = Vector3.ZERO
		game.enemy.visible = false
		game.grace = 8
		game.breath.stop()
		game.resume_game()

func _unhandled_input(event: InputEvent) -> void:
	if game.mode=="intro" and event is InputEventMouseMotion:
		intro_look=(intro_look-event.relative*game.settings.sensitivity*.001).clamp(Vector2(-.65,-.30),Vector2(.65,.30))
		get_viewport().set_input_as_handled()
	if game.mode=="intro" and (event.is_action_pressed("interact") or event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.physical_keycode==KEY_SPACE)):
		if intro_time<LESSON_END: intro_time=LESSON_END
		get_viewport().set_input_as_handled()
	elif game.mode=="puzzle" and event.is_action_pressed("pause"):
		game.resume_game()
		get_viewport().set_input_as_handled()

func spotted() -> void:
	game.enemy.detected()
	if scream_cooldown<=0:
		voice.stop()
		cry.play()
		game.hum.volume_db=-34
		game.hum.play()
		scream_cooldown = Tuning.SCREAM_COOLDOWN

func _process(delta: float) -> void:
	if not stamina_bar: return
	var playing: bool = game.mode=="playing"
	stamina_bar.visible = playing
	reticle.visible = playing
	exhaustion.visible = playing
	if playing:
		stamina_bar.modulate.a=move_toward(stamina_bar.modulate.a,1.0 if game.player.stamina<99 or game.player.is_running else 0.0,delta*2)
		encounters_controller.update(delta)
		voice_duration-=delta
		if voice_duration<=0: voice.stop()
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
		game.breath.volume_db = (-25 if obstructed else -17)-(10 if absf(game.enemy.position.y-game.player.camera.global_position.y)>2.5 else 0)
		giggle.volume_db = -29 if obstructed else -14
		if hunt_enabled and giggle_timer<0 and distance<19 and distance>2 and game.ai_state!="chase":
			giggle.play()
			giggle_timer = randf_range(42,68)
	else:
		giggle.stop()
		voice.stop()
		cry.stop()
	if game.mode=="intro":
		intro_time += delta
		var t: float = intro_time
		lesson_panel.visible=t<LESSON_END and game.settings.subtitles
		intro_caption.visible=t<LESSON_END
		lesson_dialogue.text=game.expansion.lesson_caption(t)
		var close := 0.0
		if t<LESSON_END:
			close=maxf(.82*exp(-pow((fmod(t+3,13.7)-6)/.17,2)),.7*exp(-pow((fmod(t,21.3)-9)/.22,2)))
			if t>100:
				close=maxf(close,.90*exp(-pow((t-113)/1.2,2)))
				classroom_filter.cutoff_hz=lerpf(18000,1800,smoothstep(100,125,t))
		elif t<128:
			close=lerpf(.25,1,smoothstep(125,127.8,t))
			intro_audio.volume_db=lerpf(0,-65,smoothstep(125,128,t))
			classroom_filter.cutoff_hz=lerpf(1800,500,smoothstep(125,128,t))
			intro_look=intro_look.lerp(Vector2.ZERO,minf(1,delta*1.5))
		elif t<132:
			close=1
			if not intro_dark:
				intro_dark=true
				game.expansion.set_day(false)
				intro_audio.stop()
			if not intro_chime and t>=130:
				intro_chime=true
				classroom_filter.cutoff_hz=18000
				intro_audio.stream=game.sounds.school_bell
				intro_audio.pitch_scale=1.0
				intro_audio.volume_db=-18
				intro_audio.play()
		else:
			close=maxf(1-smoothstep(132,136,t),.8*exp(-pow((t-134)/.5,2)))
		var nod: float=.23*smoothstep(125,128,t)*(1-smoothstep(132,137,t))
		var settle := 1.0-smoothstep(140.5,144.8,t)
		game.player.camera.rotation=Vector3(intro_look.y*settle-nod,intro_look.x*settle,0)
		var stand:=smoothstep(141,145,t)
		game.player.position=game.layout.SEATED.lerp(game.layout.NIGHT,stand)
		game.player.camera.position.y=lerpf(1.23,1.58,stand)
		if t>=141:
			if not intro_stand:
				intro_stand=true
				game.world_sound("creak",game.layout.SEATED+Vector3(0,.5,0),-23,.85)
				game.world_sound("bag_fabric",game.player.camera.global_position,-20,.7)
			game.player.lamp.visible=true
			game.player.lamp.light_energy=3.2*smoothstep(143,145,t)
			game.player.spill.light_energy=.38*smoothstep(143,145,t)
		eyelids.material.set_shader_parameter("closure",close)
		if t>=INTRO_DURATION: finish_intro()

func staff_completion() -> void: encounters_controller.staff_completion()
func portrait_closed() -> void: encounters_controller.portrait_closed()
func prepare_tape_encounter() -> void: encounters_controller.prepare_tape()
func tape_finished() -> void: encounters_controller.tape_finished()
