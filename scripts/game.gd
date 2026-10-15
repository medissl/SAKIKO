extends Node3D
## All coordinates are metres. Two parallel corridors loop at both ends.
const Creature = preload("res://scripts/creature.gd")
const Tuning = preload("res://scripts/config.gd")
const Expansion = preload("res://scripts/school_expansion.gd")
const Progression = preload("res://scripts/progression.gd")
const Player = preload("res://scripts/player.gd")
const ROOMS = ["1年 A組", "2年 B組", "保健室", "職員室", "3年 C組", "視聴覚室"]
var ending: Control
var ending_started := false
var entrance_locks: Array[MeshInstance3D] = []
var expansion: Node
var progression: Node
var music: AudioStreamPlayer
var nav_blocked := {}
var mode := "menu"
var world: Node3D
var player: CharacterBody3D
var enemy: CharacterBody3D
var menu_camera: Camera3D
var scare_camera: Camera3D
var scare_head: CharacterBody3D
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
var sounds := {}
var lights: Array[OmniLight3D] = []
var nav := AStar3D.new()
var nav_lookup := {}
var path := PackedVector3Array()
var waypoint := Vector3.ZERO
var target := Vector3.ZERO
var last_seen := Vector3.ZERO
var ai_state := "roam"
var state_time := 0.0
var repath := 0.0
var stuck_time := 0.0
var previous_enemy := Vector3.ZERO
var grace := 0.0
var collected := 0
var exit_open := false
var checkpoint := Vector3(-20.5,0,-5)
var pain_triggered := false
var exit_panels: Array[MeshInstance3D] = []
var clock := 0.0
var breath: AudioStreamPlayer3D
var ambient: AudioStreamPlayer
var hum: AudioStreamPlayer
var creak_clock := 11.0
var capture_time := 0.0
var message_time := 0.0
var settings := {"master": .8,"ambience": .65,"sfx": .8,"sensitivity": 2.0,"fullscreen": false,"shake": true,"reduced":false}
var options_return := "menu"
var font: SystemFont
var serif: SystemFont
var horror_font: Font
var desk_asset: PackedScene
var chair_asset: PackedScene
var exit_point := Vector3(-24,0,0)
var room_key_points: Array[Array] = []

func _ready() -> void:
	randomize()
	get_tree().auto_accept_quit = false
	setup_input()
	load_settings()
	setup_audio()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic","MS Gothic","Arial"])
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia","Times New Roman"])
	horror_font = load("res://assets/fonts/SakikoThorn.ttf")
	horror_font.fallbacks = [font]
	desk_asset = load("res://assets/furniture/desk/desk.gltf")
	chair_asset = load("res://assets/furniture/chair/chair.gltf")
	make_materials()
	build_school()
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
	breath.pitch_scale = .84
	breath.bus = "Ghost"
	breath.volume_db = -13
	breath.max_distance = 23
	breath.unit_size = 3
	enemy.add_child(breath)
	breath.finished.connect(breath.play)
	breath.play()
	menu_camera = Camera3D.new()
	menu_camera.position = Vector3(-21,1.65,-5)
	add_child(menu_camera)
	menu_camera.look_at(Vector3(20,1.5,-5.3))
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
	show_main_menu()
	if "--verify" in OS.get_cmdline_user_args(): call_deferred("verify_game")
	if "--render-audit" in OS.get_cmdline_user_args(): call_deferred("render_audit")
	if "--presentation-audit" in OS.get_cmdline_user_args(): call_deferred("presentation_audit")

