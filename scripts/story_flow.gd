extends Node
## One authoritative route; old festival_puzzles.gd is retired and never instantiated.
const SAVE_VERSION := 5
const OBJECTIVES := ["Find the main entrance.","Restore power to the south wing.","Go to the art room.","Visit the festival exhibition upstairs.","Play the tape in the AV room, first floor.","Leave the AV room.","Reach the rehearsal room upstairs. Use the green west stairs.","Reach the rehearsal room. Follow the corridor past the classrooms.","Unlock the main entrance."]
const HINTS := ["The entrance is through the west lobby.","Check the breaker beside the staff-room entrance.","Follow the south corridor to Art. Check the festival packing table.","Use the green west stairs, then follow the south corridor to Exhibition.","Use the blue east stairs. AV is at the east end of the first-floor north corridor.","The library has two doors. The staff room is farther west.","The hand mechanism is beside the shutter on the upper north corridor.","Follow the north corridor east. The classrooms have connecting doors.","Return to the west lobby and use the key on the entrance lock."]
var game: Node
var evidence: Node
var stage := 0
var flags: Dictionary = {}
var targets: Array[Dictionary] = []
var evidence_models: Dictionary = {}
var gates: Dictionary = {}
var tweens: Array[Tween] = []
var recording: AudioStreamPlayer3D
var recording_time := -1.0
var transcript_index := 0
var tape_close_button: Button
const TAPE_BLOCKS := ["The front-door key is in the rehearsal room.\nOn the chair beside the mirror.","And Sakiko?","I thought you were going back.","[Knocking.]","Turn it off."]
var captions: Label
var tape: Node3D
var exit_key: Node3D
var cover: Node3D
var lever: Node3D
var bolt: Node3D
var rehearsal_bolt: Node3D
var south_lights: Array[OmniLight3D] = []
var stalled := 0.0
var nav_dirty := false
var hinted: Dictionary = {}
var previous_av := false
var bolt_time := 0.0
var bolt_knock := false
var generation := 0
var winch: Node3D
var winch_audio: AudioStreamPlayer3D
var crank_bar: ProgressBar
var cranking:=false
var noise_clock:=0.0
var landing_door: Dictionary
var landing_bolt: Node3D
var shortcut_latch: Node3D
const WINCH_POINT := Vector3(14.03,5.2,10.8)
var middle_started_at:=-1.0
var solved := [false]
var shelf_moving := false

