extends Node
## Retired four-key implementation, retained recoverably. Runtime uses story_flow.gd.
var game: Node
var evidence: Node
var targets: Array[Dictionary]=[]
var solved: Array[bool]=[false,false,false,false]
var containers: Dictionary={}
var evidence_models: Dictionary={}
var tweens: Array[Tween]=[]
var utility_inventory: Dictionary={}
var service_taken:=false
var rehearsal_taken:=false
var power:=false
var played:=false
var brake:=false
var opened:=false
var shelf_moving:=false
var shelf: Node3D
var release_lever: MeshInstance3D
var power_lever: MeshInstance3D
var shelf_origin:=Vector3(44.5,0,33.4)
var recording: AudioStreamPlayer3D
var captions: Label
var recording_time:=-1.0
const KEY_CONTAINERS: Array[String]=["staff_cabinet","archive_12","av_case","bag"]
const KEY_POINTS: Array[Vector3]=[Vector3(31.60,1.75,2.0),Vector3(13.80,5.078,35.20),Vector3(46.0,.936,1.3),Vector3(45.44,4.726,34.4)]
var service_key: Node3D
var rehearsal_key: Node3D
var utility_nodes: Dictionary={}
var utility_taken: Dictionary={}
var inserted:=false
var tape_done:=false

