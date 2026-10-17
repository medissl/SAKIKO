extends Node3D
## All coordinates are metres. Two parallel corridors loop at both ends.
const Creature = preload("res://scripts/creature.gd")
const Tuning = preload("res://scripts/config.gd")
const Expansion = preload("res://scripts/school_expansion.gd")
const Progression = preload("res://scripts/progression.gd")
const Player = preload("res://scripts/player.gd")
const ROOMS = ["1年 A組", "2年 B組", "保健室", "職員室", "3年 C組", "視聴覚室"]
# Balance against recorded footsteps; avoid amplifying already-loud scare vocals.
const INTERACTION_GAIN := {"locked":9.0,"door_track":7.0,"latch":6.0,"close":7.0,"drawer_slide":7.0,"cabinet_hinge":7.0,"bag_fabric":7.0,"case_latch":7.0,"paper_lift":8.0,"paper_flip":8.0,"photo_handle":8.0,"shelf_track":6.0,"lock_turn":7.0,"shackle_release":7.0,"key":5.0,"unlock":5.0,"code_tick":10.0,"creak":5.0,"quiet_knocks":5.0,"staff_knocks":5.0}
var ending: Control
var ending_started := false
var hardware=preload("res://scripts/school_hardware.gd").new()
var entrance_locks: Array[Node3D] = []
var props=preload("res://scripts/school_props.gd").new()
var finishing=preload("res://scripts/school_finishing.gd").new()
var audio_trace: Array[Dictionary]=[]
var input_focused:=true
var studio_intro: CanvasLayer
var menu_indicator: ColorRect
var menu_selection: Button
var main_menu_return:="PLAY"
var nav_buttons: Array[Button]=[]
var moving_sounds: Array[WeakRef]=[]
var last_step_sample: Dictionary={}
var player_steps: Array[WeakRef]=[]
var audio_production: Dictionary={"tape_captions":[]}
var voice_quality: Dictionary={"player_enabled":false,"teacher_enabled":false,"tape_enabled":false}
var layout: Node3D
var expansion: Node
var progression: Node
var music: AudioStreamPlayer
var nav_blocked := {}
var mode := "menu"
var world: Node3D
var player_voice: Node
var chase_layer: AudioStreamPlayer
var player: CharacterBody3D
var enemy: CharacterBody3D
var menu_camera: Camera3D
var scare_camera: Camera3D
var scare_head: CharacterBody3D
var interaction_hints: Control
var gui: Control
var menu: Control
var hud: Label
var prompt: Label
var message: Label
var film: ColorRect
var curtain: ColorRect
var keys: Array[Node3D] = []
var doors: Array[Dictionary] = []
var obstacles: Array[AABB] = []
var materials := {}
var static_boxes: Array[MeshInstance3D]=[]
var compare_static_geometry:="--profile-compare" in OS.get_cmdline_user_args()
var box_meshes: Dictionary={}
var static_optimizer: RefCounted
var sounds := {}
var lights: Array[OmniLight3D] = []
var nav := AStar3D.new()
var nav_lookup := {}
var aimed_frame:=-1
var aimed_cache: Dictionary={}
var interaction_cache_enabled:=true
var path := PackedVector3Array()
var waypoint := Vector3.ZERO
var target := Vector3.ZERO
var last_seen := Vector3.ZERO
var ai_state := "roam"
var state_time := 0.0
var lost_sight := 0.0
var visual_notice := 0.0
var repath := 0.0
var stuck_time := 0.0
var previous_enemy := Vector3.ZERO
var grace := 0.0
var collected := 0
var exit_open := false
var checkpoint_state: Dictionary={}
var checkpoint_id:="start"
var checkpoint := Vector3(15.46,0,2.7)
var pain_triggered := false
var capture_ghost: AudioStreamPlayer
var capture_scream_started:=false
var capture_blink_started:=false
var objective_age:=0.0
var objective_text:=""
var exit_panels: Array[MeshInstance3D] = []
var clock := 0.0
var breath: AudioStreamPlayer3D
var ambient: AudioStreamPlayer
var hum: AudioStreamPlayer
var creak_clock := 11.0
var capture_time := 0.0
var message_time := 0.0
var settings := {"master": .8,"ambience": .65,"sfx": .8,"voice":.8,"subtitles":true,"sensitivity": 2.0,"fullscreen": false,"shake": true,"reduced":false,"msaa":2}
var options_return := "menu"
var font: Font
var serif: SystemFont
var horror_font: Font
var desk_asset: PackedScene
var chair_asset: PackedScene
var exit_point := Vector3(.19,0,12)
var room_key_points: Array[Array] = []

func _ready() -> void:
	randomize()
	get_tree().auto_accept_quit = false
	setup_input()
	load_settings()
	setup_audio()
	# Keep startup loading and the developer splash silent, including warm-up frames.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)
	font = load("res://assets/fonts/SakikoSchoolSans.ttf")
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia","Times New Roman"])
	horror_font = load("res://assets/fonts/SakikoThorn.ttf")
	horror_font.fallbacks = [font]
	# Cover warm-up render frames as well as the timed splash; no school flash.
	studio_intro = preload("res://scripts/studio_intro.gd").new()
	add_child(studio_intro)
	studio_intro.setup(self)
	studio_intro.active=false
	desk_asset = load("res://assets/furniture/desk/desk.gltf")
	chair_asset = load("res://assets/furniture/chair/chair.gltf")
	hardware.game=self
	props.game=self
	if FileAccess.file_exists("res://assets/audio/production.json"): audio_production=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/production.json"))
	make_materials()
	finishing.setup(self)
	build_school()
	if "--layout-shell" in OS.get_cmdline_user_args():
		studio_intro.queue_free()
		studio_intro=null
		set_process(false)
		set_physics_process(false)
		mode="playing"
		player=Player.new()
		player.game=self
		add_child(player)
		player.position=Vector3(10,0,10)
		call_deferred("verify_layout_shell")
		return
	layout.build_furniture()
	props.dress(layout)
	finishing.representatives(layout)
	finishing.complete_rooms(layout)
	if "--profile-compare" in OS.get_cmdline_user_args():
		static_optimizer=preload("res://scripts/static_geometry.gd").new()
		static_optimizer.build(self,static_boxes)
	static_boxes.clear()
	expansion = Expansion.new()
	add_child(expansion)
	expansion.build(self)
	progression = Progression.new()
	add_child(progression)
	progression.build(self)
	build_navigation()
	player = Player.new()
	player.game = self
	add_child(player)
	enemy = Creature.new()
	add_child(enemy)
	breath = AudioStreamPlayer3D.new()
	breath.stream = sounds.sakiko_humming
	breath.pitch_scale = .96
	breath.bus = "Ghost"
	breath.volume_db = -13
	breath.max_distance = 23
	breath.unit_size = 3
	enemy.add_child(breath)
	# Creature vocals are discrete local events, never a permanent breathing bed.
	menu_camera = Camera3D.new()
	menu_camera.position = Vector3(10,1.65,10)
	add_child(menu_camera)
	menu_camera.look_at(Vector3(46,1.5,10))
	menu_camera.fov = 68
	scare_camera = Camera3D.new()
	scare_camera.position = Vector3(0,-40,0)
	scare_camera.fov = 72
	scare_camera.near = .06
	add_child(scare_camera)
	scare_head = Creature.new()
	scare_head.position = Vector3(0,-40,-2.5)
	scare_head.rotation.y = PI
	scare_head.collision_layer = 0
	scare_head.collision_mask = 0
	add_child(scare_head)
	scare_head.visible = false
	var light := SpotLight3D.new()
	light.position = Vector3(.5,-39.5,-.2)
	light.light_energy = 2.3
	light.spot_range = 6
	light.spot_angle = 65
	light.light_color = Color("bcc8c4")
	add_child(light)
	build_gui()
	progression.setup_ui()
	player_voice=preload("res://scripts/school_voice.gd").new()
	add_child(player_voice)
	player_voice.build(self)
	var environment_audio:=preload("res://scripts/environment_audio.gd").new()
	add_child(environment_audio)
	environment_audio.build(self)
	await warm_capture_assets()
	show_main_menu()
	# Startup only: returning from OPTIONS / CREATOR never replays the branding.
	mode = "studio_intro"
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	menu.release_focus()
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus,true)
	studio_intro.active=true
	await studio_intro.finished
	studio_intro = null
	mode = "menu"
	menu.process_mode = Node.PROCESS_MODE_INHERIT
	AudioServer.set_bus_mute(master_bus,settings.master<=0)
	if is_instance_valid(menu_selection): menu_selection.grab_focus()
	# An external local driver can exercise the exact export without shipping QA files.
	var launch_args:=OS.get_cmdline_user_args()
	if "--release-qa" in launch_args:
		var driver_path: String=launch_args[launch_args.find("--release-qa")+1]
		await load(driver_path).new().run(self)
		return
	if not OS.has_feature("editor"): return
	if "--verify" in OS.get_cmdline_user_args(): call_deferred("verify_game")
	if "--render-audit" in OS.get_cmdline_user_args(): call_deferred("render_audit")
	if "--interaction-audit" in OS.get_cmdline_user_args(): call_deferred("interaction_audit")
	if "--presentation-audit" in OS.get_cmdline_user_args(): call_deferred("presentation_audit")
	if "--bake-courtyard" in OS.get_cmdline_user_args(): call_deferred("bake_courtyard")
	if "--scenery-render" in OS.get_cmdline_user_args(): call_deferred("scenery_render")
	if "--corrections-render" in OS.get_cmdline_user_args(): call_deferred("corrections_render")
	if "--bugfix-lighting-render" in OS.get_cmdline_user_args(): call_deferred("bugfix_lighting_render")
	if "--bugfix-check" in OS.get_cmdline_user_args(): call_deferred("bugfix_check")
	if "--profile-route" in OS.get_cmdline_user_args(): call_deferred("profile_route")
	if "--placement-audit" in OS.get_cmdline_user_args(): call_deferred("placement_audit")
	if "--nonverbal-check" in OS.get_cmdline_user_args(): call_deferred("nonverbal_check")
	if "--master-ui-check" in OS.get_cmdline_user_args(): call_deferred("master_ui_check")
	if "--bugfix-menu-render" in OS.get_cmdline_user_args(): call_deferred("bugfix_menu_render")
	if "--revamp-render" in OS.get_cmdline_user_args(): call_deferred("polish_render_audit")
	if "--polish-render" in OS.get_cmdline_user_args(): call_deferred("polish_render_audit")

func setup_input() -> void:
	for side in [["sprint_left",KEY_LOCATION_LEFT],["sprint_right",KEY_LOCATION_RIGHT]]:
		if not InputMap.has_action(side[0]): InputMap.add_action(side[0])
		var shift:=InputEventKey.new()
		shift.physical_keycode=KEY_SHIFT
		shift.location=side[1]
		InputMap.action_add_event(side[0],shift)
	var bindings := {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"interact":KEY_E,"flashlight":KEY_F,"pause":KEY_ESCAPE,"journal":KEY_J}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = bindings[action]
		InputMap.action_add_event(action,ev)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		for k in settings: settings[k] = cfg.get_value("settings",k,settings[k])

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings: cfg.set_value("settings",k,settings[k])
	cfg.save("user://settings.cfg")
	apply_settings()

