extends RefCounted
## Shared original kit. Room-local placement and world-space clearance checks.
var game: Node
var scenes: Dictionary={}
var surfaces: Dictionary={}
var book_materials: Dictionary={}
var palette: Dictionary={}

func setup(g: Node) -> void:
	game=g
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/furniture/finish/manifest.json"))
	for asset in manifest.assets: scenes[asset.name]=load("res://assets/furniture/finish/"+asset.name+".glb")
	for id in ["clinic_vinyl","service_tile","ceiling_ivory"]:
		var mat:=StandardMaterial3D.new()
		mat.albedo_texture=load("res://assets/furniture/finish/textures/"+id+".png")
		mat.uv1_triplanar=true
		mat.uv1_scale=Vector3.ONE*.5
		mat.roughness=.94;mat.metallic_specular=.08
		surfaces[id]=mat
	game.materials.ceiling=surfaces.ceiling_ivory
	var joint:=StandardMaterial3D.new();joint.albedo_color=Color("9a9b90");joint.roughness=1;joint.metallic_specular=0
	surfaces.ceiling_joint=joint
	var stained: StandardMaterial3D=game.materials.wood.duplicate()
	stained.albedo_color=Color("8d7b67")
	surfaces.stained=stained
	for id in ["book","file","case"]:
		var mat:=StandardMaterial3D.new()
		mat.albedo_texture=load("res://assets/furniture/finish/textures/"+id+"_atlas.png")
		mat.roughness=1;mat.metallic_specular=0
		book_materials[id]=mat
	var file_cabinet:=StandardMaterial3D.new();file_cabinet.albedo_color=Color("8a9288");file_cabinet.roughness=.92;file_cabinet.metallic_specular=.1
	game.materials.filecabinet=file_cabinet

func model(id: String,point: Vector3,yaw: float,parent: Node3D,collision_size:=Vector3.ZERO,assembly_id:="") -> Node3D:
	var root:=Node3D.new()
	root.name="Finished_"+id
	parent.add_child(root);root.position=point;root.rotation.y=yaw
	var instance: Node3D=scenes[id].instantiate()
	root.add_child(instance)
	var bounds:=AABB()
	var first:=true
	for mesh in instance.find_children("*","MeshInstance3D",true,false):
		var a: AABB=mesh.global_transform*mesh.get_aabb()
		bounds=a if first else bounds.merge(a);first=false
		for surface in range(mesh.mesh.get_surface_count()):
			var mat: Material=mesh.get_active_material(surface)
			if mat:
				if not palette.has(mat.resource_name): palette[mat.resource_name]=surfaces.stained if mat.resource_name.begins_with("KitWood") else mat
				mesh.set_surface_override_material(surface,palette[mat.resource_name])
	if id=="archive_box":
		game.layout.text_surface("SCENERY" if str(parent.name).begins_with("G09") else "資料 / ARCHIVE",Vector3(0,.17,-.172),PI,.013,Color("41483c"),root)
	if collision_size!=Vector3.ZERO:
		var owner:=str(parent.name)+" / "+id+" "+str(point)
		if not game.layout.placement.admit(root,game.layout.placement.Category.FLOOR_FURNITURE,bounds,owner,owner if assembly_id.is_empty() else assembly_id): return root
		if id in ["staff_desk","teacher_desk","broadcast_desk","av_bench","art_workbench","prep_island","laboratory_bench"]:
			game.box(Vector3(0,.81,0),Vector3(collision_size.x,.08,collision_size.z),"wood",true,root).hide()
			for x in [-1,1]:
				for z in [-1,1]: game.box(Vector3(x*(collision_size.x/2-.07),.39,z*(collision_size.z/2-.07)),Vector3(.05,.78,.05),"metal",true,root).hide()
		else:
			var body: MeshInstance3D=game.box(Vector3(0,collision_size.y*.5,0),collision_size,"wood",true,root)
			body.hide()
	return root

func floor_material(id: String) -> Material:
	if id=="G02": return surfaces.clinic_vinyl
	if id in ["G03","G05","G06","G08","U03","U04","U05"]: return surfaces.service_tile
	return game.materials.floor