func build(g: Node,journal: Node) -> void:
	game=g
	evidence=journal
	make_container("service_drawer",Vector3(26.2,.68,5.7),Vector3(.8,.22,.55),"drawer",PI)
	service_key=game.make_physical_key(Vector3(26.2,.632,5.7))
	service_key.scale=Vector3.ONE*.35
	service_key.rotation.x=-PI/2
	service_key.reparent(containers.service_drawer.tray,true)
	containers.service_drawer.contents.append(service_key)
	document("handover",Vector3(26.2,.847,5.7),true)
	make_container("staff_cabinet",Vector3(31.70,1.65,2),Vector3(.9,1,.4),"cabinet",PI/2)
	game.box(Vector3(31.76,1.79,2.0),Vector3(.04,.09,.035),"metal",false)
	document("envelope",Vector3(31.64,1.52,2.0),false,-PI/2)
	bind("envelope","staff_cabinet")
	utility("upper",Vector3(31.65,1.215,1.8),"staff_cabinet")
	utility("festival",Vector3(31.65,1.215,2.2),"staff_cabinet")
	document("plan",Vector3(26.2,.847,2.5),true)
	# Art -> matching exhibit F-12 -> indexed archive compartment B3-12.
	document("sketch",Vector3(29.6,.847,34.7),true)
	for i in range(3):
		var id: String="art_"+str(i)
		make_container(id,Vector3(25.5+i*1.5,.95,35.3),Vector3(1.35,.25,.65),"drawer")
		tag(["PAPER","F-12 MATERIAL","TOOLS"][i],id,.001)
	make_container("packing_envelope",Vector3(27,.905,35.26),Vector3(.58,.05,.40),"envelope")
	containers.packing_envelope.root.reparent(containers.art_1.tray,true)
	containers.art_1.contents.append(containers.packing_envelope.root)
	document("original",Vector3(27,.922,35.25),true)
	bind("original","packing_envelope",.65)
	utility("archive",Vector3(27.16,.924,35.29),"packing_envelope")
	document("display",Vector3(32,6.05,35.60),false,PI)
	game.box(Vector3(32,6.05,35.65),Vector3(1.5,1.5,.04),"wood",false)
	evidence_models.display.scale=Vector3.ONE*3.5
	document("exhibit",Vector3(33.1,5.65,35.60),false,PI)
	utility("compartment",Vector3(32.35,5.55,35.64),"")
	utility_nodes.compartment.reparent(evidence_models.display,true)
	game.box(Vector3(32.35,5.55,35.67),Vector3(.20,.25,.012),"paper",false)
	for i in range(11,14):
		var id: String="archive_"+str(i)
		make_container(id,Vector3(12.8+(i-11)*1.5,5.15,35.3),Vector3(1.35,.28,.7),"drawer")
		tag("B3-"+str(i),id,.0012)
	document("loan",Vector3(13.85,5.068,35.45),true)
	bind("loan","archive_12",.55)
	document("archive_record",Vector3(14.43,5.068,35.45),true)
	bind("archive_record","archive_12",.55)
	utility("media",Vector3(14.37,5.08,35.20),"archive_12")
	utility("tape",Vector3(14.10,5.08,35.20),"archive_12")
	document("program",Vector3(14.68,5.069,35.22),true)
	bind("program","archive_12",.55)
	# Physical AV case; power is local to the upstairs playback deck only.
	make_container("av_case",Vector3(46.2,1.05,1.3),Vector3(.95,.36,.7),"case",PI)
	tag("AV / B2","av_case",.001)
	document("account",Vector3(14.14,5.07,35.45),true)
	bind("account","archive_12",.55)
	utility("rehearsal_U08",Vector3(46.50,.937,1.52),"av_case")
	rehearsal_key=utility_nodes.rehearsal_U08
	document("case_reference",Vector3(46.35,.926,1.25),true)
	bind("case_reference","av_case",.65)
	game.box(Vector3(41.65,5.20,1.3),Vector3(.65,.25,.38),"dark",false)
	targets.append({"type":"recording","point":Vector3(41.65,5.33,1.51),"label":"E  -  Play festival recording"})
	game.box(Vector3(40.16,5.55,3.0),Vector3(.12,.55,.4),"metal",true)
	power_lever=game.box(Vector3(40.24,5.55,3.0),Vector3(.05,.14,.07),"red",false)
	targets.append({"type":"av_power","point":Vector3(40.26,5.55,3.0),"label":"E  -  Reset local playback breaker"})
	document("tape_index",Vector3(47.84,5.65,5.8),false,-PI/2)
	recording=AudioStreamPlayer3D.new()
	recording.stream=load("res://assets/audio/festival_nonverbal.wav")
	recording.finished.connect(recording_finished)
	recording.position=Vector3(41.65,5.3,1.3)
	recording.bus="WorldSFX"
	recording.max_distance=15
	recording.unit_size=4
	recording.volume_db=-4
	game.world.add_child(recording)
	build_shelf()
	document("maintenance",Vector3(46.3,1.45,35.83),false,PI)
	game.box(Vector3(46.3,1.45,35.87),Vector3(.39,.55,.025),"wood",false)
	make_container("bag",Vector3(45.6,4.82,34.4),Vector3(.65,.32,.43),"bag")
	for item in [["letter",Vector3(45.7,4.716,34.45)],["folded",Vector3(45.5,4.719,34.5)]]:
		document(item[0],item[1],true)
		bind(item[0],"bag",.60)
	var prop:=Node3D.new()
	prop.name="DiscardedCardboardMount"
	prop.position=Vector3(42.1,4.2,34.7)
	prop.rotation=Vector3(.16,-PI/2,0)
	game.world.add_child(prop)
	var outline:=PackedVector2Array([Vector2(-.40,.02),Vector2(.40,.02),Vector2(.43,.72),Vector2(.21,1.11),Vector2(.04,1.03),Vector2(-.14,1.13),Vector2(-.43,.74)])
	var triangles:=Geometry2D.triangulate_polygon(outline)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in triangles: surface.add_vertex(Vector3(outline[index].x,outline[index].y,0))
	surface.generate_normals()
	var backing:=MeshInstance3D.new();backing.mesh=surface.commit()
	var cardboard:=StandardMaterial3D.new();cardboard.albedo_color=Color("756d56");cardboard.roughness=1;cardboard.metallic_specular=0;cardboard.cull_mode=BaseMaterial3D.CULL_DISABLED
	backing.material_override=cardboard;prop.add_child(backing)
	for y in [.30,.76]: game.props.part(Vector3(0,y,.012),Vector3(.74,.055,.025),"wood",prop)
	for x in [-.27,.11,.29]:
		game.props.part(Vector3(x,.18,-.008),Vector3(.026,.33,.006),"dark",prop)
		game.props.part(Vector3(x,.36,-.011),Vector3(.055,.07,.008),"paper",prop)
	for i in range(8): game.box(Vector3(44.4+i*.04,4.50+i*.045,28.13),Vector3(.23,.008,.012),"dark",false)
	# Optional records occupy purposeful supporting rooms; none grants permission.
	for item in [["class_photo",Vector3(16.10,5.95,4.9),PI/2],["notice",Vector3(22.2,1.7,35.88),PI],["inventory",Vector3(38,.847,2.5),0.0],["destroy",Vector3(22,5.047,33.2),0.0],["belongings",Vector3(42.4,5.107,35.3),0.0]]:
		document(item[0],item[1],item[0] in ["inventory","destroy","belongings"],item[2])
	var photo_back:=Node3D.new();game.world.add_child(photo_back)
	photo_back.position=Vector3(16.085,5.95,4.9);photo_back.rotation.y=PI/2
	game.box(Vector3.ZERO,Vector3(.52,.36,.02),"wood",false,photo_back)

