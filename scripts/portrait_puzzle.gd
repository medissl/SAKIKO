extends Node
## Reconstruct an archived print from three physical, torn cardboard fragments.
## This is evidence restoration, never a magical key-spawning trigger.
var game: Node
var puzzles: Node
var pieces: Array[Node3D] = []
var owned := [false,false,false]
var slots := [-1,-1,-1]
var complete := false
var origins: Array[Transform3D] = []
var mounts: Array[Vector3] = []
var frame_point := Vector3(56,1.78,-16.53)

func build(g: Node,p: Node) -> void:
	game=g
	puzzles=p
	game.box(frame_point-Vector3(0,0,.045),Vector3(1.05,1.05,.07),"wood",true)
	game.box(frame_point-Vector3(0,0,.002),Vector3(.91,.91,.015),"dark",false)
	for x in [-.49,.49]: game.box(frame_point+Vector3(x,0,.015),Vector3(.04,1.02,.035),"wood",false)
	for y in [-.49,.49]: game.box(frame_point+Vector3(0,y,.015),Vector3(1.02,.04,.035),"wood",false)
	for i in range(3):
		mounts.append(frame_point+Vector3((i-1)*.30,0,.025))
		var fragment:=make_fragment(i)
		game.world.add_child(fragment)
		pieces.append(fragment)
	pieces[0].global_position=Vector3(54.6,.945,-14.65)
	pieces[0].rotation.x=-PI/2
	pieces[0].scale=Vector3.ONE*.55
	pieces[0].reparent(puzzles.containers.art_0.tray,true)
	pieces[1].global_position=Vector3(38,.87,-12)
	pieces[1].rotation=Vector3(-PI/2,0,.18)
	pieces[1].scale=Vector3.ONE*.55
	pieces[2].global_position=Vector3(20.77,.98,14.65)
	pieces[2].rotation.x=-PI/2
	pieces[2].scale=Vector3.ONE*.55
	pieces[2].reparent(puzzles.containers.av_case.tray,true)
	for piece in pieces: origins.append(piece.transform)

func seam(boundary: int,v: float) -> float:
	if boundary==0: return -.45
	if boundary==3: return .45
	return -.45+boundary*.30+sin(v*31+boundary*4)*.013+sin(v*63)*.005

func make_fragment(index: int) -> Node3D:
	var root:=Node3D.new()
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(18):
		var vertices: Array[Vector3]=[]
		var uvs: Array[Vector2]=[]
		for uv in [Vector2(0,row/18.0),Vector2(1,row/18.0),Vector2(1,(row+1)/18.0),Vector2(0,(row+1)/18.0)]:
			var x:=seam(index+int(uv.x),uv.y)
			vertices.append(Vector3(x-(index-1)*.30,.45-uv.y*.9,0))
			uvs.append(Vector2((2+(x+.45)/.9)/3,uv.y))
		for j in [0,2,1,0,3,2]:
			st.set_uv(uvs[j])
			st.add_vertex(vertices[j])
	st.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.mesh=st.commit()
	var mat:=StandardMaterial3D.new()
	mat.albedo_texture=load("res://assets/story/festival_photos.png")
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.roughness=1
	mat.metallic_specular=0
	mesh.material_override=mat
	root.add_child(mesh)
	var back:=MeshInstance3D.new()
	back.mesh=mesh.mesh
	back.position.z=-.006
	var cardboard:=StandardMaterial3D.new()
	cardboard.albedo_color=Color("80715b")
	cardboard.roughness=1
	cardboard.cull_mode=BaseMaterial3D.CULL_DISABLED
	back.material_override=cardboard
	root.add_child(back)
	return root

func reset() -> void:
	owned=[false,false,false]
	slots=[-1,-1,-1]
	complete=false
	for i in range(3):
		pieces[i].transform=origins[i]
		pieces[i].visible=i==1

func available_targets() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for i in range(3):
		if not owned[i] and not slots.has(i) and pieces[i].visible:
			result.append({"type":"fragment","index":i,"point":pieces[i].global_position,"label":"E  -  Take torn portrait fragment"})
	if complete:
		result.append({"type":"portrait","point":frame_point,"label":"E  -  Inspect restored portrait"})
	else:
		for i in range(3): result.append({"type":"portrait_slot","index":i,"point":mounts[i],"label":"E  -  Fit portrait fragment"})
	return result

func interact(item: Dictionary) -> void:
	match item.type:
		"fragment":
			owned[item.index]=true
			pieces[item.index].hide()
			game.sound("key",-28,.85)
		"portrait": game.progression.evidence.inspect("portrait")
		"portrait_slot": choose_fragment(item.index)

func place(index: int,slot: int) -> void:
	if not owned[index]: return
	if slots[slot]>=0:
		owned[slots[slot]]=true
		pieces[slots[slot]].hide()
	owned[index]=false
	slots[slot]=index
	pieces[index].global_transform=Transform3D(Basis.IDENTITY,mounts[slot])
	pieces[index].show()
	complete=slots==[0,1,2]
	game.sound("latch",-29)
	game.resume_game()

func choose_fragment(slot: int) -> void:
	game.mode="puzzle"
	var stack: VBoxContainer=game.panel_stack("TORN FESTIVAL PRINT","")
	var row:=HBoxContainer.new()
	stack.add_child(row)
	for i in range(3):
		if not owned[i]: continue
		var index: int=i
		var column:=VBoxContainer.new()
		row.add_child(column)
		var picture:=TextureRect.new()
		var atlas:=AtlasTexture.new()
		atlas.atlas=load("res://assets/story/festival_photos.png")
		var cell: float=atlas.atlas.get_width()/9.0
		atlas.region=Rect2((6+i)*cell,0,cell,atlas.atlas.get_height())
		picture.texture=atlas
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size=Vector2(180,230)
		column.add_child(picture)
		var button: Button=game.button("FIT THIS PIECE",func(): place(index,slot),column)
		button.set_meta("fragment_index",index)
		button.custom_minimum_size.x=200
		button.add_theme_font_size_override("font_size",18)
	if slots[slot]>=0:
		game.button("REMOVE FITTED PIECE",func():
			owned[slots[slot]]=true
			pieces[slots[slot]].hide()
			slots[slot]=-1
			game.resume_game(),stack)
	if not owned.has(true): game.text_label("No loose fragments.",18,stack)
	game.button("CLOSE",game.resume_game,stack)