func book_row(parent: Node3D,length: float,y: float,kind: String) -> void:
	var archive:=kind=="U06"
	var boxes_only:=kind=="G09"
	var equipment:=kind in ["G05","U05"]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new();rng.seed=int(y*1000+length*500+(1999 if archive else 15))
	var z: float=-length/2+.07
	var index:=0
	while z<length/2-.12:
		var box_style: bool=boxes_only or (archive and index%5==0)
		var width:=.28 if box_style else (rng.randf_range(.07,.11) if archive else rng.randf_range(.055,.16))
		if equipment: width=.19
		if z+width>length/2-.04: break
		if index%11==7: z+=.17;index+=1;continue
		var height:=.26 if box_style else (rng.randf_range(.29,.35) if archive else rng.randf_range(.22,.39))
		if equipment: height=.19
		var size:=Vector3(.43 if box_style else .38,height,width)
		var centre:=Vector3(rng.randf_range(-.015,.015),y+.025+height/2,z+width/2)
		var tile:=rng.randi_range(0,63)
		if box_style: tile=48+rng.randi_range(0,15)
		var offset:=Vector2(tile%8,tile/8)/8.0
		# One material/surface per shelf row; no per-book nodes or physics.
		var vertices: Array[Vector3]=[]
		for p in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(-1,1,-1),Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1)]: vertices.append(centre+p*size*.5)
		var faces: Array=[[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]]
		for face_index in range(faces.size()):
			var face: Array=faces[face_index]
			var uv: Array=[Vector2(0,1),Vector2(0,0),Vector2(1,0),Vector2(1,1)] if face_index in [0,3] else [Vector2(1,1),Vector2(0,1),Vector2(0,0),Vector2(1,0)]
			for corner in [0,1,2,0,2,3]:
				st.set_uv(offset+(Vector2(.03,.03) if face_index>=4 else Vector2(.015,.015)+uv[corner]*.97)/8)
				st.add_vertex(vertices[face[corner]])
		z+=width+rng.randf_range(.004,.02);index+=1
	st.generate_normals()
	var mesh:=MeshInstance3D.new();mesh.name="ArchivedFolders" if archive else "VariedBookRow"
	mesh.mesh=st.commit();mesh.material_override=book_materials.case if equipment else (book_materials.file if archive or boxes_only else book_materials.book)
	parent.add_child(mesh)

func representatives(layout: Node) -> void:
	var rooms: Dictionary=layout.room_roots
	model("teacher_desk",Vector3(8.50,0,.90),-PI/2,rooms.G01,Vector3(1.25,.84,.65))
	game.props.book(Vector3(8.50,.855,.90),rooms.G01,true)
	model("class_cubby",Vector3(15.70,0,6.55),PI/2,rooms.G01,Vector3(1.42,1.12,.42))
	game.props.chart("CLASS DUTY / 日直",Vector3(8.10,1.8,7.0),PI/2,rooms.G01,layout,.70)
	model("medicine_cabinet",Vector3(23.84,1.45,1.4),PI/2,rooms.G02)
	model("office_chair",Vector3(22.4,0,3.0),0,rooms.G02,Vector3(.55,.47,.55))
	model("bedside_stand",Vector3(20.3,0,5.5),0,rooms.G02,Vector3(.54,.70,.48))
	model("task_lamp",Vector3(22.85,.85,2.0),0,rooms.G02)
	game.props.chart("手洗い / HAND HYGIENE",Vector3(23.89,1.95,5.3),-PI/2,rooms.G02,layout,.8)
	game.props.chart("保健室 / HEALTH RECORD",Vector3(16.10,1.75,6.4),PI/2,rooms.G02,layout,.75)
	# Archive return ledger and supporting file storage, away from B3-12.
	model("flat_files",Vector3(9,0,35.35),0,rooms.U06,Vector3(1.4,.76,.60))
	for i in range(3): model("archive_box",Vector3(8.56+i*.44,.79,35.35),0,rooms.U06)
	model("task_lamp",Vector3(22.43,.85,33.35),0,rooms.U06)
	game.props.part(Vector3(21.75,.87,33.2),Vector3(.34,.025,.27),"wood",rooms.U06)
	game.props.chart("返却 / RETURNS",Vector3(8.10,1.8,34.2),PI/2,rooms.U06,layout,.70)
	for id in ["G01","U06"]:
		var root: Node3D=rooms[id]
		for sample in ([Vector3(14.88,.004,2.7),Vector3(12.73,.004,5.7)] if id=="G01" else [Vector3(22,.004,32.6)]): scuff(sample,root)