func build(g: Node, journal: Node) -> void:
	game=g
	evidence=journal
	# Reuse the detailed existing cassette model, inside an opened packing case.
	tape=game.props.cassette(Vector3(29.05,.857,31.65),game.world)
	tape.name="FestivalCassette"
	game.box(Vector3(29.05,.847,31.65),Vector3(.28,.012,.19),"dark",false)
	var plastic:=StandardMaterial3D.new()
	plastic.albedo_color=Color(.52,.56,.53,.18)
	plastic.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	plastic.roughness=.22
	game.box(Vector3(29.05,.948,31.748),Vector3(.28,.19,.008),"glass",false).material_override=plastic
	game.box(Vector3(29.05,.855,31.568),Vector3(.26,.002,.03),"paper",false)
	var case_label: Label3D=game.label3("Festival exhibition — 2F",Vector3(29.05,.857,31.568),0,.00018,Color("37362e"))
	case_label.rotation.x=-PI/2
	document("original",Vector3(28.3,.852,31.65),true)
	document("display",Vector3(32,6.05,35.60),false,PI)
	evidence_models.display.scale=Vector3.ONE*3.5
	game.box(Vector3(32,6.05,35.65),Vector3(1.5,1.5,.04),"wood",false)
	game.layout.placement.grounded_asset(game.chair_asset,game.world,Vector3(45.8,4.2,34.45),PI,.91)
	game.box(Vector3(45.8,5.85,35.86),Vector3(1.0,1.8,.06),"metal",false)
	var mirror:=StandardMaterial3D.new()
	mirror.albedo_color=Color("657079")
	mirror.metallic=.85
	mirror.roughness=.24
	game.box(Vector3(45.8,5.85,35.82),Vector3(.91,1.71,.012),"metal",false).material_override=mirror
	exit_key=game.make_physical_key(Vector3(45.8,4.666,34.45))
	exit_key.scale=Vector3.ONE*.24
	exit_key.rotation.x=-PI/2
	document("letter",Vector3(45.64,4.662,34.52),true)
	build_rehearsal_details()
	evidence_models.letter.scale=Vector3.ONE*.55
	document("notice",Vector3(23.88,1.65,5.8),false,-PI/2)
	# Visible through the staff doorway, on the side wall beyond the desks.
	var breaker_root:=Node3D.new()
	game.world.add_child(breaker_root)
	breaker_root.position=Vector3(31.84,1.55,2.6)
	breaker_root.rotation.y=PI/2
	game.box(Vector3.ZERO,Vector3(.48,.64,.12),"metal",false,breaker_root)
	lever=game.box(Vector3(0,0,-.12),Vector3(.10,.20,.08),"red",false,breaker_root)
	cover=Node3D.new()
	breaker_root.add_child(cover)
	cover.position=Vector3(-.255,0,-.21)
	game.box(Vector3(.255,0,0),Vector3(.51,.67,.045),"metal",false,cover)
	var breaker_label: Label3D=game.label3("South wing",breaker_root.to_global(Vector3(0,.22,-.237)),3*PI/2,.00045,Color("b4b1a1"))
	breaker_label.reparent(breaker_root,true)
	breaker_label.position=Vector3(0,.23,-.125)
	bolt=game.box(Vector3(28.25,1.30,7.58),Vector3(.29,.07,.06),"metal",false)
	bolt.reparent(game.layout.room_doors.G03[0].panels[0],true)
	bolt.set_meta("rest",bolt.position)
	rehearsal_bolt=game.box(Vector3(45,5.5,28.15),Vector3(.27,.07,.045),"metal",false)
	rehearsal_bolt.reparent(game.layout.room_doors.U08[0].panels[0],true)
	# Transport is a fixed deck, not a second collectible cassette.
	game.box(Vector3(42.3,.96,1.3),Vector3(.65,.22,.4),"metal",false)
	game.box(Vector3(42.3,.97,1.51),Vector3(.40,.065,.012),"dark",false)
	game.box(Vector3(42.53,.96,1.52),Vector3(.055,.055,.018),"red",false)
	for point in [Vector3(10,2.9,25.5),Vector3(25,2.9,27),Vector3(29,2.6,31.5)]:
		var light:=OmniLight3D.new()
		light.position=point
		light.light_color=Color("a8a48b")
		light.light_energy=.30
		light.omni_range=5
		game.world.add_child(light)
		south_lights.append(light)
	gate("staff",Vector3(23.5,0,10),true)
	gate("south",Vector3(10,0,16),false)
	gate("north_east",Vector3(32,0,10),true)
	gate("south_east",Vector3(41.5,0,26),true)
	gate("upper_north",Vector3(10,4.2,16),false)
	gate("upper_north_east",Vector3(16,4.2,10),true)
	gate("upper_east",Vector3(40.5,4.2,26),true)
	game.layout.plaque("← ART",Vector3(10,2.6,27.88),PI,game.world,.85)
	game.layout.plaque("← REHEARSAL",Vector3(41.5,6.75,27.88),PI,game.world,1.5)
	recording=AudioStreamPlayer3D.new()
	recording.stream=load("res://assets/audio/festival_nonverbal.wav")
	recording.position=Vector3(42.3,1.0,1.3)
	recording.bus="SFX"
	recording.unit_size=5
	recording.volume_db=-3
	game.world.add_child(recording)
	recording.finished.connect(recording_finished)
	build_middle_hardware()
	for d in game.doors: d.requirement=""; d.lock_label=""

func build_rehearsal_details() -> void:
	# Personal belongings and damage tell what happened here without another clue sheet.
	game.props.bag(Vector3(43.85,4.66,33.4),game.world)
	var prop:=Node3D.new()
	prop.name="DiscardedCardboardMount"
	prop.position=Vector3(44.0,4.18,35.765)
	prop.rotation=Vector3(.14,0,0)
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
	for i in range(8):
		var scratch: MeshInstance3D=game.box(Vector3(44.4+i*.04,5.28+i*.045,28.236),Vector3(.23,.008,.006),"dark",false)
		scratch.reparent(game.layout.room_doors.U08[0].panels[0],true)