func setup_input() -> void:
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
	for pair in [["Master","master"],["Ambience","ambience"],["SFX","sfx"]]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(pair[0]),linear_to_db(maxf(.0001,settings[pair[1]])))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func setup_audio() -> void:
	for bus in ["Ambience","SFX","Ghost"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Ghost"),"SFX")
	if AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Ghost"))==0:
		var room := AudioEffectReverb.new()
		room.room_size = .38
		room.damping = .7
		room.wet = .16
		room.dry = .92
		AudioServer.add_bus_effect(AudioServer.get_bus_index("Ghost"),room)
	for clip_name in ["ambience","hum","creak","step","hover","press","key","unlock","locked","door","breath","chase","capture","menu_music","chime","classroom","run_step","pant","giggle","scream","latch","close","capture_v2","player_pain","quiet_knocks"]:
		sounds[clip_name] = load("res://assets/audio/%s.wav" % clip_name)
	sounds.sakiko_humming = load("res://assets/audio/sakiko_humming.ogg")
	sounds.sakiko_scream = load("res://assets/audio/sakiko_scream.ogg")
	sounds.sakiko_laugh = load("res://assets/audio/sakiko_laugh.ogg")
	ambient = AudioStreamPlayer.new()
	ambient.stream = sounds.ambience
	ambient.bus = "Ambience"
	ambient.volume_db = -12
	add_child(ambient)
	ambient.finished.connect(ambient.play)
	ambient.play()
	hum = AudioStreamPlayer.new()
	hum.stream = sounds.hum
	hum.volume_db = -24
	hum.bus = "Ambience"
	add_child(hum)
	hum.finished.connect(hum.play)
	hum.play()
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
	p.volume_db = db
	p.pitch_scale = pitch
	p.bus = "Ghost" if clip_name.begins_with("sakiko_") else "SFX"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

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
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
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
		obstacles.append(mi.global_transform*AABB(-size*.5,size))
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
	world.add_child(l)
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
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("142226")
	e.fog_density = .008
	e.fog_sky_affect = 0
	env.environment = e
	world.add_child(env)
	# Continuous floors and ceilings; walls form a deliberately legible rectangular loop.
	for z in [-5.0,5.0]:
		box(Vector3(0,-.15,z),Vector3(54,.3,4),"floor")
		box(Vector3(0,3.5,z),Vector3(54,.2,4),"ceiling")
		box(Vector3(0,1.7,z-signf(z)*2),Vector3(46,3.4,.18),"wall")
		for x in range(-20,24,8):
			box(Vector3(x,3.24,z),Vector3(1.8,.10,.25),"metal",false)
			box(Vector3(x,3.16,z),Vector3(1.56,.045,.14),"light",false)
			lamp(Vector3(x,2.95,z),.58 if x%16 == 0 else .22,Color("b3c7ad"))
		for x in range(-24,25,4):
			box(Vector3(x,3.27,z),Vector3(.12,.25,4),"dark",false)
			box(Vector3(x,.12,z-signf(z)*1.87),Vector3(3.9,.2,.08),"wood",false)
	for x in [-25.0,25.0]:
		box(Vector3(x,-.15,0),Vector3(4,.3,14),"floor")
		box(Vector3(x,3.5,0),Vector3(4,.2,14),"ceiling")
		if x<0: box(Vector3(x+signf(x)*2,1.7,0),Vector3(.2,3.4,14),"wall")
		lamp(Vector3(x,2.7,0),.5,Color("8aabbc"))
	# The entrance is a short vestibule facing the west connector.
	box(Vector3(-26.84,1.7,0),Vector3(.1,3.1,3.2),"dark",false)
	for z in [-.78,.78]:
		exit_panels.append(box(Vector3(-26.70,1.5,z),Vector3(.12,2.9,1.48),"metal",false))
		box(Vector3(-26.60,1.95,z),Vector3(.08,1.25,1.18),"glass",false)
	for i in range(4):
		var body := box(Vector3(-26.48,.62+i*.49,0),Vector3(.12,.25,.24),"red",false)
		entrance_locks.append(body)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = .075
		torus.outer_radius = .095
		ring.mesh = torus
		ring.rotation.z = PI/2
		ring.position = Vector3(-26.48,.80+i*.49,0)
		ring.material_override = materials.metal
		world.add_child(ring)
	label3("非常口  /  ENTRANCE\n4 KEYS REQUIRED",Vector3(-26.47,3.06,0),PI/2,.007)
	for i in range(8):
		for y in range(3):
			var p := Vector3(-25.7,.4+y*.58,3.1+i*.38)
			box(p,Vector3(.65,.53,.34),"metal")
			box(p+Vector3(.34,0,0),Vector3(.03,.35,.22),"dark",false)
	# Six rooms, each with TWO wide sliding doors so players can break sight and loop.
	for side in [-1,1]:
		for ri in range(3):
			var cx := float(ri-1)*16
			var cz := float(side)*12
			var idx := ri+(3 if side>0 else 0)
			box(Vector3(cx,-.15,cz),Vector3(14,.3,10),"floor")
			box(Vector3(cx,3.5,cz),Vector3(14,.2,10),"ceiling")
			box(Vector3(cx,1.7,side*17),Vector3(14,3.4,.2),"wall")
			for dx in [-7,7]: box(Vector3(cx+dx,1.7,cz),Vector3(.2,3.4,10),"wall")
			var door_z: float = side*7.0
			for seg in [[-6.5,1.0],[0.0,6.0],[6.5,1.0]]:
				box(Vector3(cx+seg[0],1.7,door_z),Vector3(seg[1],3.4,.18),"wall")
			for dx in [-4.5,4.5]:
				box(Vector3(cx+dx,3.06,door_z),Vector3(3.4,.68,.24),"wood")
				make_door(Vector3(cx+dx,0,door_z),side)
				label3(ROOMS[idx],Vector3(cx+dx,2.92,door_z-side*.16),0.0 if side<0 else PI,.0055)
			for dx in [-3.8,3.8]:
				make_exterior_window(cx,side,dx,ri)
			# Chalkboard on the side wall leaves the exterior windows unobstructed.
			box(Vector3(cx-6.82,2.0,cz),Vector3(.08,1.5,4.3),"chalk",false)
			box(Vector3(cx-6.70,1.20,cz),Vector3(.23,.08,4.5),"wood",false)
			label3("日直   10月15日\n\n 帰りましょう。",Vector3(cx-6.72,2.05,cz),PI/2,.005)
			var spawn_points: Array = []
			if idx == 2: # Infirmary: recognizable beds and red medicine cabinet.
				for dx in [-4,0,4]:
					box(Vector3(cx+dx,.52,cz+side*1.4),Vector3(1.7,.6,3),"metal")
					box(Vector3(cx+dx,.88,cz+side*1.4),Vector3(1.65,.15,2.9),"paper",false)
					box(Vector3(cx+dx,1,cz+side*2.3),Vector3(1.3,.15,.6),"wall",false)
				box(Vector3(cx+5,.9,cz-1),Vector3(1.5,1.8,.65),"paper")
				box(Vector3(cx+5,1.3,cz-1.34),Vector3(.65,.16,.02),"red",false)
				box(Vector3(cx+5,1.3,cz-1.35),Vector3(.16,.65,.02),"red",false)
				desk(Vector3(cx-4,0,cz-2.8))
				spawn_points.append(Vector3(cx-4,.91,cz-2.8))
			else:
				for dx in [-3.9,0.0,3.9]:
					for dz in [-1.4,1.3]:
						desk(Vector3(cx+dx,0,cz+dz),PI/2 if idx==0 else 0.0)
						spawn_points.append(Vector3(cx+dx,.91,cz+dz))
				desk(Vector3(cx+3,0,cz+side*3.5))
				if idx==3:
					for dx in [-5.7,5.7]: box(Vector3(cx+dx,.85,cz+2.8),Vector3(1.5,1.7,2.2),"metal")
				if idx==5:
					box(Vector3(cx-3,.7,cz+3.6),Vector3(3.2,1.4,.8),"dark")
					box(Vector3(cx-3,.95,cz+3.08),Vector3(3,.12,.36),"paper",false)
					for k in range(22):
						box(Vector3(cx-4.4+k*.13,1.03,cz+3.18),Vector3(.055,.05,.19),"dark",false)
			room_key_points.append(spawn_points)
			# Noticeboard with layered papers, clock and a room-specific landmark.
			box(Vector3(cx,2.05,door_z+side*.14),Vector3(2.8,1.25,.12),"wood",false)
			for i in range(6):
				box(Vector3(cx-.95+i*.38,2.0+sin(i*4.0)*.12,door_z+side*.22),Vector3(.32,.64,.012),"paper",false)
			var clock_face := MeshInstance3D.new()
			var disk := CylinderMesh.new()
			disk.top_radius = .28
			disk.bottom_radius = .28
			disk.height = .035
			clock_face.mesh = disk
			clock_face.material_override = materials.paper
			clock_face.position = Vector3(cx+6.84,2.75,cz)
			clock_face.rotation.z = PI/2
			world.add_child(clock_face)
			box(Vector3(cx+6.81,2.82,cz),Vector3(.035,.18,.025),"dark",false)
			box(Vector3(cx+6.80,2.75,cz+.09),Vector3(.035,.025,.2),"dark",false)
			lamp(Vector3(cx,3.1,cz),.34,Color("b8c2aa"))
			box(Vector3(cx,3.25,cz),Vector3(2,.1,.3),"light",false)
	# Dust uses tiny unlit quads, distributed sparingly in the lit corridors.
	var dustmat := StandardMaterial3D.new()
	dustmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dustmat.albedo_color = Color(.46,.58,.6,.20)
	dustmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var particles := GPUParticles3D.new()
	particles.amount = 110
	particles.lifetime = 16
	particles.visibility_aabb = AABB(Vector3(-28,0,-18),Vector3(56,4,36))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(26,1.5,16)
	process.gravity = Vector3(0,.014,0)
	process.initial_velocity_min = .015
	process.initial_velocity_max = .045
	process.scale_min = .008
	process.scale_max = .022
	particles.process_material = process
	var quad := SphereMesh.new()
	quad.material = dustmat
	particles.draw_pass_1 = quad
	particles.position.y = 1.5
	world.add_child(particles)

func desk(pos: Vector3,yaw := 0.0) -> void:
	var group := Node3D.new()
	group.position = pos
	group.rotation.y = yaw
	world.add_child(group)
	var model := desk_asset.instantiate() as Node3D
	model.scale = Vector3.ONE*.95
	group.add_child(model)
	var chair := chair_asset.instantiate() as Node3D
	chair.position = Vector3(0,0,.83)
	chair.scale = Vector3.ONE*.91
	group.add_child(chair)
	# Simple invisible collision volumes preserve the detailed imported silhouette.
	var table_collision := box(Vector3(0,.80,0),Vector3(.70,.1,.56),"wood",true,group)
	table_collision.visible = false
	var chair_collision := box(Vector3(0,.43,.83),Vector3(.50,.10,.50),"wood",true,group)
	chair_collision.visible = false
	var back_collision := box(Vector3(0,.70,1.09),Vector3(.5,.50,.07),"wood",true,group)
	back_collision.visible = false
	var paper := box(Vector3(.12,.85,-.04),Vector3(.23,.004,.32),"paper",false,group)
	paper.rotation.y = sin(pos.x)*.08

func make_door(pos: Vector3, side: int) -> void:
	var root := Node3D.new()
	root.position = pos
	world.add_child(root)
	box(Vector3(0,1.34,0),Vector3(2.95,2.65,.11),"wood",false,root)
	box(Vector3(0,1.85,-side*.065),Vector3(2.5,1.05,.025),"glass",false,root)
	for dx in [-1.33,0.0,1.33]: box(Vector3(dx,1.85,-side*.09),Vector3(.06,1.2,.05),"metal",false,root)
	box(Vector3(1.12,1.12,-side*.10),Vector3(.07,.26,.06),"metal",false,root)
	var body := StaticBody3D.new()
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.95,2.65,.15)
	cs.shape = shape
	cs.position.y = 1.34
	body.add_child(cs)
	doors.append({"node":root,"shape":cs,"origin":pos,"open":false,"busy":false})