func scuff(point: Vector3,parent: Node3D) -> void:
	var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.65,.55);mesh.mesh=quad
	var mat:=StandardMaterial3D.new();mat.albedo_texture=load("res://assets/furniture/finish/textures/chair_scuffs.png")
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;mat.alpha_scissor_threshold=.04;mat.roughness=1;mat.metallic_specular=0
	mesh.material_override=mat;mesh.rotation.x=-PI/2;mesh.position=point;parent.add_child(mesh)

func curtain(parent: Node3D) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(40):
		for uv in [Vector2(i,0),Vector2(i+1,0),Vector2(i+1,1),Vector2(i,0),Vector2(i+1,1),Vector2(i,1)]:
			var z: float=.95+uv.x/40*2.1
			st.set_uv(Vector2(uv.x/40,uv.y))
			st.add_vertex(Vector3(19.25+sin(uv.x/40*TAU*9)*.035,.61+uv.y*2.2,z))
	st.generate_normals()
	var mesh:=MeshInstance3D.new();mesh.name="RailHungPrivacyCurtain";mesh.mesh=st.commit()
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("b4b8aa");mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=1;mat.metallic_specular=0
	mesh.material_override=mat;parent.add_child(mesh)
	# The visible cloth blocks sight, while bodies can push through it.
	var occlusion:=StaticBody3D.new();occlusion.name="CurtainSightOcclusion"
	occlusion.collision_layer=4;occlusion.collision_mask=0
	var collision:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=Vector3(.09,2.2,2.1)
	collision.shape=bounds;occlusion.add_child(collision);occlusion.position=Vector3(19.25,1.71,2)
	parent.add_child(occlusion)

func ceiling_joints(area: Rect2,parent: Node3D) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines: Array[Rect2]=[]
	var x: float=ceilf(area.position.x/1.2)*1.2
	while x<area.end.x:
		lines.append(Rect2(x-.003,area.position.y,.006,area.size.y));x+=1.2
	var z: float=ceilf(area.position.y/1.2)*1.2
	while z<area.end.y:
		lines.append(Rect2(area.position.x,z-.003,area.size.x,.006));z+=1.2
	for rect in lines:
		for uv in [Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2(0,1)]:
			st.set_normal(Vector3.DOWN);st.add_vertex(Vector3(rect.position.x+uv.x*rect.size.x,3.194,rect.position.y+uv.y*rect.size.y))
	var mesh:=MeshInstance3D.new();mesh.name="CeilingPanelJoints";mesh.mesh=st.commit();mesh.material_override=surfaces.ceiling_joint
	parent.add_child(mesh);mesh.add_to_group("audit_ceilings")