func document(id: String, point: Vector3, flat:=false, yaw:=0.0) -> void:
	var model: Node3D=evidence.make_document(id)
	game.world.add_child(model)
	model.position=point
	model.rotation=Vector3(-PI/2,0,0) if flat else Vector3(0,yaw,0)
	evidence_models[id]=model
	targets.append({"type":"evidence","id":id,"point":point})

func gate(id: String, point: Vector3, across_x: bool) -> void:
	var root:=Node3D.new()
	game.world.add_child(root)
	root.position=point
	root.name="FireShutter_"+id
	root.add_to_group("moving_obstruction")
	var size:=Vector3(.14,3.15,3.98) if across_x else Vector3(3.98,3.15,.14)
	var mesh: MeshInstance3D=game.box(Vector3(0,1.575,0),size,"metal",false,root)
	var body:=StaticBody3D.new()
	mesh.add_child(body)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	for i in range(15): game.box(Vector3(0,.12+i*.20,.075),Vector3(3.96,.012,.012) if not across_x else Vector3(.16,.012,3.96),"dark",false,root)
	gates[id]={"root":root,"origin":point,"open":false,"shape":shape}

func set_gate(id: String, opened: bool, animate: bool) -> void:
	var data: Dictionary=gates[id]
	if data.open==opened: return
	if not opened and gate_occupied(id): return
	data.open=opened
	var destination: Vector3=data.origin+Vector3(0,3.05 if opened else 0,0)
	if animate:
		var shutter_audio: AudioStreamPlayer3D=game.world_sound("shelf_track",data.origin+Vector3(0,1.4,0),-6,1.4)
		shutter_audio.unit_size=10
		shutter_audio.max_distance=36
		var tw:=create_tween()
		tweens.append(tw)
		tw.parallel().tween_property(data.root,"position",destination,1.4)
		tw.parallel().tween_property(data.root,"scale:y",.03 if opened else 1.0,1.4)
		tw.tween_callback(func(): nav_dirty=true)
	else:
		data.root.position=destination
		data.root.scale.y=.03 if opened else 1.0

func can_open(d: Dictionary) -> bool:
	if str(d.get("room",""))=="G03" and (flags.get("bolted",false) or flags.get("bolting",false)): return false
	match str(d.get("room","")):
		"G01","G02": return true
		"G03": return true
		"G08","G07": return stage>=2
		"STAIR_W","U01": return stage>=3
		"U07": return stage>=3 and (d.origin.x<30 or stage>=4 or game.progression.encounters_controller.reveal_seen)
		"STAIR_E","G04","G05": return stage>=4
		"LANDING_E_UPPER": return stage>=4 and (not flags.get("middle_section_active",false) or flags.get("east_landing_unbolted",false))
		"U02","U03": return flags.get("middle_section_active",false)
		"U08": return flags.get("tape_done",false)
	return false

func apply_state(animate:=false) -> void:
	set_gate("staff",true,animate)
	set_gate("south",stage>=2,animate)
	set_gate("upper_north",stage>=3,animate)
	for id in ["north_east","south_east"]: set_gate(id,stage>=4,animate)
	set_gate("upper_north_east",stage>=4 and (not flags.get("middle_section_active",false) or flags.get("shutter_open",false)),animate)
	set_gate("upper_east",stage>=4 and (not flags.get("middle_section_active",false) or flags.get("south_shortcut_released",false)),animate)
	if flags.get("middle_section_active",false) and not flags.get("shutter_open",false): apply_shutter_progress()
	landing_bolt.position=landing_bolt.get_meta("rest")+Vector3(-.16 if flags.get("east_landing_unbolted",false) else 0,0,0)
	shortcut_latch.rotation.x=-1.1 if flags.get("south_shortcut_released",false) else 0
	for d in game.doors: d.locked=not can_open(d)
	if stage>=4:
		for d in game.layout.room_doors.G04:
			if not d.open: game.toggle_door(d,true)
	for light in south_lights: light.visible=stage>=2
	cover.rotation.y=1.3
	lever.rotation.z=0 if stage>=2 else .6
	tape.visible=not flags.get("cassette",false)
	exit_key.visible=not flags.get("key",false)
	rehearsal_bolt.rotation.z=-1.1 if flags.get("tape_done",false) else 0.0
	bolt.position=bolt.get_meta("rest")+Vector3(.15 if flags.get("bolted",false) else 0,0,0)
	game.collected=1 if flags.get("key",false) else 0
	game.progression.hunt_enabled=flags.get("chase_started",false)
	game.aimed_frame=-1