func walkable(p: Vector3) -> bool:
	var valid := (absf(p.z-5)<1.5 or absf(p.z+5)<1.5) and p.x>-26 and p.x<82
	valid = valid or (absf(p.x-25)<1.3 or absf(p.x+25)<1.3 or absf(p.x-81)<1.3) and absf(p.z)<6.2
	for cx in Tuning.ROOM_CENTRES:
		for side in [-1,1]:
			if absf(p.x-cx)<6.3 and absf(p.z-side*12)<4.3: valid = true
			if (absf(p.x-cx-4.5)<1.0 or absf(p.x-cx+4.5)<1.0) and absf(p.z-side*7)<1.7: valid = true
	return valid and not nav_blocked.has(Vector2i(roundi(p.x*2),roundi(p.z*2)))

func build_navigation() -> void:
	for obstacle in obstacles:
		if obstacle.position.y>2.5 or obstacle.end.y<.35: continue
		var a: AABB = obstacle.grow(.92)
		for x in range(ceili(a.position.x*2),floori(a.end.x*2)+1):
			for z in range(ceili(a.position.z*2),floori(a.end.z*2)+1): nav_blocked[Vector2i(x,z)] = true
	for x in range(-52,165):
		for z in range(-34,35):
			var p := Vector3(x*.5,1.5,z*.5)
			if walkable(p):
				var id := nav.get_available_point_id()
				nav.add_point(id,p)
				nav_lookup[Vector2i(x,z)] = id
	for cell in nav_lookup:
		for offset in [Vector2i(1,0),Vector2i(0,1)]:
			if nav_lookup.has(cell+offset): nav.connect_points(nav_lookup[cell],nav_lookup[cell+offset])
	# Discard isolated pockets narrower than the creature's body (between desks).
	var connected := {}
	var pending: Array[int] = [nav.get_closest_point(Vector3(-22,1.5,-5))]
	while not pending.is_empty():
		var id: int = pending.pop_back()
		if connected.has(id): continue
		connected[id] = true
		for next in nav.get_point_connections(id):
			if not connected.has(next): pending.append(next)
	for id in nav.get_point_ids():
		if not connected.has(id): nav.remove_point(id)

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
	hud = text_label("",20)
	hud.position = Vector2(38,28)
	prompt = text_label("",19)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-290,-110)
	prompt.size = Vector2(580,45)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message = text_label("",17)
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message.position = Vector2(-440,-65)
	message.size = Vector2(880,40)
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
	for c in menu.get_children():
		menu.remove_child(c)
		c.queue_free()
	menu.visible = true
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
	l.add_theme_font_override("font",horror_font)
	l.add_theme_color_override("font_color",Color("8f353a"))
	text_label(subtitle,16,v)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	v.add_child(spacer)
	return v