func complete_rooms(layout: Node) -> void:
	var r: Dictionary=layout.room_roots
	# Daily work, concentrated at the appropriate surfaces.
	flat_label("出席簿 / ATTENDANCE",Vector3(8.50,.89,.90),0,r.G01)
	for x in [22.1,22.25]:
		game.props.cylinder(Vector3(x,.89,1.9),.022,.075,"paper",r.G02)
		game.props.cylinder(Vector3(x,.933,1.9),.024,.012,"dark",r.G02)
	var height_chart: Node3D=game.props.group(Vector3(16.105,1.30,1.0),r.G02,"HeightChart")
	height_chart.rotation.y=PI/2
	game.props.part(Vector3.ZERO,Vector3(.24,1.12,.015),"paper",height_chart)
	for cm in range(80,181,10):
		game.props.part(Vector3(.07,cm/100.0-1.3,.010),Vector3(.06,.004,.002),"dark",height_chart)
		layout.text_surface(str(cm),Vector3(-.025,cm/100.0-1.3,.011),0,.018,Color("485044"),height_chart)
	game.props.cylinder(Vector3(23.4,.20,3.6),.14,.40,"metal",r.G02)
	model("office_phone",Vector3(30.35,.85,5.6),0,r.G03)
	model("task_lamp",Vector3(26.90,.85,2.7),PI/3,r.G03)
	# Borrowing/reading have separate work places; the two door approaches stay clear.
	model("nurse_station",Vector3(35.5,0,6.5),0,r.G04,Vector3(1.4,.84,.8),"G04 checkout")
	model("office_chair",Vector3(35.5,0,5.7),PI,r.G04,Vector3(.55,.47,.55),"G04 checkout")
	layout.seat(Vector3(39,0,2.5),-PI/2,r.G04)
	game.props.book(Vector3(35.9,.85,6.5),r.G04)
	game.props.book(Vector3(35.9,.89,6.5),r.G04)
	flat_label("返却 / RETURNS",Vector3(35.1,.853,6.5),0,r.G04)
	game.props.chart("機材管理 / EQUIPMENT",Vector3(40.10,1.85,4.9),PI/2,r.G05,layout,.8)
	model("prep_island",Vector3(43.1,0,4.4),PI,r.G05,Vector3(2.4,.84,.8))
	model("av_projector",Vector3(42.6,.85,4.4),0,r.G05)
	var spare: Node3D=model("archive_box",Vector3(43.6,.85,4.4),PI,r.G05)
	spare.scale=Vector3(1.3,1,1.3)
	# Maintenance storage occupies two functional wall bays, with a central work zone.
	supply_rack(Vector3(8.42,0,31.4),PI/2,r.G06)
	supply_rack(Vector3(10.8,0,30.4),0,r.G06)
	game.props.chart("清掃当番 / CLEANING ROTA",Vector3(8.105,1.9,33.2),PI/2,r.G06,layout,.85)
	game.props.part(Vector3(9.1,.004,34.8),Vector3(.20,.008,.20),"dark",r.G06)
	for i in range(5): game.props.part(Vector3(9.02+i*.04,.010,34.8),Vector3(.015,.004,.18),"metal",r.G06)
	model("common_bench",Vector3(19.5,0,35.5),0,r.G07,Vector3(1.8,.48,.52))
	model("water_dispenser",Vector3(23.35,0,34.3),0,r.G07,Vector3(.35,1.30,.35))
	game.props.chart("部活動 / CLUB NOTICE",Vector3(23.89,1.8,31.5),-PI/2,r.G07,layout,1.0)
	game.props.bag(Vector3(17.8,.02,33.2),r.G07)
	game.props.book(Vector3(18.0,.85,32.0),r.G07)
	flat_label("美術部 / ART CLUB",Vector3(18,.88,32),0,r.G07)
	# Packing remains at its original drawers, separate from the active making tables.
	for x in [28.3,31.3,35.0]: scuff(Vector3(x,.004,32.45),r.G08)
	empty_frame(Vector3(47.7,0,29.4),Vector2(1.15,1.55),PI/2,.14,r.G09)
	# Other classrooms use the same school kit with localized committee/personal context.
	for id in ["U01","U02"]:
		var x: float=15.70 if id=="U01" else 23.70
		model("class_cubby",Vector3(x,0,6.55),PI/2,r[id],Vector3(1.42,1.12,.42))
	game.props.book(Vector3(15.7,1.15,6.3),r.U01,true)
	game.props.chart("実行委員 / COMMITTEE",Vector3(8.10,1.8,7),PI/2,r.U01,layout,.8)
	for z in [6.0,6.4,6.8]:
		game.props.part(Vector3(15.88,1.65,z),Vector3(.008,.20,.24),"paper",r.U01)
		game.props.part(Vector3(15.87,1.76,z),Vector3(.012,.025,.06),"wood",r.U01)
	for point in [Vector3(27.1,.85,4.8),Vector3(29.4,.85,1.6)]: model("microscope",point,PI/5,r.U03)
	model("prep_island",Vector3(35.7,0,4.5),0,r.U04,Vector3(2.4,.84,.8))
	model("microscope",Vector3(35.3,.85,4.5),0,r.U04)
	game.props.trolley(Vector3(37.3,0,2.1),r.U04,true)
	game.props.book(Vector3(36.3,.85,4.5),r.U04,true)
	game.props.chart("理科準備 / INSTRUMENT RETURNS",Vector3(32.10,1.8,6.5),PI/2,r.U04,layout,1.1)
	model("headphones",Vector3(41.0,.85,1.3),0,r.U05)
	game.props.chart("放送 / BROADCAST SCHEDULE",Vector3(40.10,1.8,5.5),PI/2,r.U05,layout,1.1)
	for z in [1.5,6.8]: acoustic_panel(Vector3(40.11,1.9,z),PI/2,r.U05)
	# Three exhibition stations: preparation, the existing F-12 display, returned frames.
	game.props.chart("文化祭 / DISPLAY PREPARATION",Vector3(25.6,1.8,35.43),PI,r.U07,layout,1.2)
	for x in [31.18,32.82]:
		game.props.part(Vector3(x,1.35,35.72),Vector3(.055,2.7,.055),"wood",r.U07)
		game.props.part(Vector3(x,.04,35.65),Vector3(.34,.08,.44),"wood",r.U07)
	for x in [31.2,32.8]: game.props.part(Vector3(x,1.85,35.625),Vector3(.065,1.7,.06),"wood",r.U07)
	for y in [1.03,2.67]: game.props.part(Vector3(32,y,35.625),Vector3(1.66,.065,.06),"wood",r.U07)
	game.props.part(Vector3(37.8,.04,35.7),Vector3(1.8,.08,.50),"wood",r.U07)
	for i in range(3): empty_frame(Vector3(37.6+i*.13,.08,35.74-i*.045),Vector2(1.45,1.95),0,.08,r.U07)
	empty_frame(Vector3(46.6,0,35.65),Vector2(1.0,1.45),0,.12,r.U08)
	for z in [32.0,33.2]:
		var roll: MeshInstance3D=game.props.cylinder(Vector3(41.0,1.04,z),.11,.80,"paper",r.U08)
		roll.rotation.x=PI/2
	for y in [.97,1.05]: game.props.part(Vector3(47.1,y,34.1),Vector3(.43,.07,.62),"paper",r.U08)
	finish_common_routes(layout)