func tag(value: String,id: String,pixels: float) -> void:
	var c: Dictionary=containers[id]
	var local: Vector3=Vector3(0,0,-.375 if c.kind=="case" else -.37)
	var text: Label3D=game.label3(value,c.root.to_global(local),c.root.rotation.y+PI,pixels,Color("aaa38c"))
	text.reparent(c.hinge,true)

func document(id: String,point: Vector3,flat:=false,yaw:=0.0) -> void:
	var model: Node3D=evidence.make_document(id)
	model.position=point
	model.rotation=Vector3(-PI/2,0,0) if flat else Vector3(0,yaw,0)
	game.world.add_child(model)
	evidence_models[id]=model
	targets.append({"type":"evidence","id":id,"point":point,"label":"E  -  Inspect "+str(evidence.entries[id].title)})

func bind(id: String,container: String,scale:=1.0) -> void:
	evidence_models[id].scale=Vector3.ONE*scale
	evidence_models[id].reparent(containers[container].tray,true)
	containers[container].contents.append(evidence_models[id])

func build_shelf() -> void:
	shelf=Node3D.new()
	shelf.name="G09_MovingInventoryShelf"
	shelf.position=shelf_origin
	shelf.set_meta("dynamic_nav",true)
	shelf.add_to_group("moving_obstruction")
	game.world.add_child(shelf)
	for x in [-2.35,2.35]: game.box(Vector3(x,1.15,0),Vector3(.05,2.3,.65),"metal",true,shelf)
	for y in [.18,.85,1.5,2.2]:
		game.box(Vector3(0,y,0),Vector3(4.7,.05,.65),"wood",true,shelf)
		for x in [-1.7,-.6,.6,1.7]:
			var carton: Node3D=game.finishing.model("archive_box",Vector3(x,y+.025,0),0,shelf)
			carton.scale=Vector3(1.8,1,1.45)
	for x in [-2.15,2.15]:
		for z in [-.25,.25]:
			var wheel: MeshInstance3D=game.props.cylinder(Vector3(x,.08,z),.07,.045,"dark",shelf)
			wheel.rotation.x=PI/2
			game.box(Vector3(x,.14,z),Vector3(.06,.08,.05),"metal",false,shelf)
	release_lever=game.box(Vector3(0,.8,-.37),Vector3(.18,.05,.06),"metal",false,shelf)
	for z in [33.05,33.75]: game.box(Vector3(43.5,.025,z),Vector3(6.8,.035,.045),"metal",false)
	targets.append({"type":"shelf","point":Vector3(44.5,.8,32.99),"label":"E  -  Release shelving brake"})

