extends Node3D
## All coordinates are metres. Two parallel corridors loop at both ends.
const Creature = preload("res://scripts/creature.gd")
const Player = preload("res://scripts/player.gd")
const ROOMS = ["1年 A組", "2年 B組", "保健室", "職員室", "3年 C組", "音楽室"]
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
var exit_panels: Array[MeshInstance3D] = []
var clock := 0.0
var breath: AudioStreamPlayer3D
var ambient: AudioStreamPlayer
var hum: AudioStreamPlayer
var creak_clock := 11.0
var capture_time := 0.0
var message_time := 0.0
var settings := {"master": .8,"ambience": .65,"sfx": .8,"sensitivity": 2.0,"fullscreen": false,"shake": true}
var options_return := "menu"
var font: SystemFont
var serif: SystemFont
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
	make_materials()
	build_school()
	build_navigation()
	player = Player.new()
	player.game = self
	add_child(player)
	enemy = Creature.new()
	add_child(enemy)
	breath = AudioStreamPlayer3D.new()
	breath.stream = sounds.breath
	breath.bus = "SFX"
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
	show_main_menu()
	if "--verify" in OS.get_cmdline_user_args(): call_deferred("verify_game")
	if "--render-audit" in OS.get_cmdline_user_args(): call_deferred("render_audit")