func advance(next_stage: int, checkpoint_id:="") -> void:
	stage=next_stage
	stalled=0
	apply_state(true)
	game.player_voice.progress()
	if not checkpoint_id.is_empty(): game.save_checkpoint(checkpoint_id)

func reset() -> void:
	stop_crank()
	middle_started_at=-1
	generation+=1
	nav_dirty=false
	for tw in tweens:
		if tw and tw.is_valid(): tw.kill()
	tweens.clear()
	for id in gates:
		gates[id].open=false
		gates[id].root.position=gates[id].origin
		gates[id].root.scale=Vector3.ONE
	stage=0
	flags.clear()
	hinted.clear()
	stalled=0
	previous_av=false
	bolt_time=0
	bolt_knock=false
	recording.stop()
	recording_time=-1
	evidence.collected.clear()
	apply_state()

func objective() -> String:
	if stage==2 and in_room("G08"): return "Check the festival packing table."
	if stage==3 and in_room("U07"): return "Examine the festival portrait."
	if stage==4 and in_room("G05"): return "Play the festival tape."
	if stage==5 and flags.get("chase_started",false): return "Get away from Sakiko."
	if stage==6 and game.player.position.y>3.8 and game.player.position.z<22 and game.player.position.x<17: return "Raise the shutter to reach the rehearsal wing."
	if stage==7:
		if in_room("U08"): return "Find the key on the chair beside the mirror."
		if game.player.position.x>43 and game.player.position.y>3.8: return "Follow the east corridor to Rehearsal."
	return OBJECTIVES[stage]

func in_room(id: String) -> bool:
	return absf(game.player.position.y-float(game.layout.room_floors[id])*4.2)<1.0 and game.layout.rooms[id].has_point(Vector2(game.player.position.x,game.player.position.z))

func available_targets() -> Array[Dictionary]:
	var result: Array[Dictionary]=targets.duplicate()
	if stage==1: result.append({"type":"breaker","point":lever.global_position,"label":"E — Reset"})
	if stage==2 and flags.get("original",false): result.append({"type":"cassette","point":tape.position,"label":"E — Take"})
	if stage==4: result.append({"type":"recording","point":Vector3(42.3,1.0,1.3),"label":"E — Play" if flags.get("inserted",false) else "E — Insert tape"})
	if stage==7: result.append({"type":"exit_key","point":exit_key.position,"label":"E — Take"})
	if flags.get("chase_started",false) and in_room("G03"): result.append({"type":"bolt","point":bolt.global_position,"label":"E — Unbolt door" if flags.get("bolted",false) else "E — Bolt door"})
	if stage==6 and flags.get("middle_section_active",false): result.append({"type":"winch","point":WINCH_POINT,"label":"Hold E — Raise shutter"})
	if flags.get("middle_section_active",false) and game.player.position.y>3.5:
		if not flags.get("east_landing_unbolted",false) and game.player.position.x<47.9: result.append({"type":"landing_bolt","point":landing_bolt.global_position,"label":"E — Unbolt"})
		if not flags.get("south_shortcut_released",false) and game.player.position.x>40.65: result.append({"type":"shortcut_latch","point":shortcut_latch.global_position,"label":"E — Release latch"})
	return result

func targeted() -> Dictionary: return {}