func apply_settings() -> void:
	get_viewport().msaa_3d=clampi(int(settings.msaa),0,2)
	for pair in [["Master","master"],["Ambience","ambience"],["SFX","sfx"],["Voice","voice"],["Ghost","voice"],["CreatureDry","voice"]]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(pair[0]),linear_to_db(maxf(.0001,settings[pair[1]])))
		AudioServer.set_bus_mute(AudioServer.get_bus_index(pair[0]),settings[pair[1]]<=0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func setup_audio() -> void:
	voice_quality=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voice_quality.json"))
	for bus in ["Ambience","SFX","PlayerSFX","WorldSFX","Ghost","CreatureDry","Voice","TeacherVoice","Classroom"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Ghost"),"SFX")
	for bus in ["PlayerSFX","WorldSFX","CreatureDry"]: AudioServer.set_bus_send(AudioServer.get_bus_index(bus),"SFX")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("PlayerSFX"),-1)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("WorldSFX"),0)
	if AudioServer.get_bus_effect_count(0)==0:
		var limiter:=AudioEffectHardLimiter.new()
		limiter.ceiling_db=-1.0
		limiter.pre_gain_db=0
		AudioServer.add_bus_effect(0,limiter)
	AudioServer.set_bus_send(AudioServer.get_bus_index("TeacherVoice"),"Voice")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Classroom"),"Ambience")
	if AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Ghost"))==0:
		var room := AudioEffectReverb.new()
		room.room_size = .38
		room.damping = .7
		room.wet = .16
		room.dry = .92
		AudioServer.add_bus_effect(AudioServer.get_bus_index("Ghost"),room)
	for clip_name in ["ambience","hum","creak","step","hover","press","key","unlock","locked","door","breath","chase","capture","menu_music","chime","school_bell","classroom","run_step","pant","giggle","scream","latch","close","capture_v2","player_pain","quiet_knocks","staff_knocks"]:
		sounds[clip_name] = load("res://assets/audio/%s.wav" % clip_name)
	# Warm short interaction resources once, outside movement and puzzle input.
	for clip_name in ["door_track","shelf_track","drawer_slide","cabinet_hinge","bag_fabric","case_latch","paper_lift","paper_flip","photo_handle","lock_turn","shackle_release","code_tick"]:
		sounds[clip_name]=load("res://assets/audio/%s.wav" % clip_name)
	sounds.locked=load("res://assets/audio/locked_rattle.wav")
	for surface in ["wood","tile","stair"]:
		for gait in ["walk","run"]:
			for index in range(3):
				var clip_name:="foot_%s_%s_%d" % [surface,gait,index]
				sounds[clip_name]=load("res://assets/audio/%s.wav" % clip_name)
	sounds.sakiko_humming = load("res://assets/audio/sakiko_humming.ogg")
	sounds.sakiko_scream = load("res://assets/audio/sakiko_scream.ogg")
	sounds.sakiko_laugh = load("res://assets/audio/sakiko_laugh.ogg")
	sounds.capture_shriek=load("res://assets/audio/sakiko_capture_shriek.wav")
	sounds.chase_shriek=load("res://assets/audio/sakiko_chase_shriek.wav")
	capture_ghost=AudioStreamPlayer.new()
	capture_ghost.bus="CreatureDry"
	add_child(capture_ghost)
	ambient = AudioStreamPlayer.new()
	ambient.stream = load("res://assets/audio/building_roomtone.wav")
	ambient.bus = "Ambience"
	ambient.volume_db = -12
	add_child(ambient)
	ambient.finished.connect(ambient.play)
	ambient.play()
	hum = AudioStreamPlayer.new()
	hum.stream = load("res://assets/audio/suspense_texture.wav")
	hum.volume_db = -24
	hum.bus = "Ambience"
	add_child(hum)
	# A finite authored texture; ordinary room tone carries the quiet sections.
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/menu_theme.ogg")
	music.bus = "Ambience"
	music.volume_db = -60
	add_child(music)
	music.finished.connect(music.play)
	music.play()
	apply_settings()

func sound(clip_name: String, db := -10.0, pitch := 1.0) -> void:
	if mode=="quitting" or not sounds.has(clip_name): return
	var p := AudioStreamPlayer.new()
	p.stream = sounds[clip_name]
	p.volume_db = db + float(INTERACTION_GAIN.get(clip_name,0.0))
	p.pitch_scale = pitch
	p.bus = "Ghost" if clip_name.begins_with("sakiko_") else "SFX"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func world_sound(clip: String,point: Vector3,db: float,duration: float=0.0) -> AudioStreamPlayer3D:
	audio_trace.append({"clip":clip,"point":point})
	if audio_trace.size()>32: audio_trace.pop_front()
	var audio:=AudioStreamPlayer3D.new()
	audio.stream=sounds.get(clip,sounds.latch)
	audio.position=point
	audio.volume_db=db + float(INTERACTION_GAIN.get(clip,0.0))
	if player and absf(point.y-player.camera.global_position.y)>2.5: audio.volume_db-=10
	elif player:
		var q:=PhysicsRayQueryParameters3D.create(player.camera.global_position,point,1)
		q.exclude=[player.get_rid()]
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(q)
		# A latch inside its own panel is not a distant sound behind a room wall.
		if not hit.is_empty() and hit.position.distance_to(point)>.4: audio.volume_db-=6
	audio.bus="WorldSFX"
	audio.unit_size=3
	audio.max_distance=20
	world.add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
	if duration>0:
		var weak: WeakRef=weakref(audio)
		moving_sounds.append(weak)
		get_tree().create_timer(duration).timeout.connect(func():
			var live: AudioStreamPlayer3D=weak.get_ref()
			if live: live.stop(); live.queue_free())
	return audio

func footstep(running: bool) -> void:
	var surface: String=contact_surface()
	var family: String="foot_"+surface+("_run_" if running else "_walk_")
	var index: int=randi_range(0,2)
	if index==int(last_step_sample.get(family,-1)): index=(index+1+randi_range(0,1))%3
	last_step_sample[family]=index
	var sample: String=family+str(index)
	var audio:=world_sound(sample,player.position+Vector3(0,.08,0),-13 if running else -16)
	audio.bus="PlayerSFX"
	player_steps=player_steps.filter(func(weak): return weak.get_ref()!=null)
	player_steps.append(weakref(audio))
	if progression.hunt_enabled and grace<=0 and ai_state!="chase":
		var reach: float=5.5 if running else 2.0
		var origin: Vector3=player.position+Vector3(0,1.2,0)
		if not clear_line(enemy.position,origin): reach*=.4
		if absf(enemy.position.y-origin.y)<1.8 and enemy.position.distance_to(origin)<reach:
			last_seen=player.position+Vector3(0,1.5,0)
			lost_sight=0
			ai_state="investigate"
			state_time=0
			navigate(last_seen)

func stop_player_steps() -> void:
	for weak in player_steps:
		var audio: AudioStreamPlayer3D=weak.get_ref()
		if audio: audio.stop(); audio.queue_free()
	player_steps.clear()

func contact_surface() -> String:
	var q:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3(0,.22,0),player.global_position-Vector3(0,.42,0),1)
	q.exclude=[player.get_rid()]
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var node: Node=hit.collider
		while node and node!=world:
			if node.has_meta("step_surface"): return node.get_meta("step_surface")
			node=node.get_parent()
	return "wood"

func persist_voice_flags() -> void:
	if checkpoint_state.is_empty(): return
	checkpoint_state.voice=player_voice.snapshot()
	var saved:=FileAccess.open("user://checkpoint-flow-v5.save",FileAccess.WRITE)
	if saved: saved.store_var(checkpoint_state); saved.close()

func make_materials() -> void:
	for item in [["wall","a1aaa1","plaster"],["floor","adb1a4","floor"],["wood","b7a38b","wood"],["ceiling","93998f","ceiling"],["dark","171e1c",""],["metal","64716b",""],["chalk","203e37",""],["paper","b2b1a0",""],["red","5f2325",""],["glass","263f45",""],["gold","c8a454",""]]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(item[1])
		m.roughness = .96
		if item[2] != "":
			m.albedo_texture = load("res://assets/textures/%s.png" % item[2])
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(.45,.45,.45)
		if item[0]=="glass": m.albedo_texture = load("res://assets/textures/window.png")
		materials[item[0]] = m
	var window_view := ShaderMaterial.new()
	window_view.shader = load("res://shaders/window_view.gdshader")
	window_view.set_shader_parameter("courtyard",load("res://assets/textures/window_courtyard_atlas.png"))
	window_view.set_shader_parameter("dirt",load("res://assets/textures/window.png"))
	materials.window_view = window_view
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("bac8b3")
	glow.emission_enabled = true
	glow.emission = Color("9cb7aa")
	glow.emission_energy_multiplier = 1.6
	materials.light = glow
	for pair in [["wall","plastered_wall"],["floor","wood_floor_worn"]]:
		var mat: StandardMaterial3D = materials[pair[0]]
		mat.albedo_color = Color(.66,.69,.65) if pair[0]=="wall" else Color(.72,.77,.75)
		mat.albedo_texture = load("res://assets/surfaces/%s_diff.jpg" % pair[1])
		mat.normal_enabled = true
		mat.normal_texture = load("res://assets/surfaces/%s_nor_gl.jpg" % pair[1])
		mat.normal_scale = .5
		mat.roughness_texture = load("res://assets/surfaces/%s_rough.jpg" % pair[1])
		mat.uv1_scale = Vector3.ONE*.5

func make_exterior_window(cx: float,side: int,dx: float,room: int) -> void:
	var z := side*16.84
	var small := side>0 and room==3
	var height := .65 if small else 1.5
	var y := 2.35 if small else 2.05
	var pane := box(Vector3(cx+dx,y,z),Vector3(2.9,height,.035),"window_view",false)
	var mat: ShaderMaterial = materials.window_view.duplicate()
	mat.set_shader_parameter("room_center",cx+(-7 if side>0 else 0))
	mat.set_shader_parameter("outside_side",side)
	mat.set_shader_parameter("view_offset",room*.09+(.13 if side>0 else 0.0))
	var clear_view := side<0 and room in [0,3] and dx<0
	mat.set_shader_parameter("obscured",not clear_view)
	pane.material_override = mat
	pane.add_to_group("exterior_panes")
	for off in [-1.5,0.0,1.5]: box(Vector3(cx+dx+off,y,z-side*.10),Vector3(.055,height+.12,.10),"metal",false)
	for h in [-height/2-.05,height/2+.05]: box(Vector3(cx+dx,y+h,z-side*.13),Vector3(3.15,.10,.19),"wood",false)
	if not clear_view and not small:
		# Venetian blinds obscure repeated views; each room has a different drop.
		var drop := 5+posmod(room+(1 if dx>0 else 0),5)
		for slat in range(drop):
			var strip := box(Vector3(cx+dx,y+height/2-.05-slat*.10,z-side*.20),Vector3(2.98,.085,.025),"metal",false)
			strip.rotation.x = .28*side
		for cord in [-1.1,1.1]: box(Vector3(cx+dx+cord,y+.15,z-side*.23),Vector3(.008,1.2,.008),"paper",false)