func flat_label(value: String,point: Vector3,yaw: float,parent: Node3D) -> void:
	var root: Node3D=game.props.group(point,parent,"PrintedLabel")
	root.rotation.y=yaw
	game.props.part(Vector3.ZERO,Vector3(.25,.003,.13),"paper",root)
	var lettering: Label3D=game.layout.text_surface(value,Vector3(0,.003,0),0,.016,Color("3d483b"),root)
	lettering.rotation.x=-PI/2

func empty_frame(point: Vector3,size: Vector2,yaw: float,lean: float,parent: Node3D) -> void:
	var root: Node3D=game.props.group(point,parent,"ReturnedDisplayFrame");root.rotation=Vector3(lean,yaw,0)
	for x in [-size.x/2,size.x/2]: game.props.part(Vector3(x,size.y/2,0),Vector3(.045,size.y,.04),"wood",root)
	for y in [.025,size.y-.025]: game.props.part(Vector3(0,y,0),Vector3(size.x,.045,.04),"wood",root)

func supply_rack(point: Vector3,yaw: float,parent: Node3D) -> void:
	var root: Node3D=game.props.group(point,parent,"CleaningSuppliesRack");root.rotation.y=yaw
	var bounds: AABB=root.global_transform*AABB(Vector3(-.8,0,-.23),Vector3(1.6,1.82,.46))
	var owner:=str(parent.name)+" supply rack "+str(point)
	if not game.layout.placement.admit(root,game.layout.placement.Category.FLOOR_FURNITURE,bounds,owner,owner): return
	game.box(Vector3(0,.9,0),Vector3(1.6,1.8,.46),"metal",true,root).hide()
	for x in [-.77,.77]:
		for z in [-.20,.20]: game.props.part(Vector3(x,.90,z),Vector3(.035,1.8,.035),"metal",root)
	for y in [.2,.72,1.24,1.78]:
		game.props.part(Vector3(0,y,0),Vector3(1.6,.035,.44),"metal",root)
		for x in [-.56,-.20,.20,.56]:
			game.props.cylinder(Vector3(x,y+.12,0),.065,.20,"paper",root)
			game.props.cylinder(Vector3(x,y+.23,0),.04,.025,"dark",root)

func acoustic_panel(point: Vector3,yaw: float,parent: Node3D) -> void:
	var root: Node3D=game.props.group(point,parent,"MountedAcousticPanel");root.rotation.y=yaw
	game.props.part(Vector3.ZERO,Vector3(.80,.95,.035),"dark",root)
	for x in range(10): game.props.part(Vector3(-.36+x*.08,0,.025),Vector3(.028,.88,.025),"chalk",root)