func make_container(id: String,point: Vector3,dimensions: Vector3,kind: String,yaw:=0.0) -> void:
	var root:=Node3D.new()
	root.set_meta("placement_category","PUZZLE_OBJECT")
	root.position=point
	game.world.add_child(root)
	root.rotation.y=yaw
	var skin: String="filecabinet" if id.begins_with("archive_") else ("paper" if kind=="envelope" else ("dark" if kind=="bag" else ("metal" if kind=="case" else "wood")))
	for x in [-1,1]: game.box(Vector3(x*(dimensions.x-.035)/2,0,0),Vector3(.035,dimensions.y,dimensions.z),skin,true,root)
	game.box(Vector3(0,-(dimensions.y-.035)/2,0),Vector3(dimensions.x,.035,dimensions.z),skin,true,root)
	if kind in ["drawer","cabinet"]: game.box(Vector3(0,(dimensions.y-.035)/2,0),Vector3(dimensions.x,.035,dimensions.z),skin,true,root)
	game.box(Vector3(0,0,dimensions.z/2),Vector3(dimensions.x,dimensions.y,.035),skin,true,root)
	if kind!="cabinet" and id not in ["service_drawer","bag","packing_envelope"]:
		var floor_y: float=4.2 if point.y>4.2 else 0.0
		var support_y: float=-dimensions.y/2-.045
		game.box(Vector3(0,support_y,0),Vector3(dimensions.x+.10,.07,dimensions.z+.10),skin,true,root)
		var leg_height: float=point.y+support_y-.035-floor_y
		if id.begins_with("archive_"):
			game.box(Vector3(0,-point.y+floor_y+leg_height/2,0),Vector3(dimensions.x-.06,leg_height,dimensions.z-.06),skin,true,root)
			for level in [0,1]:
				var drawer_y: float=-point.y+floor_y+.19+level*.31
				game.box(Vector3(0,drawer_y,-dimensions.z/2-.014),Vector3(dimensions.x-.13,.27,.022),skin,false,root)
				game.box(Vector3(0,drawer_y,-dimensions.z/2-.04),Vector3(.15,.025,.025),"metal",false,root)
		else:
			for x in [-1,1]:
				for z in [-1,1]: game.box(Vector3(x*(dimensions.x-.10)/2,-point.y+floor_y+leg_height/2,z*(dimensions.z-.10)/2),Vector3(.045,leg_height,.045),"metal",true,root)
	var hinge:=Node3D.new()
	hinge.position=Vector3(-dimensions.x/2,0,-dimensions.z/2) if kind in ["drawer","cabinet"] else Vector3(0,dimensions.y/2,dimensions.z/2)
	root.add_child(hinge)
	var door: MeshInstance3D
	if kind in ["case","bag","envelope"]:
		game.box(Vector3(0,0,-dimensions.z/2),Vector3(dimensions.x,.04,dimensions.z),skin,true,hinge)
		door=game.box(Vector3(0,-dimensions.y/2,-dimensions.z),Vector3(dimensions.x,dimensions.y,.04),skin,true,hinge)
	else:
		door=game.box(Vector3(dimensions.x/2,0,0),Vector3(dimensions.x,dimensions.y,.04),skin,true,hinge)
		game.box(Vector3(dimensions.x*.8,0,-.035),Vector3(.10,.035,.025),"metal",false,hinge)
	var tray: MeshInstance3D=game.box(Vector3(0,-dimensions.y/2+(.008 if kind=="envelope" else .04),0),Vector3(dimensions.x-.08,.003 if kind=="envelope" else .025,dimensions.z-.08),skin,false,root)
	if kind=="drawer":
		tray.reparent(hinge,true)
		for x in [-1,1]: game.box(Vector3(x*(dimensions.x-.12)/2,.065,0),Vector3(.025,.13,dimensions.z-.08),skin,false,tray)
	if kind=="bag":
		for x in [-.20,.20]:
			game.box(Vector3(x,0,-dimensions.z/2-.024),Vector3(.045,dimensions.y*.75,.018),"wood",false,root)
			game.box(Vector3(x,.065,-dimensions.z/2),Vector3(.025,.13,.035),"dark",false,hinge)
		game.box(Vector3(0,.13,-dimensions.z/2),Vector3(.42,.035,.035),"dark",false,hinge)
	containers[id]={"root":root,"hinge":hinge,"origin":hinge.position,"door":door,"open":false,"busy":false,"contents":[],"kind":kind,"tray":tray,"dimensions":dimensions}
	targets.append({"type":"container","id":id,"point":root.to_global(Vector3(0,0,-dimensions.z/2-.05)),"label":"E  -  Open "+{"service_drawer":"office drawer","staff_cabinet":"key cabinet","av_case":"equipment case","bag":"old student bag","packing_envelope":"F-12 packing envelope"}.get(id,"storage drawer")})

func reset() -> void:
	for tw in tweens:
		if tw and tw.is_valid(): tw.kill()
	tweens.clear()
	solved=[false,false,false,false]
	utility_inventory.clear()
	utility_taken.clear()
	inserted=false
	tape_done=false
	for node in utility_nodes.values(): node.show()
	service_taken=false
	rehearsal_taken=false
	power=false
	played=false
	brake=false
	opened=false
	shelf_moving=false
	for id in containers:
		var c: Dictionary=containers[id]
		c.open=false
		c.busy=false
		c.hinge.rotation=Vector3.ZERO
		c.hinge.position=c.origin
		for collision in c.hinge.find_children("*","CollisionShape3D",true,false): collision.set_deferred("disabled",false)
	for id in evidence_models: evidence_models[id].show()
	for c in containers.values():
		for node in c.contents: node.hide()
	evidence_models.maintenance.hide()
	utility_nodes.compartment.show()
	shelf.position=shelf_origin
	release_lever.rotation=Vector3.ZERO
	power_lever.rotation=Vector3(0,0,.5)
	recording.stop()
	recording_time=-1
	evidence.collected.clear()
	game.layout.rehearsal_door.locked=true
	for i in range(4):
		game.spawn_key(KEY_POINTS[i])
		var key: Node3D=game.keys.back()
		key.reparent(containers[KEY_CONTAINERS[i]].tray,true)
		key.scale=Vector3.ONE*.5
		key.global_rotation=Vector3(0,0,-PI/2) if i==0 else Vector3(-PI/2,0,.2)
		key.hide()
		key.set_meta("collected",false)
		key.set_meta("lock_index",i)
		game.box(Vector3(-.07,0,.005),Vector3(.09,.055,.01),"paper",false,key)
		var label: Label3D=game.label3(["I","II","III","IV"][i],Vector3.ZERO,0,.0008,Color("4b3b32"))
		label.reparent(key,false)
		label.position=Vector3(-.07,0,.011)