func box(pos: Vector3, size: Vector3, mat: String, solid := true, parent: Node3D = null) -> MeshInstance3D:
	if parent == null: parent = world
	var mi := MeshInstance3D.new()
	if not box_meshes.has(size):
		var shared:=BoxMesh.new()
		shared.size=size
		box_meshes[size]=shared
	var mesh: BoxMesh=box_meshes[size]
	mi.mesh = mesh
	if compare_static_geometry: static_boxes.append(mi)
	mi.material_override = materials[mat]
	mi.position = pos
	parent.add_child(mi)
	if solid:
		var b := StaticBody3D.new()
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		c.shape = s
		b.add_child(c)
		mi.add_child(b)
		var dynamic:=false
		var ancestor: Node=parent
		while ancestor and ancestor!=world:
			if ancestor.get_meta("dynamic_nav",false): dynamic=true; break
			ancestor=ancestor.get_parent()
		if not dynamic: obstacles.append(mi.global_transform*AABB(-size*.5,size))
	return mi

func label3(text: String, pos: Vector3, yaw := 0.0, scale_factor := .009, color := Color("c3c7b2")) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 40
	l.pixel_size = scale_factor
	l.modulate = color
	l.position = pos
	l.rotation.y = yaw
	l.no_depth_test = false
	l.shaded=true
	l.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	world.add_child(l)
	return l

func lamp(pos: Vector3, energy: float, tint: Color, shadows := false) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_energy = energy*.38
	l.light_color = tint
	l.omni_range = 10
	l.omni_attenuation = 1.5
	l.shadow_enabled = shadows
	l.set_meta("day_energy",energy*.38)
	l.set_meta("night_energy",0.0)
	world.add_child(l)
	var fixture:=Node3D.new()
	fixture.position=pos
	fixture.set_meta("placement_category","CEILING_FIXTURE")
	world.add_child(fixture)
	box(Vector3(0,.12,0),Vector3(1.15,.075,.24),"metal",false,fixture)
	box(Vector3(0,.073,0),Vector3(1.06,.025,.18),"paper",false,fixture)
	var floor_y: float=4.2 if pos.y>4.2 else 0.0
	var ceiling_y: float=floor_y+3.2
	if (pos.x<8 or pos.x>48) and pos.z>=16 and pos.z<=24: ceiling_y=4.0 if floor_y==0 else 7.4
	for x in [-.45,.45]: box(Vector3(x,(ceiling_y-pos.y+.16)/2,0),Vector3(.014,maxf(.02,ceiling_y-pos.y-.16),.014),"metal",false,fixture)
	lights.append(l)

func build_school() -> void:
	world = Node3D.new()
	world.name = "School"
	add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("080f15")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("72878b")
	e.ambient_light_energy = .075
	e.ambient_light_sky_contribution=0
	e.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("142226")
	e.fog_density = .008
	e.fog_sky_affect = 0
	env.environment = e
	world.add_child(env)
	layout=preload("res://scripts/school_layout.gd").new()
	world.add_child(layout)
	layout.build_geometry(self)
	for door in doors: fit_door_tracks(door)

func desk(pos: Vector3,yaw := 0.0) -> Node3D:
	var group := Node3D.new()
	group.position = pos
	group.rotation.y = yaw
	world.add_child(group)
	layout.placement.grounded_asset(desk_asset,group,Vector3.ZERO,0,.95)
	layout.placement.grounded_asset(chair_asset,group,Vector3(0,0,.83),PI,.91)
	# Simple invisible collision volumes preserve the detailed imported silhouette.
	var table_collision := box(Vector3(0,.80,0),Vector3(.70,.1,.56),"wood",true,group)
	table_collision.visible = false
	var chair_collision := box(Vector3(0,.43,.83),Vector3(.50,.10,.50),"wood",true,group)
	chair_collision.visible = false
	return group

func make_door(pos: Vector3, side: int) -> void:
	var root:=Node3D.new()
	root.position=pos
	root.set_meta("placement_category","DOORWAY_ASSEMBLY")
	root.set_meta("dynamic_nav",true)
	world.add_child(root)
	var panels: Array[Node3D]=[]
	var shapes: Array[CollisionShape3D]=[]
	# Jambs occupy the architectural reveal, not the wall's end faces.
	for x in [-1.045,1.045]: box(Vector3(x,1.36,0),Vector3(.07,2.72,.19),"wood",false,root)
	for y in [.025,2.72]: box(Vector3(0,y,0),Vector3(2.16,.05,.20),"metal",false,root)
	# Two surface tracks stack the full-size leaves over one metre of solid wall.
	for i in range(2):
		var leaf:=Node3D.new()
		leaf.position=Vector3(-.5 if i==0 else .5,0,side*(.20+i*.14))
		root.add_child(leaf)
		panels.append(leaf)
		box(Vector3(0,.54,0),Vector3(1.02,1.04,.055),"wood",false,leaf)
		for x in [-.49,.49]: box(Vector3(x,1.86,0),Vector3(.045,1.60,.055),"wood",false,leaf)
		for y in [1.10,2.66]: box(Vector3(0,y,0),Vector3(1.02,.06,.055),"wood",false,leaf)
		box(Vector3(0,1.88,0),Vector3(.93,1.48,.018),"glass",false,leaf)
		box(Vector3(0,1.88,0),Vector3(.93,.03,.055),"wood",false,leaf)
		for face in [-1,1]: box(Vector3(.38 if i==0 else -.38,1.02,face*.041),Vector3(.035,.18,.02),"dark",false,leaf)
		var body:=StaticBody3D.new()
		leaf.add_child(body)
		var cs:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=Vector3(1.02,2.68,.06)
		cs.shape=shape
		cs.position.y=1.34
		body.add_child(cs)
		shapes.append(cs)
	doors.append({"node":root,"shape":shapes[0],"shapes":shapes,"panels":panels,"origin":pos,"open":false,"busy":false,"slide_direction":1.0,"track_side":side,"requirement":"","locked":false})

func fit_door_tracks(d: Dictionary) -> void:
	var track:=box(Vector3(float(d.slide_direction)*.55,2.75,float(d.track_side)*.27),Vector3(3.26,.07,.27),"metal",false,d.node)
	track.set_meta("track",true)
	for z in [.20,.34]:
		box(Vector3(float(d.slide_direction)*.55,.035,float(d.track_side)*z),Vector3(3.26,.015,.025),"metal",false,d.node)
	for x in [-float(d.slide_direction)*1.06,float(d.slide_direction)*2.10]: box(Vector3(x,2.68,float(d.track_side)*.27),Vector3(.035,.10,.27),"metal",false,d.node)

func walkable(p: Vector3) -> bool:
	return layout.allowed_position(p)

func build_navigation(clearance:=.86) -> void:
	nav.clear()
	nav_lookup.clear()
	nav_blocked.clear()
	var bounds: Array[AABB]=obstacles.duplicate()
	if progression and progression.story_puzzles.flags.get("middle_section_active",false) and not progression.story_puzzles.flags.get("east_landing_unbolted",false):
		bounds.append(AABB(Vector3(47.7,4.2,17.85),Vector3(.6,2.72,2.3)))
	if progression and progression.story_puzzles.flags.get("bolted",false):
		bounds.append(AABB(Vector3(27.8,0,7.5),Vector3(2.4,2.7,.7)))
	for dynamic in get_tree().get_nodes_in_group("moving_obstruction"):
		for mesh in dynamic.find_children("*","MeshInstance3D",true,false):
			if mesh.get_child_count()>0: bounds.append(mesh.global_transform*mesh.get_aabb())
	for level in range(2):
		var floor_y: float=level*4.2
		for obstacle in bounds:
			if obstacle.position.y>floor_y+2.5 or obstacle.end.y<floor_y+.35: continue
			var a: AABB=obstacle.grow(clearance)
			for x in range(ceili(a.position.x*2),floori(a.end.x*2)+1):
				for z in range(ceili(a.position.z*2),floori(a.end.z*2)+1): nav_blocked[Vector3i(x,z,level)]=true
		for x in range(0,113):
			for z in range(0,73):
				var cell:=Vector3i(x,z,level)
				var point:=Vector3(x*.5,floor_y,z*.5)
				if walkable(point) and not nav_blocked.has(cell):
					var id:=nav.get_available_point_id()
					nav.add_point(id,point+Vector3(0,1.5,0))
					nav_lookup[cell]=id
	for cell in nav_lookup:
		for offset in [Vector3i(1,0,0),Vector3i(0,1,0)]:
			if nav_lookup.has(cell+offset): nav.connect_points(nav_lookup[cell],nav_lookup[cell+offset])
	for route in layout.stair_routes:
		var previous: int=-1
		for i in range(route.size()):
			var id:=nav.get_available_point_id()
			nav.add_point(id,route[i]+Vector3(0,1.5,0))
			if previous>=0: nav.connect_points(previous,id)
			if i==0 or i==route.size()-1:
				var cell:=Vector3i(roundi(route[i].x*2),roundi(route[i].z*2),0 if i==0 else 1)
				if nav_lookup.has(cell): nav.connect_points(id,nav_lookup[cell])
			previous=id

func navigate(to: Vector3) -> void:
	var a := nav.get_closest_point(enemy.position)
	var b := nav.get_closest_point(to)
	path = nav.get_point_path(a,b)
	if path.size()>1: path.remove_at(0)
	target = to

func build_gui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	gui = Control.new()
	gui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(gui)
	film = ColorRect.new()
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/film.gdshader")
	film.material = sm
	gui.add_child(film)
	interaction_hints = preload("res://scripts/interaction_hints.gd").new()
	interaction_hints.game = self
	gui.add_child(interaction_hints)
	hud = text_label("",16)
	hud.add_theme_font_override("font",serif)
	hud.add_theme_color_override("font_color",Color("a6aaa2"))
	hud.position = Vector2(32,26)
	prompt = text_label("",18)
	prompt.add_theme_font_override("font",serif)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left=-290
	prompt.offset_right=290
	prompt.offset_top=-110
	prompt.offset_bottom=-65
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message = text_label("",17)
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message.offset_left=-440
	message.offset_right=440
	message.offset_top=-65
	message.offset_bottom=-25
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gui.add_child(menu)
	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.modulate.a = 0
	gui.add_child(curtain)