func setup_input() -> void:
	var bindings := {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"interact":KEY_E,"flashlight":KEY_F,"pause":KEY_ESCAPE}
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
	for bus in ["Ambience","SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	for clip_name in ["ambience","hum","creak","step","hover","press","key","unlock","locked","door","breath","chase","capture"]:
		sounds[clip_name] = load("res://assets/audio/%s.wav" % clip_name)
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
	apply_settings()

func sound(clip_name: String, db := -10.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sounds[clip_name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.bus = "SFX"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func make_materials() -> void:
	for item in [["wall","a1aaa1","plaster"],["floor","adb1a4","floor"],["wood","b7a38b","wood"],["ceiling","93998f","ceiling"],["dark","171e1c",""],["metal","64716b",""],["chalk","203e37",""],["paper","b2b1a0",""],["red","5f2325",""],["glass","263f45",""],["gold","c8a454",""]]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(item[1])
		m.roughness = .87
		if item[2] != "":
			m.albedo_texture = load("res://assets/textures/%s.png" % item[2])
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(.45,.45,.45)
		materials[item[0]] = m
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("bac8b3")
	glow.emission_enabled = true
	glow.emission = Color("9cb7aa")
	glow.emission_energy_multiplier = 1.6
	materials.light = glow

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
		obstacles.append(AABB(pos-size*.5,size))
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
	l.light_energy = energy
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
	e.ambient_light_energy = .26
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
			# Inner corridor display windows and timber framing.
			var iz: float = z-signf(z)*1.86
			box(Vector3(x,1.92,iz),Vector3(3.5,1.15,.08),"glass",false)
			for dx in [-1.8,0.0,1.8]: box(Vector3(x+dx,1.92,iz-signf(z)*.06),Vector3(.065,1.3,.09),"wood",false)
			box(Vector3(x,1.30,iz),Vector3(3.8,.12,.15),"wood",false)
		for x in range(-24,25,4):
			box(Vector3(x,3.27,z),Vector3(.12,.25,4),"dark",false)
			box(Vector3(x,.12,z-signf(z)*1.87),Vector3(3.9,.2,.08),"wood",false)
	for x in [-25.0,25.0]:
		box(Vector3(x,-.15,0),Vector3(4,.3,14),"floor")
		box(Vector3(x,3.5,0),Vector3(4,.2,14),"ceiling")
		box(Vector3(x+signf(x)*2,1.7,0),Vector3(.2,3.4,14),"wall")
		lamp(Vector3(x,2.7,0),.5,Color("8aabbc"))
	# The entrance is a short vestibule facing the west connector.
	box(Vector3(-26.84,1.7,0),Vector3(.1,3.1,3.2),"dark",false)
	for z in [-.78,.78]:
		exit_panels.append(box(Vector3(-26.70,1.5,z),Vector3(.12,2.9,1.48),"metal",false))
		box(Vector3(-26.60,1.95,z),Vector3(.08,1.25,1.18),"glass",false)
	label3("非常口  /  ENTRANCE\n3 KEYS REQUIRED",Vector3(-26.47,3.06,0),PI/2,.007)
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
			for dx in [-4,0,4]:
				box(Vector3(cx+dx,2.03,side*16.84),Vector3(3.4,1.6,.08),"glass",false)
				for off in [-1.7,0.0,1.7]: box(Vector3(cx+dx+off,2.03,side*16.73),Vector3(.07,1.7,.15),"wood",false)
				box(Vector3(cx+dx,1.18,side*16.7),Vector3(3.6,.12,.24),"wood",false)
				lamp(Vector3(cx+dx,2.2,side*15.8),.38,Color("6e95b4"))
			box(Vector3(cx,2.0,side*16.59),Vector3(5.7,1.3,.08),"chalk",false)
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
						desk(Vector3(cx+dx,0,cz+dz))
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

func desk(pos: Vector3) -> void:
	box(pos+Vector3(0,.78,0),Vector3(1.5,.13,.85),"wood")
	for x in [-.61,.61]:
		for z in [-.31,.31]: box(pos+Vector3(x,.37,z),Vector3(.055,.74,.055),"metal",false)
	box(pos+Vector3(0,.42,.86),Vector3(.6,.09,.6),"wood")
	box(pos+Vector3(0,.76,1.12),Vector3(.6,.58,.07),"wood",false)
	for x in [-.25,.25]: box(pos+Vector3(x,.20,.86),Vector3(.04,.4,.45),"metal",false)
	box(pos+Vector3(.25,.86,-.10),Vector3(.32,.025,.4),"paper",false)

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
	doors.append({"node":root,"shape":cs,"origin":pos,"open":false})

func walkable(p: Vector3) -> bool:
	var valid := (absf(p.z-5)<1.5 or absf(p.z+5)<1.5) and absf(p.x)<26
	valid = valid or (absf(p.x-25)<1.3 or absf(p.x+25)<1.3) and absf(p.z)<6.2
	for cx in [-16.0,0.0,16.0]:
		for side in [-1,1]:
			if absf(p.x-cx)<6.3 and absf(p.z-side*12)<4.3: valid = true
			if (absf(p.x-cx-4.5)<1.0 or absf(p.x-cx+4.5)<1.0) and absf(p.z-side*7)<1.7: valid = true
	if not valid: return false
	for a in obstacles:
		if a.position.y > 2.5 or a.end.y < .35: continue
		var grown := a.grow(.92)
		if p.x>grown.position.x and p.x<grown.end.x and p.z>grown.position.z and p.z<grown.end.z: return false
	return true

func build_navigation() -> void:
	for x in range(-52,53):
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
	l.add_theme_font_override("font",font)
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
	b.add_theme_font_override("font",font)
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
	v.add_theme_constant_override("separation",12)
	center.add_child(v)
	var l := text_label(title,48,v)
	l.add_theme_font_override("font",serif)
	l.add_theme_color_override("font_color",Color("8f353a"))
	text_label(subtitle,16,v)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	v.add_child(spacer)
	return v

func show_main_menu() -> void:
	mode = "menu"
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
	var title := text_label("SAKIKO",88,title_box)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_override("font",serif)
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
	var sub := text_label("THE LAST BELL HAS ALREADY RUNG",12,title_box)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sub.modulate.a = .58
	var navbox := VBoxContainer.new()
	navbox.anchor_left = .09
	navbox.anchor_top = .52
	navbox.anchor_right = .36
	navbox.anchor_bottom = .88
	navbox.add_theme_constant_override("separation",9)
	menu.add_child(navbox)
	var first := button("PLAY",start_game,navbox)
	button("OPTIONS",func(): options_return="menu"; show_options(),navbox)
	button("CREATOR",show_credits,navbox)
	button("EXIT",quit_game,navbox)
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
	for row in [["Fullscreen","fullscreen"],["Camera shake","shake"]]:
		var check := CheckButton.new()
		check.text = row[0]
		check.button_pressed = settings[row[1]]
		check.add_theme_font_override("font",font)
		var key: String = row[1]
		check.toggled.connect(func(on): settings[key]=on; save_settings())
		v.add_child(check)
	button("BACK",options_back,v)
	v.get_child(4).grab_focus()

func options_back() -> void:
	if options_return=="pause": show_pause()
	else: show_main_menu()

func show_credits() -> void:
	var v := panel_stack("CREATOR","SAKIKO / さきこ")
	text_label("Your Name",28,v)
	text_label("Original procedural architecture, creature and audio.\nFace references supplied by the creator.\nBuilt with Godot Engine.\n\nCreator name is editable in scripts/game.gd.",16,v)
	button("BACK",show_main_menu,v).grab_focus()

func start_game() -> void:
	mode = "transition"
	curtain.modulate.a = 1
	clear_menu()
	menu.visible = false
	collected = 0
	exit_open = false
	for p in exit_panels: p.material_override = materials.metal
	for k in keys:
		if is_instance_valid(k): k.free()
	keys.clear()
	for d in doors:
		if d.has("tween") and d.tween: d.tween.kill()
		d.open = false
		d.node.position = d.origin
		d.shape.disabled = false
	# One key in each third of the building; two validated room choices per zone.
	for zone in range(3):
		var ri := zone + (3 if randi()%2 else 0)
		var points: Array = room_key_points[ri]
		spawn_key(points[randi()%points.size()])
	player.position = Vector3(-24,0,-1)
	player.rotation = Vector3(0,-PI/2,0)
	player.pitch = 0
	player.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.lamp.visible = true
	player.camera.current = true
	enemy.position = Vector3(22,1.5,5)
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
	ambient.volume_db = -12
	hum.volume_db = -24
	scare_head.visible = false
	film.material.set_shader_parameter("trauma",0)
	hud.visible = true
	prompt.visible = true
	message.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mode = "playing"
	toast("Three keys. One entrance.  |  WASD move · SHIFT run · E interact · F light · ESC pause",12)
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

func interactable() -> Dictionary:
	var eye: Vector3 = player.camera.global_position
	var forward: Vector3 = -player.camera.global_basis.z
	for key in keys:
		if not is_instance_valid(key) or not key.visible: continue
		var diff: Vector3 = key.global_position-eye
		if diff.length()<2.5 and forward.dot(diff.normalized())>.80 and clear_line(eye,key.global_position): return {"type":"key","node":key}
	if player.position.distance_to(exit_point)<3.0: return {"type":"exit"}
	for d in doors:
		var diff: Vector3 = d.origin+Vector3(0,1.3,0)-eye
		if diff.length()<2.8 and forward.dot(diff.normalized())>.35: return {"type":"door","door":d}
	return {}

func interact() -> void:
	var it := interactable()
	if it.is_empty(): return
	match it.type:
		"key":
			it.node.visible = false
			collected += 1
			sound("key",-12)
			toast("A cold brass key.  %d / 3" % collected)
			if collected==3: toast("All three keys. Return to the entrance.",5)
		"door": toggle_door(it.door)
		"exit":
			if collected<3:
				sound("locked",-13)
				toast("Three locks. You still need %d key%s." % [3-collected,"" if collected==2 else "s"])
			elif not exit_open:
				exit_open = true
				sound("unlock",-10)
				for p in exit_panels: p.material_override = materials.light
				toast("The locks give way. Press E to leave.",5)
			else: victory()

func toggle_door(d: Dictionary, force_open := false) -> void:
	if force_open and d.open: return
	# Never close a door through either body.
	if d.open and not force_open:
		if player.position.distance_to(d.origin)<1.5 or Vector2(enemy.position.x-d.origin.x,enemy.position.z-d.origin.z).length()<1.8: return
	d.open = true if force_open else not d.open
	d.shape.set_deferred("disabled",d.open)
	var destination: Vector3 = d.origin+Vector3(2.7 if d.open else 0.0,0,0)
	if d.has("tween") and d.tween: d.tween.kill()
	d.tween = create_tween()
	d.tween.tween_property(d.node,"position",destination,.35)
	sound("door",-24 if force_open else -16)

func clear_line(a: Vector3,b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a,b,1)
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func sees_player() -> bool:
	var diff: Vector3 = player.position+Vector3(0,1.3,0)-enemy.position
	var distance := diff.length()
	if distance>17: return false
	var flat := Vector3(diff.x,0,diff.z).normalized()
	if distance>3 and (-enemy.global_basis.z).dot(flat)<.38: return false
	return clear_line(enemy.position,player.position+Vector3(0,1.3,0))

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

func resume_game() -> void:
	mode = "playing"
	menu.visible = false
	hud.visible = true
	prompt.visible = true
	message.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	breath.stream_paused = false

func victory() -> void:
	mode = "victory"
	breath.stop()
	ambient.volume_db = -23
	hum.volume_db = -40
	var v := panel_stack("YOU ESCAPED","Cold air. A silent street. Do not look back.")
	button("PLAY AGAIN",start_game,v).grab_focus()
	button("MAIN MENU",show_main_menu,v)

func capture() -> void:
	if mode!="playing": return
	mode = "capture"
	capture_time = 0
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
	sound("capture",-3)
	film.material.set_shader_parameter("trauma",.8)

func death_screen() -> void:
	mode = "dead"
	scare_head.visible = false
	var v := panel_stack("SHE FOUND YOU","The last bell rings for you.")
	button("RETRY",start_game,v).grab_focus()
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
			sound("chase",-14)
		state_time = 0
	elif ai_state=="chase" and state_time>1.1:
		ai_state = "investigate"
		state_time = 0
		navigate(last_seen)
	if ai_state=="chase" and repath<=0:
		navigate(last_seen)
		repath = .45
	if ai_state=="roam" and (path.is_empty() or state_time>22):
		var points := [Vector3(-22,1.5,-5),Vector3(22,1.5,-5),Vector3(22,1.5,5),Vector3(-22,1.5,5),Vector3(-20.5,1.5,-12),Vector3(4.5,1.5,12),Vector3(20.5,1.5,-12)]
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
				var speed := 4.25 if ai_state=="chase" else 1.55
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
	if mode=="menu":
		menu_camera.position.z = -5+sin(clock*.09)*.12
		menu_camera.rotation.z = sin(clock*.12)*.003
	if not lights.is_empty():
		lights[2].light_energy = .16 if sin(clock*1.7)>-.95 else .025
	if mode=="playing":
		hud.text = "KEYS  %d / 3" % collected
		var it := interactable()
		prompt.text = ""
		if not it.is_empty():
			match it.type:
				"key": prompt.text = "[ E ]  Take key"
				"door": prompt.text = "[ E ]  Slide door"
				"exit": prompt.text = "[ E ]  Escape" if exit_open else "[ E ]  Unlock entrance"
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
		var lunge := 1-pow(1-clampf(t/.20,0,1),3)
		scare_head.position.z = lerpf(-3.5,-2.05,lunge)
		scare_head.scare = clampf(t*5,0,1)
		scare_head.rotation.z = -.12+sin(t*54)*.018*exp(-t*3)
		if settings.shake:
			scare_camera.rotation.z = sin(t*61)*.026*exp(-t*5)
			scare_camera.position.x = sin(t*83)*.025*exp(-t*6)
		else:
			scare_camera.rotation.z = 0
			scare_camera.position.x = 0
		curtain.modulate.a = clampf((t-1.05)/.22,0,1)
		if t>1.65: death_screen()

func verify_game() -> void:
	# Engine-level integration assertions. No debug shortcuts are enabled in normal play.
	print("VERIFY nav points: ",nav.get_point_count())
	start_game()
	await get_tree().create_timer(.8).timeout
	assert(keys.size()==3)
	for points in room_key_points:
		for p in points:
			var near := nav.get_closest_point(p)
			assert(nav.get_point_position(near).distance_to(p)<4.0,"Room disconnected from navigation")
			var route := nav.get_point_path(nav.get_closest_point(player.position),near)
			assert(route.size()>2,"Unreachable key location")
	print("VERIFY all spawn locations connected")
	var initial: Vector3 = player.position
	Input.action_press("forward")
	await get_tree().create_timer(.5).timeout
	Input.action_release("forward")
	assert(player.position.distance_to(initial)>1.0,"Movement input did not move player")
	var flash := InputEventAction.new()
	flash.action = "flashlight"
	flash.pressed = true
	player._unhandled_input(flash)
	assert(not player.lamp.visible)
	player._unhandled_input(flash)
	assert(player.lamp.visible)
	var old_volume: float = settings.sfx
	settings.sfx = .37
	save_settings()
	settings.sfx = .5
	load_settings()
	assert(is_equal_approx(settings.sfx,.37))
	assert(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")),linear_to_db(.37)))
	settings.sfx = old_volume
	save_settings()
	print("VERIFY movement / flashlight / settings persistence passed")
	for k in keys:
		for offset in [Vector3(0,0,1.6),Vector3(0,0,-1.6),Vector3(1.6,0,0),Vector3(-1.6,0,0)]:
			if not k.visible: break
			player.position = k.position+offset
			player.position.y = 0
			player.velocity = Vector3.ZERO
			player.camera.look_at(k.global_position)
			await get_tree().physics_frame
			interact()
	assert(collected==3,"Collection interaction failed")
	player.position = exit_point
	await get_tree().physics_frame
	interact()
	assert(exit_open)
	interact()
	assert(mode=="victory")
	print("VERIFY collect / unlock / escape passed")
	start_game()
	await get_tree().create_timer(.8).timeout
	assert(collected==0 and not exit_open)
	for d in doors:
		toggle_door(d,true)
	await get_tree().create_timer(.4).timeout
	for d in doors: assert(d.open and d.shape.disabled)
	show_pause()
	assert(mode=="paused")
	resume_game()
	assert(mode=="playing")
	print("VERIFY restart / doors / pause passed")
	player.position = Vector3(0,0,-5)
	enemy.position = Vector3(9,1.5,-5)
	enemy.look_at(Vector3(0,1.5,-5))
	await get_tree().physics_frame
	assert(sees_player(),"Clear corridor detection failed")
	enemy.rotation.y += PI
	assert(not sees_player(),"Field of view failed")
	player.position = Vector3(9,0,5)
	await get_tree().physics_frame
	assert(not clear_line(enemy.position,player.position+Vector3(0,1.3,0)),"Wall did not block sight")
	grace = 0
	ai_state = "chase"
	state_time = 2
	last_seen = Vector3(0,1.5,-5)
	_physics_process(.016)
	assert(ai_state=="investigate")
	path.clear()
	_physics_process(.016)
	assert(ai_state=="search")
	state_time = 5
	_physics_process(.016)
	assert(ai_state=="roam")
	print("VERIFY FOV / sight occlusion / investigate / search / roam passed")
	start_game()
	grace = 999
	player.position = Vector3(-24,0,-5)
	enemy.position = Vector3(4.5,1.5,5)
	ai_state = "investigate"
	state_time = 0
	navigate(Vector3(4.5,1.5,11))
	Engine.time_scale = 5
	await get_tree().create_timer(5).timeout
	Engine.time_scale = 1
	assert(enemy.position.z>8.2,"Enemy failed to navigate and open closed classroom door")
	print("VERIFY physical navigation through closed door passed")
	capture()
	await get_tree().create_timer(1.9).timeout
	assert(mode=="dead")
	print("VERIFY capture / death passed")
	show_main_menu()
	print("VERIFY COMPLETE")
	if "--quit-after-verify" in OS.get_cmdline_user_args(): quit_game()

func snapshot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/artifacts/%s.png" % filename)
	print("RENDER ",filename)

func render_audit() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	await get_tree().create_timer(1).timeout
	await snapshot("menu")
	show_options()
	await snapshot("options")
	start_game()
	await get_tree().create_timer(1).timeout
	player.position = Vector3(-19,0,-5)
	player.camera.look_at(Vector3(12,1.5,-5))
	await snapshot("corridor")
	player.position = Vector3(5,0,8.8)
	player.camera.look_at(Vector3(-1,1.5,15))
	await snapshot("classroom")
	player.position = Vector3(8,0,-5)
	player.camera.look_at(Vector3(15,1.6,-5))
	enemy.position = Vector3(13,1.5,-5)
	enemy.look_at(Vector3(8,1.5,-5))
	mode = "paused"
	await snapshot("creature")
	mode = "playing"
	capture()
	await get_tree().create_timer(.30).timeout
	await snapshot("capture")
	await get_tree().create_timer(1.6).timeout
	await snapshot("death")
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