func interact(item: Dictionary) -> void:
	match item.type:
		"evidence": evidence.inspect(item.id)
		"breaker":
			if stage==1: advance(2,"CP1")
		"cassette":
			if stage!=2 or not flags.get("original",false): return
			flags.cassette=true
			game.world_sound("case_latch",tape.position,-10)
			game.world_sound("school_bell",Vector3(8,2.7,19),-12)
			advance(3)
			for d in game.doors:
				if d.room=="STAIR_W": game.toggle_door(d,true)
		"recording":
			if not flags.get("inserted",false):
				flags.inserted=true
				game.world_sound("case_latch",recording.position,-9)
			else: play_tape()
		"exit_key":
			flags.key=true
			game.sound("key",-12)
			advance(8,"CP6")
		"bolt": toggle_bolt()
		"winch": pass # Holding input drives the mechanism; movement is never captured.
		"landing_bolt":
			if game.player.position.x>=47.9: return
			flags.east_landing_unbolted=true
			apply_state()
			game.world_sound("lock_turn",landing_bolt.global_position,-10)
			game.toggle_door(landing_door,true)
			game.build_navigation()
			persist_middle()
		"shortcut_latch":
			if game.player.position.x<=40.65: return
			flags.south_shortcut_released=true
			game.world_sound("lock_turn",shortcut_latch.global_position,-10)
			apply_state(true)
			persist_middle()

func try_exit() -> void:
	if stage==0:
		flags.exit_tried=true
		game.toast("Locked.",2)
		game.world_sound("locked",game.layout.EXIT_TARGET,-12)
		advance(1)
	elif not flags.get("key",false):
		game.toast("Locked.",2)
		game.world_sound("locked",game.layout.EXIT_TARGET,-12)
	elif not game.hardware.released[0]: game.hardware.release(0)
	elif not game.hardware.busy and not game.exit_open:
		game.exit_open=true
		for i in range(game.exit_panels.size()):
			var tw:=create_tween()
			tweens.append(tw)
			tw.tween_property(game.exit_panels[i],"position:z",game.progression.exit_origins[i].z+(-1.3 if i==0 else 1.3),.8)

func play_tape() -> void:
	game.player.cancel_movement()
	game.mode="playback"
	game.player_voice.flush()
	game.player.velocity=Vector3.ZERO
	var stack: VBoxContainer=game.panel_stack("FESTIVAL RECORDING","")
	captions=game.text_label("[Tape starts.]",25,stack)
	captions.add_theme_font_override("font",game.serif)
	captions.custom_minimum_size=Vector2(680,180)
	captions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	transcript_index=0
	game.button("PREVIOUS",func(): step_transcript(-1),stack)
	game.button("NEXT / REVIEW",func(): step_transcript(1),stack)
	tape_close_button=game.button("CLOSE",close_tape,stack)
	game.text_label("Read at your own pace. Closing early leaves the tape available to replay.",15,stack)
	recording_time=0
	captions.text=TAPE_BLOCKS[0]
	recording.play()

func step_transcript(direction: int) -> void:
	transcript_index=clampi(transcript_index+direction,0,TAPE_BLOCKS.size()-1)
	captions.text=TAPE_BLOCKS[transcript_index]
	if transcript_index==TAPE_BLOCKS.size()-1: recording_finished()

func close_tape() -> void:
	recording.stop()
	recording_time=-1
	game.resume_game()

func recording_finished() -> void:
	if recording_time<0: return
	recording_time=-1
	flags.tape_done=true
	if not evidence.collected.has("recording"): evidence.collected.append("recording")
	advance(5,"CP4")
	game.world_sound("shackle_release",Vector3(45,5.5,28),-6)
	var stack: VBoxContainer=game.panel_stack("FESTIVAL RECORDING","")
	var text: Label=game.text_label(evidence.entries.recording.body,23,stack)
	text.add_theme_font_override("font",game.serif)
	text.custom_minimum_size=Vector2(700,290)
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	game.button("CLOSE",close_tape,stack).grab_focus()
	game.mode="playback_review"

func toggle_bolt() -> void:
	var token:=generation
	var d: Dictionary=game.layout.room_doors.G03[0]
	if d.busy: return
	if d.open:
		game.toggle_door(d)
		if d.open: return
		flags.bolting=true
		await get_tree().create_timer(.75).timeout
		if token!=generation: return
		flags.bolting=false
		if game.mode!="playing" or d.open or d.busy: return
	flags.bolted=not flags.get("bolted",false)
	if flags.bolted and game.enemy.position.distance_to(Vector3(29,1.5,9.8))<12 and game.clear_line(game.enemy.position,Vector3(29,1.5,9.8)):
		game.ai_state="investigate"
		game.last_seen=Vector3(29,1.5,9.8)
		game.state_time=0
		game.lost_sight=0
		game.navigate(game.last_seen)
	game.world_sound("lock_turn",bolt.global_position,-10)
	bolt_time=0
	bolt_knock=false
	apply_state()
	game.build_navigation()