func text_label(value: String, size_px: int, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_override("font",horror_font)
	l.add_theme_font_size_override("font_size",size_px)
	l.add_theme_color_override("font_color",Color("c8c9be"))
	l.add_theme_color_override("font_shadow_color",Color.BLACK)
	l.add_theme_constant_override("shadow_offset_x",2)
	l.add_theme_constant_override("shadow_offset_y",2)
	(parent if parent != null else gui).add_child(l)
	return l

func clear_menu() -> void:
	if player: player.cancel_movement()
	stop_movement_audio()
	nav_buttons.clear()
	menu_selection=null
	menu_indicator=null
	for c in menu.get_children():
		menu.remove_child(c)
		c.queue_free()
	menu.visible = true
	prompt.text = ""
	interaction_hints.cues.clear()
	interaction_hints.hide()
	hud.visible = false
	prompt.visible = false
	message.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func button(value: String, action: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = value
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(260,46)
	b.add_theme_font_override("font",horror_font)
	b.add_theme_font_size_override("font_size",23)
	b.add_theme_color_override("font_color",Color("d2d0c5"))
	b.add_theme_color_override("font_hover_color",Color("9a4547"))
	b.add_theme_color_override("font_focus_color",Color("a65456"))
	b.add_theme_color_override("font_pressed_color",Color("d96360"))
	for state in ["normal","hover","pressed","disabled"]: b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0,0,0,.08)
	focus.border_color = Color("6c3033")
	focus.border_width_left = 2
	focus.content_margin_left = 12
	b.add_theme_stylebox_override("focus",focus)
	b.mouse_entered.connect(func(): sound("hover",-25))
	b.focus_entered.connect(func(): sound("hover",-25))
	b.pressed.connect(func(): sound("press",-21); action.call())
	parent.add_child(b)
	return b

func panel_stack(title: String, subtitle: String) -> VBoxContainer:
	clear_menu()
	var dim := ColorRect.new()
	dim.color = Color(.012,.018,.020,.83)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(490,0)
	v.add_theme_constant_override("separation",8)
	center.add_child(v)
	var l := text_label(title,48,v)
	l.visible=not title.is_empty()
	l.add_theme_font_override("font",horror_font)
	l.add_theme_color_override("font_color",Color("8f353a"))
	text_label(subtitle,16,v)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	v.add_child(spacer)
	# Containers settle their minimum sizes on the following frame. Keep the
	# content transparent until that first layout is complete (still laid out).
	v.modulate.a=0
	reveal_panel.call_deferred(v)
	return v

func reveal_panel(content: Variant) -> void:
	if not is_instance_valid(content): return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(content) or not content.is_inside_tree(): return
	create_tween().tween_property(content,"modulate:a",1.0,.10)

func show_main_menu() -> void:
	load_saved_checkpoint()
	if hum: hum.stop()
	if is_instance_valid(ending): ending.queue_free()
	ending = null
	film.show()
	mode = "menu"
	if player_voice: player_voice.flush()
	if progression: progression.finish_intro(false)
	if player: player.pant.stop()
	clear_menu()
	menu_camera.current = true
	enemy.visible = false
	scare_head.visible = false
	breath.stop()
	ambient.volume_db = -12
	hum.volume_db = -24
	film.material.set_shader_parameter("trauma",0)
	curtain.modulate.a = 0
	var shade := ColorRect.new()
	shade.color = Color(.01,.015,.018,.33)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var title_box := VBoxContainer.new()
	title_box.anchor_left = .57
	title_box.anchor_right = .94
	title_box.anchor_top = .13
	title_box.anchor_bottom = .4
	menu.add_child(title_box)
	var title := text_label("SAKIKO",108,title_box)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_override("font",horror_font)
	title.add_theme_color_override("font_color",Color("7c262e"))
	# A restrained procedural erosion treatment on the title glyphs.
	var ink := Shader.new()
	ink.code = "shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV)*COLOR; float n=fract(sin(dot(FRAGCOORD.xy,vec2(7.13,81.7)))*43758.5); c.rgb*=.67+.33*step(.18,n); COLOR=c;}"
	var ink_mat := ShaderMaterial.new()
	ink_mat.shader = ink
	title.material = ink_mat
	var jp := text_label("さ  き  こ",27,title_box)
	jp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	jp.add_theme_color_override("font_color",Color("935153"))
	var sub := text_label("THE LAST BELL HAS RUNG",13,title_box)
	sub.add_theme_font_override("font",horror_font)
	sub.add_theme_font_size_override("font_size",18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sub.modulate.a = .62
	var navbox := VBoxContainer.new()
	navbox.anchor_left = .09
	navbox.anchor_top = .52
	navbox.anchor_right = .36
	navbox.anchor_bottom = .88
	navbox.add_theme_constant_override("separation",9)
	menu.add_child(navbox)
	var first: Button
	if not checkpoint_state.is_empty():
		navbox.anchor_top=.46
		first=button("CONTINUE",return_to_checkpoint,navbox)
		button("PLAY",play_intro,navbox)
	else: first=button("PLAY",play_intro,navbox)
	button("OPTIONS",func(): options_return="menu"; show_options(),navbox)
	button("CREATOR",show_credits,navbox)
	button("EXIT",quit_game,navbox)
	for nav_button in navbox.get_children():
		nav_buttons.append(nav_button)
		nav_button.add_theme_font_override("font",horror_font)
		nav_button.add_theme_font_size_override("font_size",32)
		nav_button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		nav_button.mouse_entered.connect(func(): select_menu_item(nav_button,true))
		nav_button.focus_entered.connect(func(): select_menu_item(nav_button))
		nav_button.pressed.connect(func(): main_menu_return=nav_button.text)
	menu_indicator=ColorRect.new()
	menu_indicator.color=Color("763239")
	menu_indicator.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu.add_child(menu_indicator)
	for nav_button in nav_buttons:
		if nav_button.text==main_menu_return: first=nav_button; break
	first.grab_focus()
	select_menu_item(first)
	var control_label := text_label("W A S D   MOVE     /     SHIFT   RUN     /     E   INTERACT     /     F   LIGHT     /     ESC   PAUSE",13,menu)
	control_label.anchor_top = 1
	control_label.position = Vector2(42,-38)

func show_options() -> void:
	var v := panel_stack("OPTIONS","Make the silence comfortable.")
	for row in [["Master volume","master",0.0,1.0,.01],["Ambience","ambience",0.0,1.0,.01],["Sound effects","sfx",0.0,1.0,.01],["Creature sounds","voice",0.0,1.0,.01],["Mouse sensitivity","sensitivity",.3,5.0,.1]]:
		var heading:=HBoxContainer.new();v.add_child(heading)
		var name_label:=text_label(row[0],17,heading);name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var value_label:=text_label("%.1f" % settings[row[1]] if row[1]=="sensitivity" else "%d%%" % roundi(settings[row[1]]*100),17,heading)
		var slider := HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = row[4]
		slider.value = settings[row[1]]
		var key: String = row[1]
		slider.value_changed.connect(func(value):
			settings[key]=value
			value_label.text="%.1f" % value if key=="sensitivity" else "%d%%" % roundi(value*100)
			save_settings())
		v.add_child(slider)
	for row in [["Subtitles","subtitles"],["Fullscreen","fullscreen"],["Camera shake","shake"],["Reduced analog / blur effects","reduced"]]:
		var check := CheckButton.new()
		check.text = row[0]
		check.button_pressed = settings[row[1]]
		check.add_theme_font_override("font",horror_font)
		var key: String = row[1]
		check.toggled.connect(func(on): settings[key]=on; save_settings())
		v.add_child(check)
	var quality_row:=HBoxContainer.new();v.add_child(quality_row)
	var quality_label:=text_label("Anti-aliasing",17,quality_row);quality_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var quality:=OptionButton.new();quality_row.add_child(quality)
	for label in ["Off","2x","4x"]: quality.add_item(label)
	quality.select(clampi(int(settings.msaa),0,2))
	quality.item_selected.connect(func(index): settings.msaa=index;save_settings())
	quality.tooltip_text="Smooths edges. Lower values can improve performance."
	button("BACK",options_back,v)
	v.get_child(4).grab_focus()

func options_back() -> void:
	if options_return=="pause": show_pause()
	else: show_main_menu()

func select_menu_item(item: Button,mouse:=false) -> void:
	if not is_instance_valid(item) or item.disabled or not item.is_visible_in_tree(): return
	menu_selection=item
	if mouse: item.grab_focus()
	update_menu_indicator.call_deferred()

func update_menu_indicator() -> void:
	if not is_instance_valid(menu_indicator): return
	if not is_instance_valid(menu_selection) or menu_selection.disabled or not menu_selection.is_visible_in_tree():
		menu_indicator.hide()
		for item in nav_buttons:
			if is_instance_valid(item) and not item.disabled and item.is_visible_in_tree(): menu_selection=item; break
		if not is_instance_valid(menu_selection) or menu_selection.disabled or not menu_selection.is_visible_in_tree(): return
	if menu_indicator.get_parent()!=menu_selection: menu_indicator.reparent(menu_selection,false)
	var face: Font=menu_selection.get_theme_font("font")
	var size_px: int=menu_selection.get_theme_font_size("font_size")
	menu_indicator.position=Vector2(-12,(menu_selection.size.y-face.get_height(size_px)*.8)*.5)
	menu_indicator.size=Vector2(2,face.get_height(size_px)*.8)
	menu_indicator.show()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST: quit_game(); return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if is_instance_valid(progression) and is_instance_valid(progression.story_puzzles): progression.story_puzzles.stop_crank()
		# A scripted benchmark must not silently turn into a pause-menu workload.
		if "--profile-route" in OS.get_cmdline_user_args(): return
		input_focused=false
		for action in InputMap.get_actions(): Input.action_release(action)
		if is_instance_valid(player): player.cancel_movement()
		if mode=="playing": call_deferred("pause_after_focus_loss")
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_WM_WINDOW_FOCUS_IN]: input_focused=true

func pause_after_focus_loss() -> void:
	if mode=="playing" and not input_focused: show_pause()

func show_credits() -> void:
	var v := panel_stack("CREATOR", "SAKIKO / さきこ")
	v.custom_minimum_size.x = 670
	var heading := text_label("Hi hi, its Medi here, your favorite indie developer",25,v)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label("I like making strange little games and seeing where they lead.\nThanks for stepping into SAKIKO and spending a little time in its halls.\nI hope something follows you out  -  just a feeling, hopefully.\n\nThanks for playing.  -  Medi",18,v)
	var github := button("Check out my GitHub for more games",func(): OS.shell_open(Tuning.CREATOR_GITHUB_URL),v)
	github.disabled = Tuning.CREATOR_GITHUB_URL.is_empty()
	if github.disabled: github.text += " (unavailable  -  not configured)"
	text_label("People: Innerscene / MakeHuman. Furniture: Ethan Place / Poly Haven.\nMenu music: brandon75689. Male voice: HaelDB.\nOriginal ghost surface, meshes, fonts and remaining audio. Built with Godot.\nFull asset provenance: ASSET_SOURCES.md",13,v)
	button("BACK",show_main_menu,v).grab_focus()

func play_intro() -> void:
	start_game()
	progression.begin_intro()

func start_game() -> void:
	backup_legacy_save()
	if is_instance_valid(ending): ending.queue_free()
	ending = null
	ending_started = false
	mode = "transition"
	curtain.modulate.a = 1
	clear_menu()
	menu.visible = false
	collected = 0
	checkpoint_state.clear()
	checkpoint_id="start"
	if player_voice: player_voice.reset()
	hardware.reset()
	exit_open = false
	for p in exit_panels: p.material_override = materials.metal
	for k in keys:
		if is_instance_valid(k): k.free()
	keys.clear()
	for d in doors:
		if d.has("tween") and d.tween: d.tween.kill()
		d.open = false
		d.busy = false
		d.node.position = d.origin
		for cs in d.shapes: cs.disabled=false
		for i in range(2): d.panels[i].position.x=(-.5 if i==0 else .5)
		d.locked=not str(d.get("requirement","")).is_empty()
	progression.reset()
	build_navigation()
	checkpoint = layout.NIGHT
	player.reset()
	player.position = layout.NIGHT
	player.rotation = Vector3.ZERO
	player.pitch = 0
	player.rotation.y = PI/2
	player.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.lamp.visible = true
	player.camera.current = true
	enemy.position = Vector3(6.8,1.5,17.8)
	enemy.rotation = Vector3.ZERO
	enemy.pursuing = false
	enemy.detection = 0
	enemy.velocity = Vector3.ZERO
	enemy.visible = false
	previous_enemy = enemy.position
	ai_state = "roam"
	state_time = 0
	lost_sight=0
	visual_notice=0
	repath = 0
	stuck_time = 0
	path.clear()
	grace = 8
	breath.stop()
	breath.stream_paused = false
	player.pant.stream_paused = false
	ambient.volume_db = -12
	hum.volume_db = -24
	scare_head.visible = false
	film.material.set_shader_parameter("trauma",0)
	hud.visible = true
	prompt.visible = true
	message.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mode = "playing"
	create_tween().tween_property(curtain,"modulate:a",0.0,.7)
	save_checkpoint("start")

func make_physical_key(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	world.add_child(root)
	var torus := TorusMesh.new()
	torus.inner_radius = .055
	torus.outer_radius = .10
	torus.rings=32;torus.ring_segments=8
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = materials.gold
	ring.rotation.x = PI/2
	root.add_child(ring)
	box(Vector3(.15,0,0),Vector3(.25,.045,.045),"gold",false,root)
	box(Vector3(.25,-.05,0),Vector3(.045,.10,.045),"gold",false,root)
	return root

func spawn_key(pos: Vector3) -> void:
	keys.append(make_physical_key(pos))

func toast(value: String, seconds := 3.0) -> void:
	message.text = value
	message_time = seconds

func target_visible(point: Vector3,reach: float,dot: float) -> bool:
	var eye: Vector3 = player.camera.global_position
	var diff := point-eye
	if diff.length()>reach or (-player.camera.global_basis.z).dot(diff.normalized())<dot: return false
	var q := PhysicsRayQueryParameters3D.create(eye,point,1|4)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.position.distance_to(point)<.12

func interactable(fresh:=false) -> Dictionary:
	if mode!="playing": return {}
	var frame:=Engine.get_process_frames()
	if interaction_cache_enabled and not fresh and aimed_frame==frame: return aimed_cache
	var candidates: Array[Dictionary]=progression.story_puzzles.available_targets()
	for key in keys:
		if is_instance_valid(key) and key.visible and not key.get_meta("collected",false): candidates.append({"type":"key","node":key,"point":key.global_position})
	candidates.append({"type":"exit","point":layout.EXIT_TARGET})
	for d in doors:
		if d.busy: continue
		var local_x: float=float(d.get("slide_direction",1))*1.55 if d.open else 0.0
		var centre: Vector3=d.node.to_global(Vector3(local_x,1.3,float(d.track_side)*.27))
		centre+=d.node.global_basis.z*.08*signf((player.global_position-centre).dot(d.node.global_basis.z))
		candidates.append({"type":"door","door":d,"point":centre})
	var best: Dictionary={}
	var alignment:=.89
	for item in candidates:
		if not target_visible(item.point,2.5 if item.type=="evidence" else (1.85 if item.type=="door" else 1.65),.90 if item.type=="evidence" else .96): continue
		var diff: Vector3=item.point-player.camera.global_position
		var score: float=(-player.camera.global_basis.z).dot(diff.normalized())
		if score>alignment:
			alignment=score
			best=item
	aimed_frame=frame
	aimed_cache=best
	return best

func interact() -> void:
	if mode!="playing": return
	var it := interactable(true)
	if it.is_empty(): return
	match it.type:
		"door": toggle_door(it.door)
		"exit": progression.story_puzzles.try_exit()
		_: progression.interact(it)

func toggle_door(d: Dictionary, force_open := false) -> void:
	if not progression.story_puzzles.can_open(d):
		if not force_open and clock>=float(d.get("feedback_until",-1)):
			d.feedback_until=clock+.5
			toast("Latched.",2)
			world_sound("locked",d.origin+Vector3(0,1.0,0),-19)
		return
	d.locked=false
	if d.busy or (force_open and d.open): return
	if d.open and not force_open:
		var local: Vector3=d.node.to_local(player.global_position)
		if absf(local.z)<.75 and absf(local.x)<2.15: return
		if Vector2(enemy.position.x-d.origin.x,enemy.position.z-d.origin.z).length()<1.9: return
	d.busy = true
	d.open = true if force_open else not d.open
	if d.has("tween") and d.tween: d.tween.kill()
	d.tween = create_tween()
	if is_instance_valid(d.get("motion_audio")): d.motion_audio.stop(); d.motion_audio.queue_free()
	world_sound("latch",d.origin+Vector3(0,1.0,0),-17)
	d.motion_audio=world_sound("door_track",d.origin+Vector3(0,1.2,0),-17 if force_open else -12,1.2)
	for i in range(2):
		var closed_x: float=-.5 if i==0 else .5
		d.tween.parallel().tween_property(d.panels[i],"position:x",float(d.slide_direction)*1.55 if d.open else closed_x,1.2 if force_open else .65)

	d.tween.chain().tween_callback(func():
		d.busy = false
		if not d.open: world_sound("close",d.origin+Vector3(0,1.2,0),-16))

func stop_movement_audio() -> void:
	for weak in moving_sounds:
		var audio: AudioStreamPlayer3D=weak.get_ref()
		if audio: audio.stop(); audio.queue_free()
	moving_sounds.clear()

func clear_line(a: Vector3,b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a,b,1|4)
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func flashlight_exposure() -> bool:
	# Illumination only. No hidden location beacon or unreliable light-attraction rule.
	return false

func sees_player() -> bool:
	var diff: Vector3 = player.position+Vector3(0,1.3,0)-enemy.position
	var distance := diff.length()
	if distance>Tuning.FLASHLIGHT_RANGE: return false
	var flat := Vector3(diff.x,0,diff.z).normalized()
	var normal_sight := distance<Tuning.DETECTION_RANGE and (distance<3 or (-enemy.global_basis.z).dot(flat)>.38)
	return normal_sight and clear_line(enemy.position,player.position+Vector3(0,1.3,0))

func _input(event: InputEvent) -> void:
	if is_instance_valid(studio_intro):
		studio_intro.consume(event)
		return
	# Escape closes a modal even when a number wheel's LineEdit owns focus.
	if event.is_action_pressed("pause") and mode in ["document","puzzle"]:
		if mode=="document": progression.evidence.close()
		else: resume_game()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if mode=="playing": show_pause()
		elif mode=="paused": resume_game()

func show_pause() -> void:
	progression.story_puzzles.stop_crank()
	mode = "paused"
	var v := panel_stack("PAUSED","WASD move  ·  Shift run  ·  E interact  ·  F light  ·  J journal")
	button("RESUME",resume_game,v).grab_focus()
	button("OPTIONS",func(): options_return="pause"; show_options(),v)
	button("MAIN MENU",show_main_menu,v)
	breath.stream_paused = true
	player.pant.stream_paused = true

func resume_game() -> void:
	mode = "playing"
	prompt.text = ""
	menu.visible = false
	hud.visible = true
	prompt.visible = true
	message.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	breath.stream_paused = false
	player.pant.stream_paused = false

func victory() -> void:
	if player_voice: player_voice.flush()
	if ending_started or mode!="playing" or collected!=1: return
	ending_started = true
	mode = "ending"
	breath.stop()
	player.pant.stop()
	progression.voice.stop()
	progression.cry.stop()
	progression.story_puzzles.recording.stop()
	ambient.volume_db = -70
	hum.volume_db = -70
	music.volume_db = -70
	clear_menu()
	menu.hide()
	hud.hide()
	prompt.hide()
	message.hide()
	film.hide()
	curtain.modulate.a = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ending = preload("res://ending.tscn").instantiate()
	ending.game = self
	gui.add_child(ending)

func capture() -> void:
	progression.story_puzzles.stop_crank()
	if hum: hum.stop()
	if mode!="playing": return
	player.cancel_movement()
	stop_movement_audio()
	player.pant.stop()
	progression.giggle.stop()
	mode = "capture"
	player_voice.flush()
	capture_time = 0
	pain_triggered = false
	capture_scream_started=false
	capture_blink_started=false
	var env: Environment = world.get_child(0).environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.fog_enabled = false
	scare_camera.position = Vector3(0,-40,0)
	player.velocity = Vector3.ZERO
	menu.visible = false
	hud.visible = false
	prompt.visible = false
	message.visible = false
	enemy.visible = false
	breath.stop()
	ambient.volume_db = -40
	hum.volume_db = -40
	scare_head.visible = true
	scare_head.scare = 0
	scare_head.capture_pose=true
	scare_head.capture_jaw=0
	scare_head.capture_age=0
	scare_head.blink_time=-1
	scare_head.face_material.set_shader_parameter("blink",0)
	scare_camera.current = true
	scare_camera.rotation = Vector3.ZERO
	scare_head.position = Vector3(0,-40,-3.5)
	sound("capture",-15)
	progression.cry.stop()
	progression.voice.stop()
	capture_ghost.stream=load("res://assets/audio/sakiko_capture_breath.wav")
	capture_ghost.pitch_scale=1.0
	capture_ghost.volume_db=-15
	capture_ghost.stop()
	film.material.set_shader_parameter("trauma",0)

func death_screen() -> void:
	mode = "dead"
	scare_head.visible = false
	var v := panel_stack("YOU DIED","She swallowed the last sound. Your checkpoint remains.")
	menu.get_child(0).color = Color(.13,.008,.014,.97)
	v.get_child(0).add_theme_color_override("font_color",Color("b52b34"))
	button("RETURN TO CHECKPOINT",return_to_checkpoint,v).grab_focus()
	button("RESTART RUN",start_game,v)
	button("MAIN MENU",show_main_menu,v)
	curtain.modulate.a = 0
	film.material.set_shader_parameter("trauma",0)

func _physics_process(delta: float) -> void:
	if mode!="playing": return
	watch_doors()
	if exit_open and player.position.x< -.75 and player.position.y<1 and absf(player.position.z-12)<1.0:
		victory()
		return
	if not progression.hunt_enabled: return
	if progression.encounters_controller.retreating:
		if sees_player():
			progression.encounters_controller.retreating=false
			path.clear()
		else: return
	grace -= delta
	state_time += delta
	repath -= delta
	enemy.pursuing = ai_state=="chase"
	var visible_now := grace<=0 and sees_player()
	var notice_duration:=.15 if enemy.position.distance_to(player.camera.global_position)<3 else 1.0
	visual_notice=clampf(visual_notice+(delta/notice_duration if visible_now else -delta*2),0,1)
	var sees := visible_now and (ai_state=="chase" or visual_notice>=1)
	if sees: lost_sight=0
	elif ai_state in ["chase","investigate","search"]: lost_sight+=delta
	if lost_sight>=9:
		lost_sight=0
		progression.encounters_controller.disengage()
		return
	if sees:
		last_seen = player.position+Vector3(0,1.5,0)
		if ai_state!="chase":
			ai_state = "chase"
			progression.story_puzzles.flags.detected_once=true
			progression.spotted()
		state_time = 0
	elif ai_state=="chase" and state_time>1.1:
		ai_state = "investigate"
		state_time = 0
		navigate(last_seen)
	if ai_state in ["presence","middle_approach"] and path.is_empty():
		ai_state="roam"
		progression.encounters_controller.pressure_cooldown=12
	if ai_state in ["chase","approach"] and repath<=0:
		navigate(last_seen)
		repath = .45
	if ai_state in ["roam","withdraw"] and (path.is_empty() or state_time>22):
		ai_state="roam"
		# The director rests; she remains physical and can still see/hear nearby players.
		if progression.encounters_controller.pressure_cooldown>0: return
		var points: Array=layout.PATROL
		navigate(points[randi()%points.size()])
		state_time = 0
	if ai_state in ["investigate","approach"] and (path.is_empty() or state_time>8):
		ai_state = "search"
		state_time = 0
	if ai_state=="search":
		enemy.rotate_y(delta*.6)
		if state_time>7:
			progression.encounters_controller.disengage()
	else:
		if not path.is_empty():
			waypoint = path[0]
			var offset: Vector3 = waypoint-enemy.position
			if offset.length()<.25: path.remove_at(0)
			else:
				var direction := offset.normalized()
				var speed := Tuning.CHASE_SPEED if ai_state=="chase" else 1.45
				if ai_state=="investigate": speed = 2.2
				if ai_state=="approach" or progression.encounters_controller.approach_time>0: speed = 1.45
				enemy.velocity = enemy.velocity.move_toward(direction*speed,delta*12)
				var yaw := atan2(-direction.x,-direction.z)
				enemy.rotation.y = lerp_angle(enemy.rotation.y,yaw,delta*5)
				var waiting:=false
				for d in doors:
					if absf(enemy.position.y-d.origin.y-1.5)<1.0 and Vector2(enemy.position.x-d.origin.x,enemy.position.z-d.origin.z).length()<2.0 and (d.busy or not d.open) and absf(d.node.to_local(waypoint).x)<1.0 and d.node.to_local(enemy.position).z*d.node.to_local(waypoint).z<=.03:
						waiting=true
						if not d.busy: toggle_door(d,true)
				if not waiting: enemy.move_and_slide()
	if enemy.position.distance_to(previous_enemy)<delta*.12 and not path.is_empty(): stuck_time += delta
	else: stuck_time = 0
	previous_enemy = enemy.position
	if stuck_time>2:
		# Recover by replanning; never move through a real closed door.
		navigate(target)
		stuck_time = 0
	if grace<=0 and enemy.position.distance_to(player.position+Vector3(0,1.4,0))<1.25 and clear_line(enemy.position,player.position+Vector3(0,1.4,0)): capture()

func _process(delta: float) -> void:
	clock += delta
	if mode=="menu": update_menu_indicator()
	if music:
		music.volume_db = lerpf(music.volume_db,-18.0 if mode=="menu" else -65.0,minf(1,delta*1.8))
		var story_quiet: bool = mode in ["ending","credits","capture"] or (mode=="intro" and progression.intro_time<129)
		ambient.volume_db = -80 if story_quiet else lerpf(ambient.volume_db,0.0 if mode=="playing" else -22.0,minf(1,delta*2))
		hum.volume_db = -80 # Building ambience carries the quiet sections.
	var dialogue_active: bool=progression and (progression.story_puzzles.recording.playing or (mode=="intro" and expansion.time<125))
	if dialogue_active:
		ambient.volume_db-=minf(4,delta*12)
		music.volume_db-=minf(4,delta*12)
	if mode=="playing" and progression.cry.playing:
		ambient.volume_db=minf(ambient.volume_db,-8.0)
	if mode=="playing" and ai_state=="chase" and enemy.visible:
		pass # Detection cry already supplies the discrete creature vocal.
	else: breath.stop()
	if film: film.material.set_shader_parameter("reduced",settings.reduced)
	if mode=="menu":
		menu_camera.position.z = 10+sin(clock*.09)*.12
		menu_camera.rotation.z = sin(clock*.12)*.003
	if not lights.is_empty():
		if mode!="intro": lights[2].light_energy = float(lights[2].get_meta("night_energy",.055))*(1.0 if sin(clock*1.7)>-.95 else .16)
	if mode=="playing":
		hud.text = progression.objective()
		if hud.text!=objective_text:
			objective_text=hud.text
			objective_age=0
		objective_age+=delta
		hud.modulate.a=lerpf(1.0,.40,smoothstep(7,10,objective_age))
		if progression.encounters_controller.reveal_time>=0 and not progression.encounters_controller.reveal_finished: hud.modulate.a=0
		var it := interactable()
		prompt.text = ""
		if not it.is_empty():
			match it.type:
				"key","utility","service_key","fragment": prompt.text = "E — Take"
				"door": prompt.text = "E — Close" if it.door.open else "E — Open"
				"exit": prompt.text = "E  -  Escape" if exit_open else "E  -  Try entrance"
				"evidence","portrait": prompt.text = "E — Inspect"
				"container": prompt.text = "E — Open"
				_: prompt.text = str(it.get("label","E — Interact"))
		message_time -= delta
		message.modulate.a = clampf(message_time,0,1)
	if mode=="capture":
		capture_time+=delta
		var t:=capture_time
		scare_head.capture_age=t
		if t>=.3 and t<.3+delta: capture_ghost.play()
		if t>=.48 and not capture_blink_started:
			capture_blink_started=true
			scare_head.blink(.32)
		if t>=1.2 and not capture_scream_started:
			capture_scream_started=true
			capture_ghost.stop()
			capture_ghost.stream=sounds.capture_shriek
			capture_ghost.pitch_scale=1.0
			capture_ghost.volume_db=-2
			capture_ghost.play()
		var lunge:=smoothstep(1.2,2.4,t)
		scare_head.position.z=lerpf(-3.5,-2.08,lunge)
		scare_head.capture_jaw=.32*smoothstep(1.2,2.4,t)
		scare_head.scare=smoothstep(1.2,2.0,t)
		scare_head.rotation.z=lerpf(0,-.055,smoothstep(.3,1.2,t))
		var swallow:=smoothstep(2.4,3.08,t)
		scare_camera.position=Vector3(0,lerpf(-40,-41.0,swallow),lerpf(0,-.52,swallow))
		scare_camera.fov=lerpf(72,82,swallow)
		scare_camera.look_at(Vector3(0,lerpf(-40.05,-41.0,smoothstep(1.2,2.9,t)),-2.6))
		if settings.shake and not settings.reduced:
			var jolt:=maxf(0,1-absf(t-2.52)/.11)
			scare_camera.rotation.z=jolt*.035
		curtain.modulate.a=smoothstep(2.92,3.12,t)
		if t>3.2: capture_ghost.volume_db=lerpf(-2,-60,smoothstep(3.2,3.85,t))
		if t>=3.9:
			capture_ghost.stop()
			death_screen()

const SAFE_CHECKPOINTS: Dictionary={"start":Vector3(15.46,0,2.7),"CP1":Vector3(29,0,6.3),"CP2":Vector3(10,4.2,25),"CP3":Vector3(46,4.2,25),"CP4":Vector3(44,0,5.5),"CP5":Vector3(27,0,5.5),"CP6":Vector3(45,4.2,32),"MIDDLE_SHUTTER":Vector3(13.0,4.2,9.5),"MIDDLE_FAR":Vector3(46,4.2,10)}

func load_saved_checkpoint() -> void:
	if not checkpoint_state.is_empty(): return
	var path: String="user://checkpoint-flow-v5.save"
	if not FileAccess.file_exists(path): path="user://checkpoint-flow-v4.save"
	if not FileAccess.file_exists(path): return
	var saved:=FileAccess.open(path,FileAccess.READ)
	if not saved: return
	var data: Variant=saved.get_var(false)
	saved.close()
	if data is Dictionary and data.get("version",0)==4:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path("user://checkpoint.pre-middle-v4-%d.save" % int(Time.get_unix_time_from_system())))
		data=migrate_middle_save(data)
	if not data is Dictionary or data.get("version",0)!=5: return
	if not SAFE_CHECKPOINTS.has(data.get("id","")) or not data.get("flow") is Dictionary: return
	if not data.get("doors") is Array or data.doors.size()!=doors.size(): return
	if not data.get("encounters") is Dictionary or not data.get("locks") is Array: return
	checkpoint_state=data
	if path.ends_with("v4.save"): persist_voice_flags()

func migrate_middle_save(old: Dictionary) -> Dictionary:
	var data: Dictionary=old.duplicate(true)
	var flags: Dictionary=data.flow.flags
	var has_key: bool=flags.get("key",false)
	var tape_done: bool=flags.get("tape_done",false)
	flags.middle_section_active=tape_done
	flags.shutter_progress=1.0 if has_key else 0.0
	flags.shutter_open=has_key
	flags.east_landing_unbolted=has_key
	flags.south_shortcut_released=has_key
	if has_key:
		data.flow.stage=8
		data.id="CP6"
		data.position=SAFE_CHECKPOINTS.CP6
	elif flags.get("escape_done",false):
		data.flow.stage=6
		data.id="CP5"
		data.position=SAFE_CHECKPOINTS.CP5
	if data.doors.size()==doors.size()-1: data.doors.append({"open":false})
	data.version=5
	return data

func backup_legacy_save() -> void:
	if not FileAccess.file_exists("user://checkpoint.save"): return
	var backup_path: String=ProjectSettings.globalize_path("user://checkpoint.pre-flow-%d.save" % int(Time.get_unix_time_from_system()))
	DirAccess.copy_absolute(ProjectSettings.globalize_path("user://checkpoint.save"),backup_path)
	# Keep the original as well. New runs use a separate versioned filename.

func save_checkpoint(id: String) -> void:
	checkpoint_id=id
	checkpoint=SAFE_CHECKPOINTS.get(id,layout.NIGHT)
	var door_states: Array=[]
	for d in doors: door_states.append({"open":d.open})
	checkpoint_state={"version":5,"id":id,"position":checkpoint,"flow":progression.story_puzzles.snapshot(),"doors":door_states,"locks":hardware.released.duplicate(),"exit_open":exit_open,"encounters":progression.encounters_controller.snapshot(),"voice":player_voice.snapshot()}
	var saved:=FileAccess.open("user://checkpoint-flow-v5.save",FileAccess.WRITE)
	if saved: saved.store_var(checkpoint_state); saved.close()

func return_to_checkpoint() -> void:
	progression.story_puzzles.stop_crank()
	if checkpoint_state.is_empty() or checkpoint_state.get("version",0)!=5: return
	var data: Dictionary=checkpoint_state.duplicate(true)
	stop_movement_audio()
	capture_ghost.stop()
	for d in doors:
		if d.has("tween") and d.tween: d.tween.kill()
		d.busy=false
	progression.story_puzzles.restore(data.flow)
	for i in range(doors.size()):
		var d: Dictionary=doors[i]
		if d.has("tween") and d.tween: d.tween.kill()
		d.busy=false
		d.open=data.doors[i].open
		for n in range(2): d.panels[n].position.x=d.slide_direction*1.55 if d.open else (-.5 if n==0 else .5)
	hardware.reset()
	hardware.released.assign(data.locks)
	hardware.locks[0].lock.visible=not hardware.released[0]
	exit_open=data.exit_open
	for i in range(exit_panels.size()): exit_panels[i].position=progression.exit_origins[i]+Vector3(0,0,(-1.3 if i==0 else 1.3) if exit_open else 0)
	progression.encounters_controller.restore(data.encounters)
	player_voice.restore(data.get("voice",{}))
	checkpoint=data.position
	checkpoint_id=data.id
	player.reset()
	player.position=checkpoint
	player.rotation=Vector3.ZERO
	player.pitch=0
	player.camera.rotation=Vector3.ZERO
	player.camera.current=true
	player.lamp.show()
	player.velocity=Vector3.ZERO
	enemy.position=Vector3(51.4,1.5,17.8) if checkpoint_id=="CP4" else Vector3(13,1.5,7)
	if progression.story_puzzles.stage>=7: enemy.position=Vector3(10,5.7,19)
	enemy.velocity=Vector3.ZERO
	enemy.visible=progression.story_puzzles.flags.get("escape_done",false)
	enemy.pursuing=false
	enemy.detection=0
	scare_head.hide()
	scare_head.capture_pose=false
	path.clear()
	ai_state="roam"
	state_time=0
	lost_sight=0
	visual_notice=0
	stuck_time=0
	grace=0
	repath=0
	progression.scream_cooldown=0
	progression.cry.stop()
	progression.giggle.stop()
	progression.voice.stop()
	breath.stop()
	curtain.modulate.a=0
	film.material.set_shader_parameter("trauma",0)
	expansion.set_day(false)
	build_navigation()
	resume_game()

func watch_doors() -> void:
	for d in doors:
		if not d.busy or d.open: continue
		var local: Vector3=d.node.to_local(player.global_position)
		if absf(local.z-float(d.track_side)*.27)<.6 and absf(local.x)<1.65:
			d.tween.kill()
			d.busy=false
			d.open=false
			toggle_door(d,true)

func verify_game() -> void:
	var suite = load("res://tests/flow_check.gd").new()
	await suite.run(self)

func bugfix_check() -> void:
	await load("res://tests/bugfix_audio_lighting.gd").new().run(self)

func profile_route() -> void:
	await load("res://tests/performance_route.gd").new().run(self)

func warm_capture_assets() -> void:
	# Upload/compile the existing head during startup, away from the first scare.
	if DisplayServer.get_name()=="headless": return
	var view:=SubViewport.new();view.size=Vector2i(64,64)
	view.world_3d=get_world_3d();view.msaa_3d=get_viewport().msaa_3d
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(view)
	var camera:=Camera3D.new();view.add_child(camera)
	camera.position=Vector3(0,-40,0);camera.look_at(Vector3(0,-40,-2.5));camera.current=true
	scare_head.show()
	for frame in range(3): await RenderingServer.frame_post_draw
	scare_head.hide();view.queue_free()

func placement_audit() -> void:
	await load("res://tests/placement_audit.gd").new().run(self)

func nonverbal_check() -> void:
	await load("res://tests/nonverbal_pass.gd").new().run(self)

func master_ui_check() -> void:
	await load("res://tests/master_ui.gd").new().run(self)

func bugfix_menu_render() -> void:
	show_main_menu()
	await get_tree().create_timer(.2).timeout
	for item in nav_buttons.duplicate():
		item.mouse_entered.emit()
		await get_tree().create_timer(.08).timeout
		await snapshot("bugfix_menu_"+item.text.to_lower())
	get_window().size=Vector2i(1024,576)
	await get_tree().create_timer(.2).timeout
	nav_buttons[1].grab_focus()
	await get_tree().create_timer(.1).timeout
	await snapshot("bugfix_menu_resized")
	quit_game()

func bugfix_lighting_render() -> void:
	start_game()
	player_voice.flush();player_voice.wake_delay=-1
	mode="inspection"
	hud.hide();prompt.hide();message.hide();film.hide()
	expansion.set_day(true)
	await audit_view(Vector3(14.8,0,5.5),Vector3(10.5,1.5,4))
	player.lamp.hide()
	await snapshot("bugfix_classroom_day")
	expansion.set_day(false)
	for shot in [["G01",Vector3(14.8,0,5.5),Vector3(10.5,1.5,4)],["corridor",Vector3(28,0,10),Vector3(38,1.5,10)],["archive",Vector3(14,4.2,32.5),Vector3(14.3,5.1,35.3)],["rehearsal",Vector3(44,4.2,31.2),Vector3(45.5,5.1,34.4)],["stairs",Vector3(4.6,.5,19.6),Vector3(4.6,1.8,22.6)]]:
		await audit_view(shot[1],shot[2])
		for on in [false,true]:
			player.lamp.visible=on
			await get_tree().create_timer(.15).timeout
			await snapshot("bugfix_"+shot[0]+("_on" if on else "_off"))
	quit_game()

func snapshot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/artifacts/%s.png" % filename)
	print("RENDER ",filename)

func presentation_audit() -> void:
	await polish_render_audit()

func render_audit() -> void:
	await polish_render_audit()

func quit_game(exit_code:=0) -> void:
	if mode=="quitting": return
	mode = "quitting"
	for p in find_children("*","AudioStreamPlayer",true,false):
		p.stop()
		p.stream = null
	for p in find_children("*","AudioStreamPlayer3D",true,false):
		p.stop()
		p.stream = null
	sounds.clear()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(exit_code)

func interaction_audit() -> void:
	start_game()
	await audit_view(Vector3(26.2,0,7.3),Vector3(26.2,.68,6.025))
	await snapshot("interaction_aimed")
	player.camera.rotate_y(.7)
	await get_tree().process_frame
	await snapshot("interaction_look_away")
	await audit_view(Vector3(26.2,0,10),Vector3(26.2,.68,6.025))
	await snapshot("interaction_far")
	quit_game()

func audit_view(from: Vector3,to: Vector3) -> void:
	player.position=from
	player.velocity=Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.look_at(Vector3(to.x,player.global_position.y,to.z))
	player.camera.rotation=Vector3(atan2(to.y-player.camera.global_position.y,Vector2(to.x-player.global_position.x,to.z-player.global_position.z).length()),0,0)
	await get_tree().create_timer(.15).timeout

func polish_render_audit() -> void:
	await get_tree().create_timer(.5).timeout
	start_game()
	grace=999
	var env: Environment=world.get_child(0).environment
	mode="inspection"
	hud.hide()
	prompt.hide()
	message.hide()
	film.hide()
	for light in layout.inspection_lights: light.show()
	env.ambient_light_energy=.6
	env.fog_enabled=false
	if "--detail-render" in OS.get_cmdline_user_args():
		await audit_view(Vector3(45.7,4.2,32.8),Vector3(45.6,4.8,34.4))
		await snapshot("revamp_rehearsal_neutral")
		quit_game()
		return
	var ceiling_nodes: Array[Node]=get_tree().get_nodes_in_group("audit_ceilings")
	for node in ceiling_nodes: node.hide()
	var upper: Array[Node3D]=[]
	for node in layout.get_children():
		if node is Node3D and node.position.y>4.0 and node.visible: upper.append(node); node.hide()
	for node in world.get_children():
		if node is Node3D and node!=layout and node.position.y>4.0 and node.visible: upper.append(node); node.hide()
	for core_name in ["WestStairs_Green","EastStairs_Blue"]:
		for node in layout.get_node(core_name).get_children():
			if node is MeshInstance3D and node.position.y>3.9 and node.visible: upper.append(node); node.hide()
	menu_camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	menu_camera.size=42
	menu_camera.position=Vector3(28,45,18)
	menu_camera.look_at(Vector3(28,0,18),Vector3(0,0,-1))
	menu_camera.current=true
	# Parent room lights disappear in the cutaway; use dedicated audit lighting.
	var audit_sun:=DirectionalLight3D.new()
	audit_sun.rotation_degrees=Vector3(-70,-25,0)
	audit_sun.light_energy=1.1
	add_child(audit_sun)
	env.ambient_light_energy=1.1
	await get_tree().create_timer(.2).timeout
	await snapshot("revamp_ground_overview_neutral")
	for node in upper: node.show()
	await get_tree().create_timer(.2).timeout
	await snapshot("revamp_upper_overview_neutral")
	audit_sun.queue_free()
	env.ambient_light_energy=.6
	for node in ceiling_nodes: node.show()
	menu_camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	player.camera.current=true
	for shot in [["lobby",Vector3(6.4,0,12.8),Vector3(0,1.6,12)], ["west_stairs",Vector3(6.8,0,17.8),Vector3(4.6,1.8,21)], ["east_stairs_upper",Vector3(49.2,4.2,17.8),Vector3(54.2,5,20.8)], ["archive",Vector3(14.3,4.2,33.8),Vector3(14.3,5.15,34.9)], ["rehearsal",Vector3(45.7,4.2,32.8),Vector3(45.6,4.8,34.4)]]:
		await audit_view(shot[1],shot[2])
		await snapshot("revamp_"+shot[0]+"_neutral")
	for light in layout.inspection_lights: light.hide()
	film.show()
	expansion.set_day(false)
	mode="playing"
	resume_game()
	await audit_view(Vector3(29,0,10.6),Vector3(29,2.95,8.10))
	player.lamp.hide()
	await snapshot("revamp_sign_dark")
	player.lamp.show()
	await snapshot("revamp_sign_flashlight")
	await audit_view(Vector3(28,0,10.3),Vector3(28,1.8,12))
	await snapshot("revamp_courtyard_window")
	player.camera.rotation.x=.5
	await snapshot("revamp_window_look_up")
	player.camera.rotation.x=-.5
	await snapshot("revamp_window_look_down")
	await audit_view(Vector3(12,0,2),Vector3(12,1.8,0))
	await snapshot("revamp_exterior_window")
	play_intro()
	await get_tree().create_timer(.5).timeout
	await snapshot("revamp_intro_rear_seat")
	progression.finish_intro()
	await get_tree().create_timer(.2).timeout
	await snapshot("revamp_night_hud")
	await audit_view(Vector3(26.2,0,7.3),Vector3(26.2,.68,6.025))
	await snapshot("revamp_staff_prompt")
	progression.evidence.inspect("sketch")
	await get_tree().create_timer(.25).timeout
	await snapshot("revamp_document_front")
	progression.evidence.reverse=true
	progression.evidence.update_preview()
	await get_tree().create_timer(.2).timeout
	await snapshot("revamp_document_back")
	progression.evidence.close()
	quit_game()

func verify_layout_shell() -> void:
	var suite=load("res://tests/layout_shell.gd").new()
	await suite.run(self)

func bake_courtyard() -> void:
	mode="bake"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/windows"))
	for pane in get_tree().get_nodes_in_group("exterior_panes"): pane.hide()
	enemy.hide()
	scare_head.hide()
	var view:=SubViewport.new()
	view.size=Vector2i(1536,768)
	view.world_3d=get_world_3d()
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(view)
	var camera:=Camera3D.new()
	camera.fov=72
	view.add_child(camera)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-55,-25,0)
	sun.light_color=Color("eee7d2")
	sun.shadow_enabled=true
	add_child(sun)
	var env: Environment=world.get_child(0).environment
	for level in range(2):
		for side in ["north","south","west","east"]:
			var y: float=level*4.2+1.75
			var point: Vector3={"north":Vector3(28,y,12.25),"south":Vector3(28,y,23.75),"west":Vector3(12.25,y,18),"east":Vector3(43.75,y,18)}[side]
			camera.position=point
			camera.look_at(Vector3(28,3.5,18))
			var atlas:=Image.create(1536,1536,false,Image.FORMAT_RGBA8)
			for day in [true,false]:
				expansion.set_day(day)
				sun.light_energy=1.2 if day else .08
				env.ambient_light_energy=.65 if day else .13
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var capture_image: Image=view.get_texture().get_image()
				capture_image.convert(Image.FORMAT_RGBA8)
				atlas.blit_rect(capture_image,Rect2i(0,0,1536,768),Vector2i(0,0 if day else 768))
			atlas.save_png("res://assets/windows/courtyard_%s_%d.png" % [side,level])
			print("BAKED courtyard ",side," ",level)
	quit_game()

