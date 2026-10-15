extends Node
var game: Node
var evidence: Node
var targets: Array[Dictionary] = []
var solved := [false,false,false,false]
var held := -1
var slots := [-1,-1,-1]
var pieces: Array[Node3D] = []
var piece_origins: Array[Vector3] = []
var mount_points: Array[Vector3] = []
var display_lid: Node3D
var desk_lid: Node3D
var shelf: Node3D
var shelf_origin := Vector3(78.55,0,12)
var power := false
var played := false
var brake := false
var opened := false
var recording: AudioStreamPlayer3D
var recording_time := -1.0
var captions: Label
var knock_done := false
var tweens: Array[Tween] = []
var evidence_models := {}

func build(g: Node,journal: Node) -> void:
	game = g
	evidence = journal
	# The recognizable crane desk teaches inspection without a code lock.
	document("preparation",Vector3(-18.6,1.35,-15.2))
	game.label3("FESTIVAL PREPARATIONS\nE inspect photograph  |  J journal",Vector3(-18.6,1.9,-15.18),0,.0035)
	var desk_point := Vector3(-19.9,.85,-13.4)
	game.label3("17",desk_point+Vector3(.13,.06,-.18),PI/2,.004)
	var ribbon = game.box(desk_point+Vector3(.26,-.13,.15),Vector3(.035,.3,.008),"paper",false)
	ribbon.rotation.y = PI/2
	var crane := decoration(0)
	crane.position = desk_point+Vector3(0,.07,0)
	crane.scale = Vector3.ONE*.25
	game.world.add_child(crane)
	desk_lid = game.box(desk_point+Vector3(.25,-.13,0),Vector3(.05,.16,.42),"wood",false)
	targets.append({"type":"festival_desk","point":desk_point,"label":"E  -  Open desk 17"})
	# Physical three-piece display arrangement, with a nearby inspectable sketch.
	document("sketch",Vector3(52.8,1.45,-15.4))
	game.box(Vector3(56,1.30,-15.7),Vector3(4.4,2.6,.18),"wood")
	game.box(Vector3(56,.78,-15.12),Vector3(4.4,.10,1.0),"wood")
	display_lid = game.box(Vector3(56,.55,-14.85),Vector3(1.4,.32,.06),"metal",false)
	for i in range(3):
		var point := Vector3(54.7+i*1.3,1.75,-15.45)
		mount_points.append(point)
		game.label3(str(i+1),point+Vector3(0,.52,.03),0,.006)
		targets.append({"type":"mount","index":i,"point":point,"label":"E  -  Place / take display piece %d" % (i+1)})
		var part := decoration(i)
		var origin := Vector3(54.7+posmod(i+1,3)*1.3,.93,-14.8)
		part.position = origin
		piece_origins.append(origin)
		pieces.append(part)
		game.world.add_child(part)
		targets.append({"type":"piece","index":i,"point":origin,"label":"E  -  Take "+piece_name(i)})
	game.label3("MOUNT ALL THREE PIECES\nShallow drawer below",Vector3(56,2.85,-15.4),0,.0035)
	# AV power and replayable tape; the shelf label remains readable without audio.
	game.box(Vector3(16,.85,15.2),Vector3(3.6,.1,.8),"wood")
	game.box(Vector3(16,1.02,15.2),Vector3(.65,.24,.38),"dark",false)
	game.label3("FESTIVAL TAPE\nE PLAY / REPLAY",Vector3(16,1.42,15.12),PI,.0035)
	game.box(Vector3(12,1.5,15.3),Vector3(.4,.5,.08),"metal",false)
	game.label3("LOCAL AV POWER\nE  ON",Vector3(12,1.95,15.23),PI,.0033)
	targets.append({"type":"av_power","point":Vector3(12,1.5,15.2),"label":"E  -  Restore local AV power"})
	targets.append({"type":"recording","point":Vector3(16,1.15,15.1),"label":"E  -  Play festival recording"})
	game.box(Vector3(21,1.1,15.5),Vector3(1.4,2.2,.65),"wood")
	game.label3("B2\nEQUIPMENT CASE",Vector3(21,1.8,15.1),PI,.005)
	targets.append({"type":"case","point":Vector3(21,1.2,15.1),"label":"E  -  Open case B2"})
	recording = AudioStreamPlayer3D.new()
	recording.stream = load("res://assets/audio/festival_recording.wav")
	recording.position = Vector3(16,1,15)
	recording.bus = "SFX"
	recording.unit_size = 4
	recording.max_distance = 16
	recording.volume_db = -8
	game.world.add_child(recording)
	# Concealed storeroom: short shelf brake interaction, then slide it aside.
	document("plan",Vector3(72,1.5,-15.35))
	game.label3("MAINTENANCE / SCENERY STORE\nService plan",Vector3(72,2.25,-15.3),0,.004)
	shelf = Node3D.new()
	shelf.position = shelf_origin
	game.world.add_child(shelf)
	for z in [-1.4,1.4]: game.box(Vector3(0,1.25,z),Vector3(.75,2.5,.08),"metal",true,shelf)
	for y in [.18,.9,1.6,2.3]:
		game.box(Vector3(0,y,0),Vector3(.75,.07,2.9),"wood",true,shelf)
		for z in [-.9,0,.9]: game.box(Vector3(0,y+.18,z),Vector3(.55,.32,.65),"paper",false,shelf)
	targets.append({"type":"shelf","point":Vector3(78.2,1.0,12),"label":"E  -  Release archive shelf brake"})
	game.label3("FLOOR BRAKE ↓",Vector3(78.05,.55,12),-PI/2,.0035)
	var prop = preload("res://scripts/creature.gd").new()
	prop.position = Vector3(81.4,.65,14.4)
	prop.scale = Vector3.ONE*.31
	prop.rotation = Vector3(.2,-PI/2,.12)
	prop.set_process(false)
	prop.collision_layer = 0
	prop.collision_mask = 0
	game.world.add_child(prop)
	game.box(Vector3(81.1,.35,11),Vector3(.46,.6,.25),"dark",false)
	game.box(Vector3(81.1,.63,11),Vector3(.35,.035,.16),"wood",false)
	for i in range(9):
		var mark = game.box(Vector3(79.12,.24+i*.045,10.55),Vector3(.012,.008,.24+fmod(i*.13,.25)),"dark",false)
		mark.rotation.x = .07*i
	document("letter",Vector3(81.1,.95,11.05))
	document("belongings",Vector3(81.4,.95,14.8))
	document("maintenance",Vector3(81.6,1.4,15.6))
	# Optional fragments on routes, not exposition walls.
	document("notice",Vector3(-16,1.5,15.2))
	document("inventory",Vector3(40,1.4,-15.2))
	document("destroy",Vector3(56,1.4,15.2))
	document("class_photo",Vector3(2,1.5,15.2))
	document("display",Vector3(55.1,1.1,-14.6))