func _process(delta: float) -> void:
	if not game or not game.player: return
	update_crank(delta)
	if nav_dirty:
		nav_dirty=false
		game.build_navigation()
	if recording_time>=0 and game.mode=="playback":
		recording_time+=delta
		var timed_index:=0 if recording_time<8 else (1 if recording_time<12 else (2 if recording_time<17 else (3 if recording_time<21 else 4)))
		transcript_index=maxi(transcript_index,timed_index)
		captions.text=TAPE_BLOCKS[transcript_index]
	if game.mode!="playing": return
	update_middle()
	if stage==3 and game.player.position.y>3.8 and not flags.get("landing",false):
		flags.landing=true
		game.save_checkpoint("CP2")
	var av:=in_room("G05")
	if stage==5 and not flags.get("chase_started",false) and previous_av and not av and game.player.position.z>8.65: game.progression.encounters_controller.start_pursuit()
	previous_av=av or (previous_av and stage==5 and not flags.get("chase_started",false))
	if stage>=2 and not flags.get("chair",false) and not in_room("G03"):
		flags.chair=true
		game.world_sound("creak",Vector3(13,1,4),-10,.85)
	if flags.get("bolted",false):
		bolt_time+=delta
		if not bolt_knock and game.enemy.position.distance_to(Vector3(29,1.5,9.8))<3:
			bolt_knock=true
			game.world_sound("staff_knocks",Vector3(29,1.4,8.13),-9)
		if bolt_knock and bolt_time>8 and not flags.get("escape_done",false): game.progression.encounters_controller.disengage()
	stalled+=delta
	if stalled>=60 and not hinted.has(stage) and not game.player_voice.danger_or_dialogue():
		hinted[stage]=true
		game.player_voice.say("The key is on the chair beside the mirror." if stage==7 and in_room("U08") else HINTS[stage])

func snapshot() -> Dictionary:
	return {"stage":stage,"flags":flags.duplicate(true),"hinted":hinted.duplicate(),"evidence":evidence.collected.duplicate()}