func show_main_menu() -> void:
	if is_instance_valid(ending): ending.queue_free()
	ending = null
	film.show()
	mode = "menu"
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
	var sub := text_label("THE LAST BELL HAS ALREADY RUNG",13,title_box)
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
	var first := button("PLAY",play_intro,navbox)
	button("OPTIONS",func(): options_return="menu"; show_options(),navbox)
	button("CREATOR",show_credits,navbox)
	button("EXIT",quit_game,navbox)
	for nav_button in navbox.get_children():
		nav_button.add_theme_font_override("font",horror_font)
		nav_button.add_theme_font_size_override("font_size",32)
	first.grab_focus()
	var control_label := text_label("W A S D   MOVE     /     SHIFT   RUN     /     E   INTERACT     /     F   LIGHT     /     ESC   PAUSE",13,menu)
	control_label.anchor_top = 1
	control_label.position = Vector2(42,-38)

func show_options() -> void:
	var v := panel_stack("OPTIONS","Make the silence comfortable.")
	for row in [["Master volume","master",0.0,1.0,.01],["Ambience","ambience",0.0,1.0,.01],["Sound effects","sfx",0.0,1.0,.01],["Mouse sensitivity","sensitivity",.3,5.0,.1]]:
		text_label(row[0],17,v)
		var slider := HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = row[4]
		slider.value = settings[row[1]]
		var key: String = row[1]
		slider.value_changed.connect(func(value): settings[key]=value; save_settings())
		v.add_child(slider)
	for row in [["Fullscreen","fullscreen"],["Camera shake","shake"],["Reduced analog / blur effects","reduced"]]:
		var check := CheckButton.new()
		check.text = row[0]
		check.button_pressed = settings[row[1]]
		check.add_theme_font_override("font",horror_font)
		var key: String = row[1]
		check.toggled.connect(func(on): settings[key]=on; save_settings())
		v.add_child(check)
	button("BACK",options_back,v)
	v.get_child(4).grab_focus()

func options_back() -> void:
	if options_return=="pause": show_pause()
	else: show_main_menu()

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
	if is_instance_valid(ending): ending.queue_free()
	ending = null
	ending_started = false
	mode = "transition"
	curtain.modulate.a = 1
	clear_menu()
	menu.visible = false
	collected = 0
	for lock in entrance_locks: lock.material_override = materials.red
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
		d.shape.disabled = false
	progression.reset()
	checkpoint = Vector3(-20.5,0,-5)
	player.reset()
	player.position = Vector3(-20.5,0,-9)
	player.rotation = Vector3.ZERO
	player.pitch = 0
	player.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.lamp.visible = true
	player.camera.current = true
	enemy.position = Vector3(72,1.5,5)
	enemy.rotation = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	enemy.visible = true
	previous_enemy = enemy.position
	ai_state = "roam"
	state_time = 0
	repath = 0
	stuck_time = 0
	path.clear()
	grace = 18
	breath.play()
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
	toast("Find the entrance.  |  WASD move · SHIFT sprint · E interact · F light · ESC pause",9)
	create_tween().tween_property(curtain,"modulate:a",0.0,.7)