func corrections_render() -> void:
	await get_tree().create_timer(.4).timeout
	start_game()
	player_voice.flush()
	player_voice.wake_delay=-1
	mode="inspection"
	hud.hide()
	prompt.hide()
	message.hide()
	film.hide()
	var env: Environment=world.get_child(0).environment
	for light in layout.inspection_lights: light.show()
	env.fog_enabled=false
	env.ambient_light_energy=.75
	var audit_sun:=DirectionalLight3D.new()
	audit_sun.rotation_degrees=Vector3(-65,-25,0)
	audit_sun.light_energy=.9
	add_child(audit_sun)
	var ceilings: Array[Node]=get_tree().get_nodes_in_group("audit_ceilings")
	for node in ceilings: node.hide()
	var upper: Array[Node3D]=[]
	for node in layout.get_children():
		if node is Node3D and node.position.y>4.0 and node.visible: upper.append(node); node.hide()
	for node in world.get_children():
		if node is Node3D and node!=layout and node.position.y>4.0 and node.visible: upper.append(node); node.hide()
	for core_name in ["WestStairs_Green","EastStairs_Blue"]:
		for node in layout.get_node(core_name).get_children():
			if node is MeshInstance3D and node.position.y>3.9 and node.visible: upper.append(node); node.hide()
	menu_camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	menu_camera.size=42
	menu_camera.position=Vector3(28,45,18)
	menu_camera.look_at(Vector3(28,0,18),Vector3(0,0,-1))
	menu_camera.current=true
	await get_tree().create_timer(.2).timeout
	await snapshot("correction_ground_overview")
	for node in upper: node.show()
	await get_tree().create_timer(.2).timeout
	await snapshot("correction_upper_overview")
	for node in ceilings: node.show()
	menu_camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	player.camera.current=true
	for shot in [["staff_cabinet",Vector3(29.5,0,3.4),Vector3(31.7,1.6,2)],["upper_sign",Vector3(6.8,4.2,19),Vector3(7.86,6.65,22)],["science_entrance",Vector3(25.5,4.2,10.7),Vector3(25.5,5.7,8)],["library_front",Vector3(36,0,11),Vector3(36,1.7,7.4)],["art_widening",Vector3(29.7,0,25.7),Vector3(29.7,1.7,30)],["entrance_hardware_locked",Vector3(1.0,0,12),Vector3(.13,1.25,12)],["west_landing",Vector3(3.5,0,23),Vector3(0,1.8,20)],["east_landing",Vector3(50,4.2,18),Vector3(55.9,5.9,20)]]:
		await audit_view(shot[1],shot[2])
		await snapshot("correction_"+shot[0])
	var p: Node=progression.story_puzzles
	for id in ["upper","festival","archive","media","rehearsal_U08"]: p.utility_inventory[id]=true
	for d in doors:
		d.locked=false
		toggle_door(d,true)
	await get_tree().create_timer(.9).timeout
	for shot in [["archive_vestibule",Vector3(10,4.2,27),Vector3(13.3,5.2,29.4)],["classroom",Vector3(14.9,0,6.6),Vector3(9,1.3,4)],["rehearsal",Vector3(45.7,4.2,32.8),Vector3(45.6,4.8,34.4)]]:
		await audit_view(shot[1],shot[2])
		await snapshot("correction_"+shot[0])
	var door: Dictionary=layout.room_doors.G04[0]
	await audit_view(Vector3(33.5,0,10.3),Vector3(34.3,1.4,7.6))
	await snapshot("correction_door_parked")
	toggle_door(door)
	await get_tree().create_timer(.30).timeout
	await snapshot("correction_door_midcycle")
	await get_tree().create_timer(.5).timeout
	await snapshot("correction_door_closed")
	for i in range(4): hardware.release(i); await get_tree().create_timer(.6).timeout
	await audit_view(Vector3(1.0,0,12),Vector3(.13,1.25,12))
	await snapshot("correction_entrance_hardware_released")
	audit_sun.queue_free()
	for light in layout.inspection_lights: light.hide()
	for day in [true,false]:
		expansion.set_day(day)
		for level in range(2):
			await audit_view(Vector3(12,level*4.2,1.3),Vector3(12,level*4.2+1.8,-5))
			await snapshot("correction_window_"+("day" if day else "night")+str(level))
			player.camera.rotation.x=.95
			await snapshot("correction_window_up_"+str(day)+str(level))
			player.camera.rotation.x=-.95
			await snapshot("correction_window_down_"+str(day)+str(level))
			await audit_view(Vector3(13.5,level*4.2,1.3),Vector3(12,level*4.2+1.8,-5))
			await snapshot("correction_window_side_"+str(day)+str(level))
		await audit_view(Vector3(28,0,10.4),Vector3(28,1.8,18))
		await snapshot("correction_courtyard_"+str(day))
	expansion.set_day(false)
	film.show()
	play_intro()
	await get_tree().create_timer(3).timeout
	await snapshot("correction_intro")
	print("PLACEMENT accepted=",layout.placement.accepted.size()," rejected=",layout.placement.rejected)
	quit_game()