func available_targets() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for source in targets:
		var item: Dictionary=source.duplicate()
		if item.type=="evidence":
			if not evidence_models[item.id].is_visible_in_tree(): continue
			item.point=evidence_models[item.id].global_position
		if item.type=="container":
			if item.id=="packing_envelope" and not containers.art_1.open: continue
			var c: Dictionary=containers[item.id]
			if c.open or c.busy or not c.root.is_visible_in_tree(): continue
			item.point=c.root.to_global(Vector3(0,c.dimensions.y/2+.02,0) if c.kind=="envelope" else Vector3(0,0,-c.dimensions.z/2-.05))
		if item.type=="shelf":
			if opened or shelf_moving: continue
			if brake: item.label="E  -  Slide shelf along track"
		if item.type=="av_power" and power: continue
		result.append(item)
	if containers.service_drawer.open and not service_taken: result.append({"type":"service_key","point":service_key.global_position,"label":"E  -  Take cabinet service key"})
	for id in utility_nodes:
		if id=="compartment" or utility_taken.get(id,false) or not utility_nodes[id].is_visible_in_tree(): continue
		result.append({"type":"utility","id":id,"point":utility_nodes[id].global_position,"label":"E  -  Take "+utility_label(id)})

	return result

func targeted() -> Dictionary:
	for item in available_targets():
		if game.target_visible(item.point,1.65,.96): return item
	return {}

func solve(index: int) -> void:
	if solved[index]: return
	solved[index]=true
	game.keys[index].show()

func open_container(id: String) -> void:
	var c: Dictionary=containers[id]
	if c.open or c.busy: return
	c.busy=true
	game.world_sound({"drawer":"drawer_slide","cabinet":"cabinet_hinge","bag":"bag_fabric","envelope":"paper_flip","case":"case_latch"}.get(c.kind,"latch"),c.root.global_position,-12,.7)
	var tw:=create_tween()
	tweens.append(tw)
	if c.kind=="drawer": tw.tween_property(c.hinge,"position:z",c.origin.z-.6,.65)
	elif c.kind=="cabinet": tw.tween_property(c.hinge,"rotation:y",PI*.63,.7)
	else: tw.tween_property(c.hinge,"rotation:x",PI*.65,.7)
	tw.tween_callback(func():
		c.busy=false
		c.open=true
		for node in c.contents: node.show()
		var index: int=KEY_CONTAINERS.find(id)
		if index>=0: solve(index))

func submit_combination(code: String) -> bool:
	if code!="1015": return false
	game.resume_game()
	open_container("av_case")
	return true

func combination() -> void:
	game.mode="puzzle"
	var stack: VBoxContainer=game.panel_stack("AV CASE B2","")
	var row:=HBoxContainer.new()
	stack.add_child(row)
	var digits: Array[SpinBox]=[]
	for i in range(4):
		var wheel:=SpinBox.new()
		wheel.min_value=0
		wheel.max_value=9
		wheel.step=1
		wheel.value_changed.connect(func(_value): game.world_sound("code_tick",containers.av_case.root.global_position,-30))
		wheel.custom_minimum_size=Vector2(100,50)
		wheel.add_theme_font_override("font",game.serif)
		wheel.add_theme_font_size_override("font_size",32)
		wheel.get_line_edit().alignment=HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(wheel)
		digits.append(wheel)
	var feedback: Label=game.text_label("",18,stack)
	game.button("RELEASE LATCH",func():
		var code: String=""
		for wheel in digits: code+=str(int(wheel.value))
		if not submit_combination(code): feedback.text="The latch holds."; game.sound("locked",-22),stack)
	game.button("CLOSE",game.resume_game,stack)
	digits[0].get_line_edit().grab_focus.call_deferred()