func build_middle_hardware() -> void:
	var first_child: int=game.world.get_child_count()
	# Extend the existing shutter rather than adding a second collision plane.
	game.box(Vector3(16,7.36,10),Vector3(.38,.28,4.12),"metal",true)
	for z in [8.12,11.88]: game.box(Vector3(16,5.78,z),Vector3(.28,3.16,.14),"metal",true)
	game.box(Vector3(40.5,7.36,26),Vector3(.38,.28,4.12),"metal",true)
	for z in [24.12,27.88]: game.box(Vector3(40.5,5.78,z),Vector3(.28,3.16,.14),"metal",true)
	game.box(Vector3(14.3,4.23,10.8),Vector3(.45,.06,.45),"metal",true)
	game.box(Vector3(14.3,4.76,10.8),Vector3(.16,1.06,.16),"metal",true)
	var gearbox:=MeshInstance3D.new()
	var housing:=CylinderMesh.new();housing.top_radius=.15;housing.bottom_radius=.15;housing.height=.22;housing.radial_segments=16
	gearbox.mesh=housing;gearbox.material_override=game.materials.metal
	game.world.add_child(gearbox);gearbox.position=Vector3(14.19,5.2,10.8);gearbox.rotation.z=PI/2
	var cable: MeshInstance3D=game.box(Vector3(15.15,6.2,10.8),Vector3(.018,sqrt(1.7*1.7+4),.018),"metal",false)
	cable.rotation.z=-atan2(1.7,2.0)
	winch=Node3D.new()
	game.world.add_child(winch)
	winch.position=WINCH_POINT
	game.box(Vector3(0,.14,0),Vector3(.045,.3,.045),"metal",false,winch)
	var grip:=MeshInstance3D.new()
	var knob:=CylinderMesh.new();knob.top_radius=.04;knob.bottom_radius=.04;knob.height=.18;knob.radial_segments=12
	grip.mesh=knob;grip.material_override=game.materials.dark
	winch.add_child(grip);grip.position=Vector3(-.09,.28,0);grip.rotation.z=PI/2
	winch_audio=AudioStreamPlayer3D.new()
	winch_audio.stream=load("res://assets/audio/winch_ratchet.wav")
	winch_audio.position=WINCH_POINT
	winch_audio.bus="WorldSFX"
	winch_audio.volume_db=-8
	winch_audio.unit_size=5
	winch_audio.max_distance=24
	game.world.add_child(winch_audio)
	winch_audio.finished.connect(func():
		if cranking: winch_audio.play())
	game.make_door(Vector3(48,4.2,19),1)
	landing_door=game.doors.back()
	landing_door.node.rotation.y=PI/2
	landing_door.room="LANDING_E_UPPER"
	landing_door.slide_direction=1.0
	game.fit_door_tracks(landing_door)
	landing_bolt=game.box(Vector3(48.145,5.22,19.12),Vector3(.055,.055,.30),"metal",false)
	landing_bolt.reparent(landing_door.panels[0],true)
	landing_bolt.set_meta("rest",landing_bolt.position)
	var plate: MeshInstance3D=game.box(Vector3(48.16,5.22,19.19),Vector3(.05,.12,.24),"dark",false)
	plate.reparent(landing_door.panels[0],true)
	var keeper: MeshInstance3D=game.box(Vector3(48.24,5.22,18.98),Vector3(.21,.11,.065),"metal",false)
	keeper.reparent(landing_door.panels[1],true)
	shortcut_latch=game.box(Vector3(40.72,5.5,27.72),Vector3(.06,.24,.12),"metal",false)
	game.box(Vector3(40.62,5.5,27.72),Vector3(.20,.29,.18),"dark",false)
	game.layout.plaque("REHEARSAL →",Vector3(12,6.8,8.13),0,game.world,1.6)
	game.layout.plaque("REHEARSAL →",Vector3(47.86,6.8,10.5),-PI/2,game.world,1.6)
	# Allows a bounded render-cost comparison without changing retail gate/AI rules.
	for node in game.world.get_children().slice(first_child):
		if node is Node3D: node.add_to_group("middle_hardware")
	crank_bar=ProgressBar.new()
	crank_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	crank_bar.offset_left=-100
	crank_bar.offset_right=100
	crank_bar.offset_top=-84
	crank_bar.offset_bottom=-80
	crank_bar.show_percentage=false
	crank_bar.max_value=1
	crank_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var fill:=StyleBoxFlat.new();fill.bg_color=Color(.40,.37,.29,.8)
	var backing:=StyleBoxFlat.new();backing.bg_color=Color(.018,.021,.020,.8)
	crank_bar.add_theme_stylebox_override("fill",fill)
	crank_bar.add_theme_stylebox_override("background",backing)
	call_deferred("attach_crank_bar")
	crank_bar.hide()

func attach_crank_bar() -> void:
	game.gui.add_child(crank_bar)

func gate_occupied(id: String) -> bool:
	var data: Dictionary=gates[id]
	var across_x: bool=id in ["staff","north_east","south_east","upper_north_east","upper_east"]
	for actor in [game.player,game.enemy]:
		if not is_instance_valid(actor) or (actor==game.enemy and not actor.visible): continue
		var feet: Vector3=actor.position-(Vector3(0,1.5,0) if actor==game.enemy else Vector3.ZERO)
		if absf(feet.y-data.origin.y)>1.2: continue
		var offset: Vector3=feet-data.origin
		if absf(offset.x)<(1.1 if across_x else 2.8) and absf(offset.z)<(2.8 if across_x else 1.1): return true
	return false