func piece_name(index: int) -> String:
	return ["red fan","white lantern","blue star"][index]

func decoration(index: int) -> Node3D:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = [Color("70353b"),Color("c3bca4"),Color("364d69")][index]
	mat.roughness = 1
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if index==1:
		var sphere := SphereMesh.new()
		sphere.radius = .22
		sphere.height = .5
		mesh.mesh = sphere
	else:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var points := 10 if index==2 else 14
		for i in range(points):
			var a: float = float(i)/points*TAU if index==2 else float(i)/points*PI
			var b: float = float(i+1)/points*TAU if index==2 else float(i+1)/points*PI
			var r1 := .30 if index==0 or i%2==0 else .13
			var r2 := .30 if index==0 or (i+1)%2==0 else .13
			for point in [Vector3.ZERO,Vector3(cos(a)*r1,sin(a)*r1,0),Vector3(cos(b)*r2,sin(b)*r2,0)]: st.add_vertex(point)
		st.generate_normals()
		mesh.mesh = st.commit()
	mesh.material_override = mat
	root.add_child(mesh)
	return root

func document(id: String,point: Vector3) -> void:
	var root := Node3D.new()
	root.position = point
	game.world.add_child(root)
	evidence_models[id] = root
	var paper = game.box(Vector3.ZERO,Vector3(.48,.34,.012),"paper",false,root)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/story/documents/%s.svg" % id)
	mat.roughness = 1
	paper.material_override = mat
	var label: Label3D = game.label3("E  INSPECT",point+Vector3(0,.27,-.015 if point.z>0 else .015),PI if point.z>0 else 0,.0025)
	label.reparent(root,true)
	targets.append({"type":"evidence","id":id,"point":point,"label":"E  -  Inspect "+str(evidence.entries[id].title)})