func finish_common_routes(layout: Node) -> void:
	for east in [false,true]:
		var root: Node3D=layout.get_node("EastStairs_Blue" if east else "WestStairs_Green")
		for x in [.75,5.65]:
			game.box(Vector3(layout.core_x(x,east),3,23),Vector3(.045,.045,1.7),"metal",true,root)
			game.box(Vector3(layout.core_x(x,east),2.55,23),Vector3(.045,.9,.045),"metal",true,root)
		game.box(Vector3(layout.core_x(3.15,east),5.1,18.82),Vector3(.6,.045,.045),"metal",true,root)
		for bridge in [[.875,.295],[5.575,.195]]: game.box(Vector3(layout.core_x(bridge[0],east),3,23.85),Vector3(bridge[1],.045,.045),"metal",true,root)
		# Battery-backed bulkheads supply two restrained landing landmarks.
		var fixture: Node3D=game.props.group(Vector3(layout.core_x(3.25,east),3.85,23.91),root,"BatteryLandingBulkhead")
		game.props.part(Vector3.ZERO,Vector3(.34,.15,.08),"metal",fixture)
		var lens: MeshInstance3D=game.props.part(Vector3(0,0,-.045),Vector3(.28,.095,.018),"paper",fixture)
		var lit:=StandardMaterial3D.new();lit.albedo_color=Color("8c9783");lit.emission_enabled=true;lit.emission=Color("40513e");lit.emission_energy_multiplier=.35;lit.roughness=.8
		lens.material_override=lit
		var pool:=OmniLight3D.new();pool.position=Vector3(0,-.08,-.28);pool.light_color=Color("a4b69c");pool.light_energy=.16;pool.omni_range=3.4;pool.shadow_enabled=false
		fixture.add_child(pool)
	var corridor: Node3D=layout.get_node("CorridorLoop_0")
	var speaker: Node3D=game.props.group(Vector3(42,2.50,8.16),corridor,"MountedSchoolSpeaker")
	game.props.part(Vector3.ZERO,Vector3(.28,.20,.10),"paper",speaker)
	for i in range(5): game.props.part(Vector3(0,-.06+i*.03,.055),Vector3(.21,.006,.004),"dark",speaker)
	game.props.part(Vector3(0,.40,-.05),Vector3(.016,.60,.016),"metal",speaker)
	var fire: Node3D=game.props.group(Vector3(19,0,8.23),corridor,"WallExtinguisher")
	game.props.cylinder(Vector3(0,1.0,0),.09,.38,"red",fire)
	game.props.part(Vector3(0,.79,-.045),Vector3(.24,.035,.16),"metal",fire)
	game.props.part(Vector3(0,1.21,0),Vector3(.12,.025,.05),"dark",fire)
	var hose: MeshInstance3D=game.hardware.tube(PackedVector3Array([Vector3(.04,1.20,0),Vector3(.13,1.11,0),Vector3(.13,.83,0)]),.013,fire)
	hose.material_override=game.materials.dark
	var upper: Node3D=layout.get_node("CorridorLoop_1")
	var clock: Node3D=game.props.group(Vector3(16,2.05,27.89),upper,"MountedLandingClock")
	var rim: MeshInstance3D=game.props.cylinder(Vector3.ZERO,.19,.06,"dark",clock);rim.rotation.x=PI/2
	var dial: MeshInstance3D=game.props.cylinder(Vector3(0,0,-.035),.17,.008,"paper",clock);dial.rotation.x=PI/2
	for digit in [["12",Vector3(0,.12,-.043)],["3",Vector3(-.12,0,-.043)],["6",Vector3(0,-.12,-.043)],["9",Vector3(.12,0,-.043)]]: layout.text_surface(digit[0],digit[1],PI,.022,Color("374039"),clock)
	var hour: MeshInstance3D=game.props.part(Vector3(.035,.025,-.047),Vector3(.085,.008,.004),"dark",clock);hour.rotation.z=.6
	game.props.part(Vector3(0,-.052,-.048),Vector3(.007,.105,.004),"dark",clock)