func interact(item: Dictionary) -> void:
	if game.mode!="playing": return
	match item.type:
		"evidence": evidence.inspect(item.id)
		"service_key":
			if service_taken: return
			service_taken=true
			utility_inventory["service"]=true
			service_key.hide()
		"utility": collect_utility(item.id)
		"container":
			if item.id=="staff_cabinet" and not service_taken: game.toast("Locked.",2); return
			if item.id=="archive_12" and not utility_inventory.has("compartment"): game.toast("Locked.",2); game.sound("locked",-22); return
			if item.id=="av_case": combination()
			else: open_container(item.id)
		"av_power": power=true; power_lever.rotation.z=0; game.sound("latch",-20)
		"recording":
			if not utility_inventory.has("tape"): game.toast("Empty.",2); return
			game.player_voice.playback_known=true
			game.player_voice.flush()
			if not inserted:
				inserted=true
				game.sound("latch",-22)
				return
			if not power: power=true; power_lever.rotation.z=0
			if recording.playing: return
			played=true
			recording.play()
			recording_time=0
			if not tape_done: game.progression.prepare_tape_encounter()
			evidence.inspect("recording")
		"shelf":
			if not brake: brake=true; release_lever.rotation.z=.6; game.sound("latch",-22)
			else: move_shelf()

func move_shelf() -> void:
	if shelf_moving or opened: return
	var point: Vector3=game.player.position
	if point.x>40.4 and point.x<47 and point.z>32.9 and point.z<33.9: game.toast("Step clear of the shelf track.",2); return
	shelf_moving=true
	game.path.clear()
	game.grace=maxf(game.grace,2)
	var tw:=create_tween()
	tweens.append(tw)
	tw.tween_property(shelf,"position:x",shelf_origin.x-1.9,1.2)
	tw.tween_callback(func():
		opened=true
		shelf_moving=false
		evidence_models.maintenance.show()
		game.build_navigation())
	game.world_sound("shelf_track",shelf.global_position,-13,1.2)

func _process(delta: float) -> void:
	if not game or not game.player: return
	if not captions:
		captions=game.text_label("",18)
		captions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		captions.offset_left=-430
		captions.offset_right=430
		captions.offset_top=-170
		captions.offset_bottom=-120
		captions.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if recording_time>=0:
		recording_time=recording.get_playback_position()
		var lines: Array=game.audio_production.tape_captions
		var text: String=""
		for cue in lines:
			if recording_time>=float(cue.start) and recording_time<float(cue.end): text=cue.text
		captions.text=text
	# Essential recording text remains readable even with optional subtitles off.
	# The inspected transcript already carries the words on the paper itself.
	var reading_transcript: bool=game.mode=="document" and evidence.current=="recording" and not evidence.journal_open
	captions.visible=recording_time>=0 and game.mode in ["playing","document"] and not reading_transcript

func utility_label(id: String) -> String:
	return {"upper":"upper-wing key","festival":"festival storeroom key","archive":"archive collection access key","compartment":"B3-12 compartment key","media":"media-room key","tape":"festival cassette F-12","rehearsal_U08":"U08 rehearsal key"}.get(id,id)

func utility(id: String,point: Vector3,container_id: String) -> void:
	var node: Node3D
	if id=="tape": node=game.props.cassette(point,game.world)
	else:
		node=game.make_physical_key(point)
		node.scale=Vector3.ONE*.28
		node.rotation.x=-PI/2
	node.set_meta("placement_category","PUZZLE_OBJECT")
	utility_nodes[id]=node
	if not container_id.is_empty():
		node.reparent(containers[container_id].tray,true)
		containers[container_id].contents.append(node)

func collect_utility(id: String) -> void:
	if utility_taken.get(id,false): return
	utility_taken[id]=true
	utility_inventory[id]=true
	utility_nodes[id].hide()
	if id=="rehearsal_U08": rehearsal_taken=true
	game.world_sound("key",utility_nodes[id].global_position,-15)
	game.player_voice.utility_collected(id)
	if id in ["upper","festival"]: game.progression.staff_completion()

func recording_finished() -> void:
	recording_time=-1
	if not tape_done:
		tape_done=true
		game.progression.tape_finished()