func reset() -> void:
	for tween in tweens:
		if tween and tween.is_valid(): tween.kill()
	tweens.clear()
	solved = [false,false,false,false]
	held = -1
	slots = [-1,-1,-1]
	for i in range(3): pieces[i].position = piece_origins[i]; pieces[i].show()
	desk_lid.position = Vector3(-19.65,.72,-13.4)
	display_lid.position = Vector3(56,.55,-14.85)
	shelf.position = shelf_origin
	power = false
	played = false
	brake = false
	opened = false
	knock_done = false
	recording.stop()
	recording_time = -1
	evidence.collected.clear()
	evidence_models.display.hide()
	for point in [Vector3(-19.9,.94,-13.4),Vector3(56,.65,-14.32),Vector3(21,1.2,15.0),Vector3(81.0,.45,15.3)]:
		game.spawn_key(point)
		game.keys.back().visible = false
		game.keys.back().set_meta("collected",false)

func targeted() -> Dictionary:
	for item in targets:
		if item.type=="evidence" and not evidence_models[item.id].visible: continue
		if item.type=="festival_desk" and solved[0]: continue
		if item.type=="case" and solved[2]: continue
		if item.type=="shelf" and opened: continue
		if item.type=="piece" and (held==item.index or slots.has(item.index)): continue
		if item.type in ["piece","mount"] and solved[1]: continue
		var point: Vector3 = item.point
		if item.type=="piece": point = pieces[item.index].global_position
		if game.target_visible(point,2.5,.98 if item.type in ["piece","mount"] else .94): return item
	return {}

func solve(index: int) -> void:
	if solved[index]: return
	solved[index] = true
	game.keys[index].show()
	game.sound("unlock",-17)
	game.toast("An entrance key.  |  E collect",4)

func interact(item: Dictionary) -> void:
	match item.type:
		"evidence": evidence.inspect(item.id)
		"festival_desk":
			solve(0)
			var tw := create_tween()
			tw.tween_property(desk_lid,"position:x",-19.35,.45)
			tweens.append(tw)
			for id in ["folded","original"]:
				if not evidence.collected.has(id): evidence.collected.append(id)
			evidence.inspect("folded")
		"piece":
			if held>=0: return
			held = item.index
			pieces[held].hide()
			game.sound("key",-24)
		"mount":
			var slot: int = item.index
			if held<0:
				held = slots[slot]
				if held>=0: pieces[held].hide(); slots[slot] = -1
			else:
				var previous: int = slots[slot]
				slots[slot] = held
				pieces[held].position = mount_points[slot]
				pieces[held].show()
				held = previous
				if held>=0: pieces[held].hide()
			game.sound("latch",-21)
			if slots==[0,1,2]:
				solve(1)
				var tw := create_tween()
				tw.tween_property(display_lid,"position:z",-14.45,.5)
				tweens.append(tw)
				evidence_models.display.show()
		"av_power": power = true; game.sound("latch",-20); game.toast("AV power restored. The tape deck is ready.")
		"recording":
			if not power: game.toast("No power. The labeled local switch is beside the deck."); return
			played = true
			recording.play()
			recording_time = 0
			evidence.inspect("recording")
		"case":
			if not power or not played: game.toast("The case label reads B2. The festival tape is beside the local power switch."); return
			solve(2)
			evidence.inspect("account")
		"shelf":
			if not brake:
				brake = true
				game.sound("latch",-18)
				game.toast("The floor brake releases. E  -  slide shelving aside.",4)
			else:
				opened = true
				var tw := create_tween()
				tw.tween_property(shelf,"position:z",15.3,1.2)
				tweens.append(tw)
				game.sound("door",-20,.7)
				solve(3)

func _process(delta: float) -> void:
	if not game or not game.player: return
	if not captions:
		captions = game.text_label("",18)
		captions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		captions.position = Vector2(-430,-120)
		captions.size = Vector2(860,70)
		captions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if recording_time>=0:
		recording_time += delta
		if recording_time>20: recording_time = -1
		captions.text = ["Student: Does it hang straight?","Student: Put the spare equipment case on shelf B two.","[Laughter. Three quiet knocks.]","Student: Is that part of the attraction?","Student: Leave it. We still have cleanup."][mini(4,int(recording_time/4))] if recording_time>=0 else ""
	captions.visible = recording_time>=0 and game.mode in ["playing","document"]
	if not knock_done and game.mode=="playing" and game.player.position.distance_to(Vector3(77,0,12))<5:
		knock_done = true
		game.progression.giggle.stop()
		game.progression.positional_voice(Vector3(80,1,12),game.sounds.quiet_knocks,-16,3)


