extends Node
var game: Node
var entries := {}
var collected: Array[String] = []
var current := ""
var reverse := false
var journal_open := false
var preview: Node3D
var preview_camera: Camera3D
var tilt := Vector2.ZERO
var zoom := 1.05
var sleeve_button: Button
var preview_view: SubViewport
var preview_generation := 0

func build(g: Node) -> void:
	game=g
	entries=JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/evidence.json"))

func photo(index: int) -> AtlasTexture:
	var image: Texture2D=load("res://assets/story/festival_photos.png")
	var atlas:=AtlasTexture.new()
	atlas.atlas=image
	var width:=image.get_width()/3.0
	atlas.region=Rect2(index*width+2,0,width-4,image.get_height())
	return atlas

func make_document(id: String) -> Node3D:
	var root:=Node3D.new()
	root.name="Document_"+id
	var data: Dictionary=entries[id]
	var is_photo: bool=data.has("photo") or id=="class_photo"
	var dimensions:=Vector2(.48,.32) if id=="class_photo" else (Vector2(.40,.40) if is_photo else Vector2(.34,.48))
	var paper:=MeshInstance3D.new()
	var thickness:=BoxMesh.new()
	thickness.size=Vector3(dimensions.x,dimensions.y,.003)
	paper.mesh=thickness
	var edge:=StandardMaterial3D.new()
	edge.albedo_color=Color("b7ad94")
	edge.roughness=1
	paper.material_override=edge
	root.add_child(paper)
	for back in [false,true]:
		var surface:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=dimensions-Vector2(.003,.003)
		surface.mesh=quad
		surface.position.z=-.0017 if back else .0017
		if back: surface.rotation.y=PI
		var mat:=StandardMaterial3D.new()
		mat.roughness=1
		mat.metallic_specular=0
		mat.albedo_texture=load("res://assets/story/documents/rendered/%s%s.png" % [id,"_back" if back else ""])
		if is_photo and not back: mat.albedo_texture=load("res://assets/story/class_photo.png") if id=="class_photo" else load("res://assets/story/festival_photos.png")
		if data.has("photo") and not back:
			mat.uv1_scale=Vector3(1.0/3.0,1,1)
			mat.uv1_offset=Vector3(float(data.photo)/3.0,0,0)
		surface.material_override=mat
		root.add_child(surface)
	return root

func inspect(id: String) -> void:
	if game.mode!="playing" or not entries.has(id): return
	if not collected.has(id): collected.append(id)
	current=id
	game.world_sound("paper_lift",game.player.camera.global_position,-16)
	reverse=false
	tilt=Vector2.ZERO
	zoom=.76 if entries[current].has("photo") or current=="class_photo" else .85
	journal_open=false
	show_entry()

func show_entry() -> void:
	preview_generation += 1
	var generation := preview_generation
	game.mode="document"
	game.player.velocity=Vector3.ZERO
	var data: Dictionary=entries[current]
	var stack: VBoxContainer=game.panel_stack("","Drag to tilt  ·  Scroll to zoom")
	stack.custom_minimum_size.x=760
	var container:=TextureRect.new()
	var preview_height:=clampf(game.get_viewport().get_visible_rect().size.y-210,300,620)
	container.custom_minimum_size=Vector2(760,preview_height)
	container.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	container.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.modulate.a=0
	stack.add_child(container)
	var view:=SubViewport.new()
	preview_view=view
	view.size=Vector2i(760,int(preview_height))
	view.own_world_3d=true
	view.transparent_bg=true
	view.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	container.add_child(view)
	container.texture=view.get_texture()
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.018,.02,.019,0)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("f2e4c8")
	environment.environment.ambient_light_energy=1.1
	view.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-25,-25,0)
	light.light_energy=.7
	view.add_child(light)
	preview=make_document(current)
	view.add_child(preview)
	preview_camera=Camera3D.new()
	preview_camera.fov=35
	view.add_child(preview_camera)
	preview_camera.current=true
	update_preview()
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
			tilt=(tilt+event.relative*.005).clamp(Vector2(-.35,-.5),Vector2(.35,.5))
			update_preview()
		if event is InputEventMouseButton and event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom=maxf(.65,zoom-.08)
			if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom=minf(1.35,zoom+.08)
			update_preview())
	sleeve_button=game.button("TAKE KEY",func():
		game.progression.story_puzzles.collect_utility("compartment")
		refresh_sleeve_action(),stack)
	refresh_sleeve_action()
	var row:=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	stack.add_child(row)
	for value in ["FLIP","JOURNAL","CLOSE"]:
		var action: String=value
		var b: Button=game.button(value,func():
			match action:
				"FLIP": reverse=not reverse; game.world_sound("photo_handle" if entries[current].has("photo") else "paper_flip",game.player.camera.global_position,-16); update_preview(); refresh_sleeve_action()
				"JOURNAL": show_journal()
				"CLOSE": close()
		,row)
		b.custom_minimum_size=Vector2(180,40)
		b.add_theme_font_size_override("font_size",18)
	present_preview.call_deferred(container,view,generation)

func present_preview(container: Control, view: SubViewport, generation: int) -> void:
	# A new ViewportTexture has no completed image during its first UI layout.
	# Keep it rendering transparently until its target and camera are ready.
	for frame in range(3):
		if DisplayServer.get_name()=="headless": await get_tree().process_frame
		else: await RenderingServer.frame_post_draw
		if generation!=preview_generation or not is_instance_valid(view) or not is_instance_valid(container): return
	if game.mode!="document" or journal_open: return
	view.render_target_update_mode=SubViewport.UPDATE_ONCE
	create_tween().tween_property(container,"modulate:a",1.0,.10)

func update_preview() -> void:
	if not is_instance_valid(preview): return
	preview.rotation=Vector3(tilt.y,(PI if reverse else 0.0)+tilt.x,0)
	preview_camera.position=Vector3(0,0,zoom)
	preview_camera.look_at(Vector3.ZERO)
	if is_instance_valid(preview_view): preview_view.render_target_update_mode=SubViewport.UPDATE_ONCE

func close() -> void:
	preview_generation += 1
	if not journal_open:
		game.player_voice.document_closed(current,reverse)
		if current=="display": game.progression.portrait_closed()
	preview=null
	preview_view=null
	game.resume_game()

func reopen(id: String) -> void:
	current=id
	reverse=false
	tilt=Vector2.ZERO
	zoom=.76 if entries[current].has("photo") or current=="class_photo" else .85
	journal_open=false
	show_entry()

func show_journal() -> void:
	preview_generation += 1
	preview_view=null
	game.mode="document"
	journal_open=true
	preview=null
	var stack: VBoxContainer=game.panel_stack("EVIDENCE","Collected notes and photographs")
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(680,340)
	stack.add_child(scroll)
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id in collected:
		var evidence_id: String=id
		game.button(entries[id].title,func(): reopen(evidence_id),list)
	if collected.is_empty(): game.text_label("No evidence collected yet.",20,list)
	game.button("RETURN",close,stack).grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal") and game.mode in ["playing","document"]:
		if game.mode=="document": close()
		else: show_journal()
		get_viewport().set_input_as_handled()
	elif game.mode=="document" and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()

func refresh_sleeve_action() -> void:
	if is_instance_valid(sleeve_button): sleeve_button.visible=current=="display" and reverse and not game.progression.story_puzzles.utility_taken.get("compartment",false)