func scenery_render() -> void:
	await get_tree().create_timer(.4).timeout
	start_game()
	player_voice.flush()
	player_voice.wake_delay=-1
	mode="inspection"
	hud.hide();prompt.hide();message.hide();film.hide()
	if "--creature-render" in OS.get_cmdline_user_args():
		expansion.set_day(true)
		enemy.position=Vector3(28,1.5,-90)
		enemy.rotation=Vector3.ZERO
		enemy.show()
		for shot in [["front",Vector3(28,0,-94)],["quarter",Vector3(31,0,-93)],["side",Vector3(32,0,-90)],["rear",Vector3(28,0,-86)]]:
			await audit_view(shot[1],enemy.position)
			await snapshot("final_head_"+shot[0])
		await audit_view(Vector3(28,0,-94),enemy.position)
		enemy.slow_blink()
		await get_tree().create_timer(.22).timeout
		await snapshot("final_head_halfblink")
		await get_tree().create_timer(.2).timeout
		await snapshot("final_head_closed")
		enemy.scare=1.0
		await audit_view(Vector3(31,0,-93),enemy.position)
		await snapshot("final_head_open_quarter")
		mode="playing"
		capture()
		await get_tree().create_timer(.42).timeout
		await snapshot("final_capture_stare")
		await get_tree().create_timer(.58).timeout
		await snapshot("final_capture_lunge")
		await get_tree().create_timer(.3).timeout
		await snapshot("final_capture_black")
		quit_game()
		return
	if "--hallway-render" in OS.get_cmdline_user_args():
		expansion.set_day(false)
		film.show()
		var encounter: RefCounted=progression.encounters_controller
		mode="playing"
		await audit_view(Vector3(38,4.2,26.5),Vector3(44,6,26.5))
		encounter.portrait_closed()
		await get_tree().create_timer(.2).timeout
		await audit_view(Vector3(38,4.2,26.5),Vector3(10,5.7,26))
		await get_tree().create_timer(.3).timeout
		await snapshot("final_hallway_distant")
		print("HALLWAY distance=",player.position.distance_to(enemy.position)," hunt=",progression.hunt_enabled," noticed=",encounter.reveal_seen)
		await get_tree().create_timer(1.45).timeout
		await snapshot("final_hallway_blink")
		print("HALLWAY blink=",enemy.face_material.get_shader_parameter("blink"))
		await get_tree().create_timer(5).timeout
		await snapshot("final_hallway_withdrawn")
		print("HALLWAY sighted=",encounter.reveal_seen," withdrawn=",encounter.reveal_finished," hunt=",progression.hunt_enabled)
		quit_game()
		return
	if "--door-render" in OS.get_cmdline_user_args():
		expansion.set_day(true)
		var d: Dictionary=layout.room_doors.G01[0]
		for opened in [false,true]:
			if opened: toggle_door(d,true); await get_tree().create_timer(.8).timeout
			for shot in [["inside",Vector3(10.7,0,5.7),Vector3(10.5,1.4,8.25)],["edge",Vector3(12.4,0,7.45),Vector3(10.7,1.4,8.25)],["hall",Vector3(10.8,0,10.4),Vector3(10.5,1.4,8.25)]]:
				await audit_view(shot[1],shot[2])
				await snapshot("door_"+shot[0]+"_"+str(opened))
		quit_game()
		return
	if "--graphics-final" in OS.get_cmdline_user_args():
		for day in [true,false]:
			expansion.set_day(day)
			await audit_view(Vector3(12,4.2,1.3),Vector3(12,5.4,-5))
			await snapshot("final_exterior_"+str(day))
			await audit_view(Vector3(28,0,10.4),Vector3(25,2.1,18))
			await snapshot("final_courtyard_"+str(day))
		enemy.position=Vector3(31,1.5,26);enemy.rotation.y=-PI/2;enemy.show()
		await audit_view(Vector3(35,0,26),Vector3(31,1.5,26))
		enemy.slow_blink()
		await get_tree().create_timer(.4).timeout
		await snapshot("final_creature_blink")
		for light in layout.inspection_lights: light.show()
		await audit_view(Vector3(31.3,4.2,5),Vector3(31.3,5,3.5))
		await snapshot("final_science_sink")
		print("FINAL PLACEMENT ",layout.placement.accepted.size()," accepted; rejected ",layout.placement.rejected)
		quit_game()
		return
	for day in [true,false]:
		expansion.set_day(day)
		for shot in [["courtyard_ground",Vector3(28,0,10.4),Vector3(25,2.1,18)],["courtyard_upper",Vector3(28,4.2,10.4),Vector3(25,2.3,18)],["exterior_ground",Vector3(12,0,1.3),Vector3(12,2,-5)],["exterior_upper",Vector3(12,4.2,1.3),Vector3(12,5.4,-5)]]:
			await audit_view(shot[1],shot[2])
			await snapshot("scenery_"+shot[0]+("_day" if day else "_night"))
		await audit_view(Vector3(12,4.2,1.1),Vector3(12,5.8,-5))
		player.camera.rotation.x=.95
		await snapshot("scenery_pitch_up_"+str(day))
		player.camera.rotation.x=-.95
		await snapshot("scenery_pitch_down_"+str(day))
		await audit_view(Vector3(13.5,4.2,1.1),Vector3(12,5.8,-5))
		await snapshot("scenery_sideways_"+str(day))
	for light in layout.inspection_lights: light.show()
	await audit_view(Vector3(19.4,0,33.0),Vector3(19.4,1.9,35.9))
	await snapshot("scenery_student_art")
	await audit_view(Vector3(31.3,4.2,5.0),Vector3(31.3,5.0,3.5))
	await snapshot("scenery_science_sink")
	await audit_view(Vector3(14.8,0,3.6),Vector3(14.1,.9,2.7))
	await snapshot("scenery_desk_belongings")
	for light in layout.inspection_lights: light.hide()
	enemy.position=Vector3(31,1.5,26)
	enemy.rotation.y=-PI/2
	enemy.show()
	await audit_view(Vector3(35,0,26),Vector3(31,1.5,26))
	await snapshot("correction_creature_front")
	enemy.slow_blink()
	await get_tree().create_timer(.4).timeout
	await snapshot("correction_creature_blink")
	await audit_view(Vector3(31,0,22),Vector3(31,1.5,26))
	await snapshot("correction_creature_side")
	mode="playing"
	capture()
	await get_tree().create_timer(.42).timeout
	await snapshot("correction_capture_stare")
	await get_tree().create_timer(.58).timeout
	await snapshot("correction_capture_lunge")
	await get_tree().create_timer(.3).timeout
	await snapshot("correction_capture_black")
	quit_game()