func update_middle() -> void:
	if flags.get("tape_done",false) and not flags.get("middle_section_active",false) and game.player.position.y<1:
		if gate_occupied("upper_north_east") or gate_occupied("upper_east"): return
		if game.enemy.visible and game.enemy.position.distance_to(Vector3(48,5.7,19))<2.4: return
		if landing_door.busy: return
		# Closing uses the normal door operation before its upper-side bolt engages.
		if landing_door.open: game.toggle_door(landing_door)
		flags.middle_section_active=true
		flags.shutter_progress=0.0
		flags.shutter_open=false
		flags.east_landing_unbolted=false
		flags.south_shortcut_released=false
		game.world_sound("case_latch",Vector3(16,6.8,10),-8)
		for d in game.layout.room_doors.U01: game.toggle_door(d,true)
		apply_state(true)
		game.build_navigation()
		persist_middle()
	if stage==6 and middle_started_at<0: middle_started_at=game.clock
	if stage==7 and game.player.position.y>3.8 and game.player.position.x>43 and game.player.position.z<14 and not flags.get("far_arrived",false):
		if game.ai_state in ["chase","investigate","search","approach"]: return
		if game.enemy.visible and game.enemy.position.distance_to(game.player.camera.global_position)<12: return
		flags.far_arrived=true
		game.save_checkpoint("MIDDLE_FAR")

func apply_shutter_progress() -> void:
	var progress: float=clampf(float(flags.get("shutter_progress",0.0)),0,1)
	# No standing-height opening before the final release. The collider moves with the slats.
	var lift:=.4*minf(progress/.9,1.0)+.8*smoothstep(.9,1.0,progress)
	gates.upper_north_east.root.position=gates.upper_north_east.origin+Vector3(0,lift,0)
	gates.upper_north_east.root.scale=Vector3.ONE
	winch.rotation.x=progress*TAU*8

func update_crank(delta: float) -> void:
	if not is_instance_valid(crank_bar): return
	var eligible: bool=stage==6 and flags.get("middle_section_active",false) and not flags.get("shutter_open",false) and game.mode=="playing" and game.input_focused and Input.is_action_pressed("interact")
	if eligible: eligible=game.interactable().get("type","")=="winch"
	if not eligible:
		stop_crank()
		return
	if not cranking:
		cranking=true
		noise_clock=0
		winch_audio.play()
		mechanism_noise()
	flags.shutter_progress=clampf(float(flags.get("shutter_progress",0.0))+delta/12.0,0,1)
	apply_shutter_progress()
	crank_bar.value=flags.shutter_progress
	crank_bar.show()
	noise_clock+=delta
	if noise_clock>=2:
		noise_clock-=2
		mechanism_noise()
	if flags.shutter_progress>=1:
		flags.shutter_open=true
		stage=7
		stop_crank()
		for room in ["U02","U03"]:
			for door in game.layout.room_doors[room]: game.toggle_door(door,true)
		advance(7,"MIDDLE_SHUTTER")

func stop_crank() -> void:
	if not cranking: return
	cranking=false
	if is_instance_valid(winch_audio): winch_audio.stop()
	if is_instance_valid(crank_bar): crank_bar.hide()
	persist_middle()

func mechanism_noise() -> void:
	game.audio_trace.append({"clip":"winch_noise","point":WINCH_POINT})
	if not game.progression.hunt_enabled or absf(game.enemy.position.y-WINCH_POINT.y)>1.8: return
	var reach:=18.0 if game.clear_line(game.enemy.position,WINCH_POINT) else 11.7
	if game.enemy.position.distance_to(WINCH_POINT)>reach or game.ai_state=="chase": return
	game.last_seen=WINCH_POINT
	game.lost_sight=0
	game.state_time=0
	game.ai_state="investigate"
	game.navigate(WINCH_POINT)

func persist_middle() -> void:
	if game.checkpoint_state.is_empty(): return
	# Keep the last SAFE position; only merge legitimately completed world/progress state.
	var old_progress: float=float(game.checkpoint_state.flow.flags.get("shutter_progress",0.0))
	flags.shutter_progress=maxf(old_progress,float(flags.get("shutter_progress",0.0)))
	game.checkpoint_state.flow=snapshot()
	game.checkpoint_state.encounters=game.progression.encounters_controller.snapshot()
	for i in range(game.doors.size()): game.checkpoint_state.doors[i].open=game.doors[i].open
	game.persist_voice_flags()

func restore(data: Dictionary) -> void:
	reset()
	stage=int(data.stage)
	flags=data.flags.duplicate(true)
	flags.bolting=false
	flags.middle_warning=false # A quiet tactical approach cue can recur on a new attempt.
	hinted=data.get("hinted",{}).duplicate()
	evidence.collected.assign(data.evidence)
	previous_av=stage==5
	apply_state()