func spawn_key(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	world.add_child(root)
	var torus := TorusMesh.new()
	torus.inner_radius = .055
	torus.outer_radius = .10
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = materials.gold
	ring.rotation.x = PI/2
	root.add_child(ring)
	box(Vector3(.15,0,0),Vector3(.25,.045,.045),"gold",false,root)
	box(Vector3(.25,-.05,0),Vector3(.045,.10,.045),"gold",false,root)
	var glint := OmniLight3D.new()
	glint.position.y = .18
	glint.light_color = Color("b09a62")
	glint.light_energy = .28
	glint.omni_range = 1.2
	root.add_child(glint)
	keys.append(root)

func toast(value: String, seconds := 3.0) -> void:
	message.text = value
	message_time = seconds

func target_visible(point: Vector3,reach: float,dot: float) -> bool:
	var eye: Vector3 = player.camera.global_position
	var diff := point-eye
	if diff.length()>reach or (-player.camera.global_basis.z).dot(diff.normalized())<dot: return false
	var q := PhysicsRayQueryParameters3D.create(eye,point,1)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.position.distance_to(point)<.12

func interactable() -> Dictionary:
	for key in keys:
		if not is_instance_valid(key) or not key.visible or key.get_meta("collected",false): continue
		if target_visible(key.global_position,2.5,.94): return {"type":"key","node":key}
	var puzzle: Dictionary = progression.targeted()
	if not puzzle.is_empty(): return puzzle
	if target_visible(Vector3(-26.42,1.4,0),3.1,.83): return {"type":"exit"}
	for d in doors:
		var centre: Vector3 = d.node.position+Vector3(0,1.3,0)
		if d.open: centre = d.origin+Vector3(1.34,1.3,-signf(d.origin.z)*.18)
		if target_visible(centre,2.8,.86): return {"type":"door","door":d}
	return {}

func interact() -> void:
	if mode!="playing": return
	var it := interactable()
	if it.is_empty(): return
	match it.type:
		"key":
			if it.node.get_meta("collected",false): return
			it.node.set_meta("collected",true)
			it.node.visible = false
			collected += 1
			entrance_locks[collected-1].material_override = materials.gold
			update_checkpoint(it.node.position)
			sound("key",-14)
			toast("Entrance key  -  %d/4   |   Checkpoint saved" % collected)
			if collected==4: toast("All four keys. Return to the entrance.",5)
		"door": toggle_door(it.door)
		"exit":
			progression.discovered = true
			if collected<4:
				sound("locked",-16)
				toast("Four locks. Find the entrance keys  -  %d/4." % collected)
				for i in range(exit_panels.size()):
					var tw := create_tween()
					tw.tween_property(exit_panels[i],"position:x",progression.exit_origins[i].x-.045,.07)
					tw.tween_property(exit_panels[i],"position",progression.exit_origins[i],.13)
					progression.puzzle_tweens.append(tw)
			elif not exit_open:
				exit_open = true
				sound("unlock",-13)
				for i in range(exit_panels.size()):
					var tw := create_tween()
					tw.tween_property(exit_panels[i],"position:z",progression.exit_origins[i].z+(-1.3 if i==0 else 1.3),.7)
					progression.puzzle_tweens.append(tw)
				toast("The entrance opens. E  -  step outside.",4)
			else: victory()
		_: progression.interact(it)

func toggle_door(d: Dictionary, force_open := false) -> void:
	if d.busy or (force_open and d.open): return
	if d.open and not force_open:
		if player.position.distance_to(d.origin)<1.65 or Vector2(enemy.position.x-d.origin.x,enemy.position.z-d.origin.z).length()<1.9: return
	d.busy = true
	d.open = true if force_open else not d.open
	var destination: Vector3 = d.origin+Vector3(2.8 if d.open else 0.0,0,0)
	if d.has("tween") and d.tween: d.tween.kill()
	d.tween = create_tween()
	sound("latch",-25)
	sound("door",-27 if force_open else -20)
	d.tween.tween_property(d.node,"position",destination,.55)
	d.tween.tween_callback(func():
		d.busy = false
		if not d.open: sound("close",-21))

func clear_line(a: Vector3,b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a,b,1)
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func flashlight_exposure() -> bool:
	if not player.lamp.visible: return false
	var diff: Vector3 = enemy.position-player.camera.global_position
	return diff.length()<Tuning.FLASHLIGHT_RANGE and (-player.camera.global_basis.z).dot(diff.normalized())>Tuning.FLASHLIGHT_DOT and clear_line(player.camera.global_position,enemy.position)

func sees_player() -> bool:
	var diff: Vector3 = player.position+Vector3(0,1.3,0)-enemy.position
	var distance := diff.length()
	if distance>Tuning.FLASHLIGHT_RANGE: return false
	var flat := Vector3(diff.x,0,diff.z).normalized()
	var normal_sight := distance<Tuning.DETECTION_RANGE and (distance<3 or (-enemy.global_basis.z).dot(flat)>.38)
	return (normal_sight or flashlight_exposure()) and clear_line(enemy.position,player.position+Vector3(0,1.3,0))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if mode=="playing": show_pause()
		elif mode=="paused": resume_game()

func show_pause() -> void:
	mode = "paused"
	var v := panel_stack("PAUSED","The halls are still.")
	button("RESUME",resume_game,v).grab_focus()
	button("OPTIONS",func(): options_return="pause"; show_options(),v)
	button("MAIN MENU",show_main_menu,v)
	breath.stream_paused = true
	player.pant.stream_paused = true

func resume_game() -> void:
	mode = "playing"
	menu.visible = false
	hud.visible = true
	prompt.visible = true
	message.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	breath.stream_paused = false
	player.pant.stream_paused = false

func victory() -> void:
	if ending_started or mode!="playing" or collected!=4: return
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
	if mode!="playing": return
	player.pant.stop()
	progression.giggle.stop()
	mode = "capture"
	capture_time = 0
	pain_triggered = false
	var env: Environment = world.get_child(0).environment
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
	scare_camera.current = true
	scare_camera.rotation = Vector3.ZERO
	scare_head.position = Vector3(0,-40,-3.5)
	sound("capture_v2",-5)
	sound("sakiko_scream",-7,.78)
	film.material.set_shader_parameter("trauma",.8)

func death_screen() -> void:
	mode = "dead"
	scare_head.visible = false
	var v := panel_stack("YOU DIED","She swallowed the last sound. Your checkpoint remains.")
	v.get_child(0).add_theme_color_override("font_color",Color("b52b34"))
	button("RETURN TO CHECKPOINT",return_to_checkpoint,v).grab_focus()
	button("RESTART RUN",start_game,v)
	button("MAIN MENU",show_main_menu,v)
	curtain.modulate.a = 0
	film.material.set_shader_parameter("trauma",0)

func _physics_process(delta: float) -> void:
	if mode!="playing": return
	grace -= delta
	state_time += delta
	repath -= delta
	var sees := grace<=0 and sees_player()
	if sees:
		last_seen = player.position+Vector3(0,1.5,0)
		if ai_state!="chase":
			ai_state = "chase"
			progression.spotted()
		state_time = 0
	elif ai_state=="chase" and state_time>1.1:
		ai_state = "investigate"
		state_time = 0
		navigate(last_seen)
	if ai_state=="chase" and repath<=0:
		navigate(last_seen)
		repath = .45
	if ai_state=="roam" and (path.is_empty() or state_time>22):
		var points := [Vector3(-22,1.5,-5),Vector3(22,1.5,-5),Vector3(78,1.5,-5),Vector3(78,1.5,5),Vector3(-22,1.5,5),Vector3(35.5,1.5,-12),Vector3(60.5,1.5,12)]
		navigate(points[randi()%points.size()])
		state_time = 0
	if ai_state=="investigate" and (path.is_empty() or state_time>12):
		ai_state = "search"
		state_time = 0
	if ai_state=="search":
		enemy.rotate_y(delta*.6)
		if state_time>4.5:
			ai_state = "roam"
			path.clear()
	else:
		if not path.is_empty():
			waypoint = path[0]
			var offset: Vector3 = waypoint-enemy.position
			offset.y = 0
			if offset.length()<.25: path.remove_at(0)
			else:
				var direction := offset.normalized()
				var speed := Tuning.CHASE_SPEED if ai_state=="chase" else 1.45
				if ai_state=="investigate": speed = 2.2
				enemy.velocity = enemy.velocity.move_toward(direction*speed,delta*12)
				var yaw := atan2(-direction.x,-direction.z)
				enemy.rotation.y = lerp_angle(enemy.rotation.y,yaw,delta*5)
				enemy.move_and_slide()
	for d in doors:
		if Vector2(enemy.position.x-d.origin.x,enemy.position.z-d.origin.z).length()<2.8: toggle_door(d,true)
	if enemy.position.distance_to(previous_enemy)<delta*.12 and not path.is_empty(): stuck_time += delta
	else: stuck_time = 0
	previous_enemy = enemy.position
	if stuck_time>2:
		# Recover by replanning; only snap a few centimetres to the nearest valid cell.
		var nearest := nav.get_point_position(nav.get_closest_point(enemy.position))
		if enemy.position.distance_to(nearest)<1.0: enemy.position = nearest
		navigate(target)
		stuck_time = 0
	if grace<=0 and enemy.position.distance_to(player.position+Vector3(0,1.4,0))<1.25 and clear_line(enemy.position,player.position+Vector3(0,1.4,0)): capture()

func _process(delta: float) -> void:
	clock += delta
	if music:
		music.volume_db = lerpf(music.volume_db,-18.0 if mode=="menu" else -65.0,minf(1,delta*1.8))
		var story_quiet := mode in ["ending","credits"]
		ambient.volume_db = -80 if story_quiet else lerpf(ambient.volume_db,-25.0 if mode=="playing" else -32.0,minf(1,delta*2))
		hum.volume_db = -80 if story_quiet else lerpf(hum.volume_db,-32.0,minf(1,delta*2))
	if film: film.material.set_shader_parameter("reduced",settings.reduced)
	if mode=="menu":
		menu_camera.position.z = -5+sin(clock*.09)*.12
		menu_camera.rotation.z = sin(clock*.12)*.003
	if not lights.is_empty():
		lights[2].light_energy = .055 if sin(clock*1.7)>-.95 else .008
	if mode=="playing":
		hud.text = progression.objective()
		var it := interactable()
		prompt.text = ""
		if not it.is_empty():
			match it.type:
				"key": prompt.text = "E  -  Pick up entrance key"
				"door": prompt.text = "E  -  Close" if it.door.open else "E  -  Open"
				"exit": prompt.text = "E  -  Escape" if exit_open else "E  -  Try entrance"
				_: prompt.text = it.get("label", "E  -  Interact")
		message_time -= delta
		message.modulate.a = clampf(message_time,0,1)
		for key in keys:
			if is_instance_valid(key): key.rotation.y += delta*.22
		creak_clock -= delta
		if creak_clock<0:
			sound("creak",-28,randf_range(.7,1.1))
			creak_clock = randf_range(13,25)
	if mode=="capture":
		capture_time += delta
		var t := capture_time
		var lunge := 1-pow(1-clampf(t/.18,0,1),3)
		scare_head.position.z = lerpf(-3.5,-2.08,lunge)
		scare_head.scare = clampf(t*4.8,0,1.35)
		scare_head.rotation.z = -.07+sin(t*53)*.014*exp(-t*4)
		# The camera dives through the empty mouth opening, between the teeth.
		var swallow := smoothstep(.56,1.27,t)
		scare_camera.position = Vector3(0,lerpf(-40,-40.63,swallow),lerpf(0,-1.96,swallow))
		scare_camera.fov = lerpf(72,86,swallow)
		scare_camera.look_at(Vector3(0,lerpf(-40.05,-40.63,smoothstep(.40,.80,t)),-2.6))
		if settings.shake and not settings.reduced:
			scare_camera.rotation.z = sin(t*61)*.022*exp(-t*5)
			scare_camera.position.x = sin(t*83)*.018*exp(-t*6)
		curtain.modulate.a = clampf((t-1.19)/.18,0,1)
		if t>1.85: death_screen()

func update_checkpoint(key_pos: Vector3) -> void:
	var closest := -16.0
	for cx in Tuning.ROOM_CENTRES:
		if absf(cx-key_pos.x)<absf(closest-key_pos.x): closest = cx
	checkpoint = Vector3(closest-4.5,0,-5 if key_pos.z<0 else 5)

func return_to_checkpoint() -> void:
	mode = "playing"
	player.reset()
	player.position = checkpoint
	player.rotation = Vector3.ZERO
	player.pitch = 0
	player.camera.rotation = Vector3.ZERO
	player.camera.current = true
	player.lamp.visible = true
	player.velocity = Vector3.ZERO
	enemy.position = Vector3(-20,1.5,5) if checkpoint.x>30 else Vector3(72,1.5,5)
	enemy.velocity = Vector3.ZERO
	enemy.visible = true
	scare_head.visible = false
	path.clear()
	ai_state = "roam"
	state_time = 0
	stuck_time = 0
	grace = 16
	repath = 0
	progression.scream_cooldown = 8
	curtain.modulate.a = 0
	film.material.set_shader_parameter("trauma",0)
	expansion.set_day(false)
	breath.play()
	resume_game()
	toast("Checkpoint restored. Keys and solved puzzles retained.",4)

func verify_game() -> void:
	var suite = preload("res://tests/integration.gd").new()
	await suite.run(self)

func snapshot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/artifacts/%s.png" % filename)
	print("RENDER ",filename)

func presentation_audit() -> void:
	start_game()
	grace = 999
	mode = "paused"
	scare_head.show()
	scare_head.scare = 0
	scare_head.position = Vector3(0,-40,-2.08)
	scare_camera.current = true
	var env: Environment = world.get_child(0).environment
	env.ambient_light_energy = .6
	env.background_color = Color("171b1c")
	var fill := OmniLight3D.new()
	fill.position = Vector3(2,-38,-4)
	fill.light_energy = 4
	fill.omni_range = 8
	add_child(fill)
	for pose in [["creature_front_studio",Vector3(0,-40,2)],["creature_profile_studio",Vector3(4,-40,-2.08)],["creature_back_studio",Vector3(0,-40,-6.4)],["creature_threequarter_studio",Vector3(3,-40,1)]]:
		scare_camera.position = pose[1]
		scare_camera.look_at(scare_head.position)
		await snapshot(pose[0])
	fill.queue_free()
	env.ambient_light_energy = .075
	mode = "playing"
	capture()
	await get_tree().create_timer(.3).timeout
	await snapshot("capture")
	await get_tree().create_timer(.62).timeout
	await snapshot("capture_mouth")
	await get_tree().create_timer(1.2).timeout
	start_game()
	collected = 4
	victory()
	await get_tree().create_timer(1.4).timeout
	ending.advance()
	ending.advance()
	ending.advance()
	ending.advance()
	ending.advance()
	await get_tree().create_timer(1.3).timeout
	ending.advance()
	await get_tree().create_timer(2).timeout
	ending.credits_y = -400
	ending.credits.position.y = -400
	await get_tree().process_frame
	print("CREDITS DIAGNOSTIC ",ending.credits.get_global_rect()," alpha ",ending.curtain.modulate.a," label0 ",ending.credits.get_child(0).get_global_rect()," visible ",ending.credits.get_child(0).is_visible_in_tree())
	await snapshot("credits")
	ending.credits_y = -2500
	ending.credits.position.y = -2500
	await snapshot("credits_attribution")
	ending.finish()
	await get_tree().create_timer(1).timeout
	quit_game()

func render_audit() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	await get_tree().create_timer(1).timeout
	await snapshot("menu")
	show_credits()
	await snapshot("creator")
	show_options()
	await snapshot("options")
	play_intro()
	await get_tree().create_timer(1).timeout
	await snapshot("intro_day")
	player.position = Vector3(-10,0,-9)
	player.camera.position.y = 1.4
	player.camera.look_at(Vector3(-18,1,-13))
	mode = "audit_intro"
	await snapshot("intro_actors")
	player.position = Vector3(-19.8,0,-14)
	player.camera.look_at(Vector3(-19.8,2,-16.84))
	await snapshot("window_day")
	mode = "intro"
	progression.intro_time = 8.2
	await get_tree().process_frame
	await snapshot("intro_eyelids")
	progression.finish_intro()
	start_game()
	grace = 999
	player.position = Vector3(-19.8,0,-14)
	player.camera.look_at(Vector3(-19.8,2,-16.84))
	await snapshot("window_night")
	player.position = Vector3(-19,0,-5)
	player.camera.look_at(Vector3(15,1.5,-5))
	player.lamp.visible = false
	await snapshot("corridor_off")
	player.lamp.visible = true
	await snapshot("corridor_on")
	player.camera.look_at(Vector3(-16,1.6,-3.1))
	await snapshot("flashlight_wall")
	progression.evidence.inspect("preparation")
	await snapshot("evidence_preparation")
	progression.evidence.inspect("original")
	await snapshot("evidence_original")
	progression.evidence.inspect("class_photo")
	await snapshot("evidence_class")
	progression.evidence.inspect("display")
	await snapshot("evidence_display")
	progression.evidence.reverse = true
	progression.evidence.show_entry()
	await snapshot("evidence_reverse")
	progression.evidence.show_journal()
	await snapshot("journal")
	resume_game()
	player.position = Vector3(56,0,-12.4)
	player.camera.look_at(Vector3(56,1.5,-15.3))
	await snapshot("festival_puzzle")
	player.position = Vector3(16,0,12.2)
	player.camera.look_at(Vector3(16,1.3,15.2))
	await snapshot("av_room")
	progression.story_puzzles.interact({"type":"shelf"})
	progression.story_puzzles.interact({"type":"shelf"})
	await get_tree().create_timer(1.4).timeout
	player.position = Vector3(80.2,0,12.2)
	player.camera.look_at(Vector3(81.2,.7,14.4))
	await snapshot("storeroom")
	player.position = Vector3(40,0,8.7)
	player.camera.look_at(Vector3(40,1.5,15))
	await snapshot("toilets")
	mode = "paused"
	scare_head.visible = true
	scare_head.scare = 0
	scare_head.position = Vector3(0,-40,-2.08)
	scare_camera.current = true
	var fill := OmniLight3D.new()
	fill.position = Vector3(2,-38,-4)
	fill.light_energy = .35
	fill.omni_range = 8
	add_child(fill)
	for pose in [["creature_front_studio",Vector3(0,-40,2)],["creature_profile_studio",Vector3(4,-40,-2.08)],["creature_back_studio",Vector3(0,-40,-6.4)],["creature_threequarter_studio",Vector3(3,-40,1)]]:
		scare_camera.position = pose[1]
		scare_camera.look_at(scare_head.position)
		await snapshot(pose[0])
	fill.queue_free()
	scare_head.hide()
	player.camera.current = true
	mode = "playing"
	capture()
	await get_tree().create_timer(.30).timeout
	await snapshot("capture")
	await get_tree().create_timer(.62).timeout
	await snapshot("capture_mouth")
	await get_tree().create_timer(1.6).timeout
	await snapshot("death")
	start_game()
	collected = 4
	victory()
	await get_tree().create_timer(.8).timeout
	await snapshot("ending_reveal")
	ending.advance()
	await snapshot("ending_1280")
	get_window().size = Vector2i(960,540)
	await get_tree().create_timer(.4).timeout
	await snapshot("ending_960")
	get_window().size = Vector2i(1920,1080)
	await get_tree().create_timer(.4).timeout
	await snapshot("ending_1920")
	get_window().size = Vector2i(1280,720)
	ending.advance()
	ending.advance()
	await snapshot("ending_page2")
	ending.advance()
	ending.advance()
	await get_tree().create_timer(1.3).timeout
	await snapshot("ending_final")
	ending.advance()
	await get_tree().create_timer(1.1).timeout
	ending.credits_y = -400
	ending.credits.position.y = -400
	await snapshot("credits")
	ending.credits_y = -2500
	ending.credits.position.y = -2500
	await snapshot("credits_attribution")
	ending.finish()
	await get_tree().create_timer(1).timeout
	await snapshot("menu_after_ending")
	quit_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_game()

func quit_game() -> void:
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
	get_tree().quit()
