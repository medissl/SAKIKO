extends RefCounted
## Authored small assemblies. Coordinates are support surfaces, never mesh origins.
var game: Node

func part(point: Vector3,size: Vector3,mat: String,parent: Node3D) -> MeshInstance3D:
	return game.box(point,size,mat,false,parent)

func group(point: Vector3,parent: Node3D,title: String) -> Node3D:
	var root:=Node3D.new()
	root.name=title
	parent.add_child(root)
	root.position=point
	root.set_meta("placement_category","PUZZLE_OBJECT")
	return root

func cylinder(point: Vector3,radius: float,height: float,mat: String,parent: Node3D) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var mesh:=CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=16
	node.mesh=mesh
	node.material_override=game.materials[mat]
	node.position=point
	parent.add_child(node)
	return node

func book(point: Vector3,parent: Node3D,opened:=false) -> Node3D:
	var root:=group(point,parent,"ExerciseBook" if opened else "ReturnedBook")
	for side in [-1,1] if opened else [1]:
		var leaf:=group(Vector3(side*.095,.015,0),root,"Pages")
		leaf.rotation.z=side*.10 if opened else 0.0
		part(Vector3.ZERO,Vector3(.19,.025,.27),"paper",leaf)
		part(Vector3(0,-.016,0),Vector3(.20,.008,.28),"dark",leaf)
		if opened:
			for i in range(9): part(Vector3(0,.014,-.10+i*.023),Vector3(.145,.001,.0015),"dark",leaf)
	return root

func rounded_body(root: Node3D,width: float,height: float,depth: float) -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var loop: Array[Vector2]=[]
	for corner in range(4):
		var centre:=Vector2((1 if corner in [0,3] else -1)*(width/2-.035),(1 if corner<2 else -1)*(depth/2-.035))
		for i in range(5):
			var a: float=corner*PI/2+i*PI/8
			loop.append(centre+Vector2(cos(a),sin(a))*.035)
	# Explicit rounded corners in angular order.
	loop.clear()
	for i in range(32):
		var a: float=i*TAU/32
		loop.append(Vector2(signf(cos(a))*(width/2-.035)+cos(a)*.035,signf(sin(a))*(depth/2-.035)+sin(a)*.035))
	for i in range(loop.size()):
		var a: Vector2=loop[i]
		var b: Vector2=loop[(i+1)%loop.size()]
		for p in [Vector3(a.x,0,a.y),Vector3(b.x,0,b.y),Vector3(b.x,height,b.y),Vector3(a.x,0,a.y),Vector3(b.x,height,b.y),Vector3(a.x,height,a.y),Vector3(0,height,0),Vector3(a.x,height,a.y),Vector3(b.x,height,b.y)]: st.add_vertex(p)
	st.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.mesh=st.commit()
	mesh.material_override=game.materials.dark
	root.add_child(mesh)

func bag(point: Vector3,parent: Node3D) -> Node3D:
	var root:=group(point,parent,"HookedSchoolbag")
	rounded_body(root,.27,.28,.13)
	game.hardware.tube(PackedVector3Array([Vector3(-.05,.28,0),Vector3(-.05,.34,0),Vector3(.05,.34,0),Vector3(.05,.28,0)]),.009,root)
	for x in [-.075,.075]:
		part(Vector3(x,.13,.073),Vector3(.022,.22,.012),"wood",root)
		part(Vector3(x,.08,.083),Vector3(.032,.025,.008),"metal",root)
	return root

func pencil_case(point: Vector3,parent: Node3D) -> void:
	var root:=group(point,parent,"PencilCase")
	rounded_body(root,.19,.045,.075)
	for i in range(12): part(Vector3(-.08+i*.014,.047,0),Vector3(.004,.003,.008),"metal",root)
	part(Vector3(.08,.05,.012),Vector3(.025,.004,.012),"metal",root)

func cassette(point: Vector3,parent: Node3D) -> Node3D:
	var root:=group(point,parent,"FestivalCassette_F12")
	rounded_body(root,.20,.025,.13)
	part(Vector3(0,.027,.026),Vector3(.16,.002,.039),"paper",root)
	for x in [-.051,.051]:
		cylinder(Vector3(x,.029,-.020),.026,.004,"metal",root)
		cylinder(Vector3(x,.032,-.020),.011,.004,"dark",root)
	for x in [-.085,.085]:
		for z in [-.05,.05]: cylinder(Vector3(x,.028,z),.003,.003,"metal",root)
	return root

func trolley(point: Vector3,parent: Node3D,materials:=false) -> void:
	var root:=group(point,parent,"MaterialsTrolley" if materials else "BookReturnsTrolley")
	var collision: MeshInstance3D=game.box(Vector3(0,.4,0),Vector3(.8,.8,.42),"wood",true,root)
	collision.hide()
	game.layout.placement.admit(root,game.layout.placement.Category.FLOOR_FURNITURE,AABB(root.global_position-Vector3(.4,0,.21),Vector3(.8,.92,.42)),str(parent.name)+" trolley",str(parent.name)+" trolley")
	for y in [.18,.65]: part(Vector3(0,y,0),Vector3(.8,.035,.42),"wood",root)
	for x in [-.37,.37]:
		for z in [-.18,.18]:
			part(Vector3(x,.42,z),Vector3(.025,.72,.025),"metal",root)
			var wheel:=cylinder(Vector3(x,.075,z),.065,.035,"dark",root)
			wheel.rotation.z=PI/2
	game.hardware.tube(PackedVector3Array([Vector3(.37,.72,-.18),Vector3(.37,.90,-.18),Vector3(.37,.90,.18),Vector3(.37,.72,.18)]),.016,root)
	for i in range(3):
		if materials: cylinder(Vector3(-.22+i*.20,.76,0),.075,.18,"paper",root)
		else: book(Vector3(-.20+i*.20,.69,0),root)

func brushes(point: Vector3,parent: Node3D) -> void:
	var root:=group(point,parent,"BrushJar")
	cylinder(Vector3(0,.055,0),.041,.11,"glass",root)
	for i in range(5):
		var brush:=group(Vector3((i%3-1)*.014,.055,(i/3)*.013),root,"Brush")
		brush.rotation.z=(i-2)*.06
		part(Vector3(0,.10,0),Vector3(.005,.20,.005),"wood",brush)
		part(Vector3(0,.215,0),Vector3(.010,.038,.008),"dark",brush)

func kettle(point: Vector3,parent: Node3D) -> void:
	var root:=group(point,parent,"KettleCorner")
	cylinder(Vector3(0,.12,0),.105,.21,"metal",root)
	cylinder(Vector3(0,.23,0),.11,.025,"metal",root)
	cylinder(Vector3(0,.255,0),.027,.035,"dark",root)
	game.hardware.tube(PackedVector3Array([Vector3(-.09,.18,0),Vector3(-.17,.20,0),Vector3(-.17,.04,0),Vector3(-.09,.04,0)]),.016,root)
	game.hardware.tube(PackedVector3Array([Vector3(.09,.05,0),Vector3(.14,.11,0),Vector3(.18,.20,0)]),.023,root)
	for x in [.28,.45]: cylinder(Vector3(x,.045,0),.045,.09,"paper",root)

func sink(point: Vector3,parent: Node3D,yaw:=0.0) -> void:
	game.finishing.model("sink_station",point,yaw,parent,Vector3(.94,.87,.65))

func dress(layout: Node) -> void:
	var rooms: Dictionary=layout.room_roots
	# Student belongings attach to actual desks, with one player exercise book.
	for id in ["G01","U01","U02"]:
		var ox: float=layout.rooms[id].position.x
		for sample in [[1.75,1.2],[3.9,4.2],[6.05,2.7]]:
			var point:=Vector3(ox+sample[0],.85,sample[1])
			pencil_case(point,rooms[id])
			bag(point+Vector3(.12,-.43,.29),rooms[id])
			part(point+Vector3(.12,-.07,.29),Vector3(.018,.025,.10),"metal",rooms[id])
	book(Vector3(14.05,.85,2.7),rooms.G01,true).rotation.y=PI/2
	part(Vector3(8.30,1.35,3),Vector3(.11,.055,.065),"dark",rooms.G01)
	for z in [3.3,3.5]: part(Vector3(8.27,1.36,z),Vector3(.05,.014,.014),"paper",rooms.G01)
	# Staff work is concentrated around desks, not pasted across the window.
	for x in [26.2,29.8]:
		for i in range(4): part(Vector3(x+.35+i*.006,.849+i*.006,2.5),Vector3(.26,.004,.35),"paper",rooms.G03)
	layout.table(Vector3(31.35,0,6.6),Vector2(.65,1.5),rooms.G03)
	kettle(Vector3(31.30,.847,6.5),rooms.G03)
	chart("WEEKLY TIMETABLE",Vector3(24.10,1.75,5.4),PI/2,rooms.G03,layout)
	# Coats hang from a rail fixed to the solid side wall.
	part(Vector3(24.12,1.82,6.7),Vector3(.07,.10,1.0),"wood",rooms.G03)
	for z in [6.45,6.95]:
		part(Vector3(24.20,1.8,z),Vector3(.16,.025,.025),"metal",rooms.G03)
		part(Vector3(24.27,1.36,z),Vector3(.10,.70,.32),"dark",rooms.G03)
		part(Vector3(24.27,1.67,z),Vector3(.10,.10,.46),"dark",rooms.G03)
		for side in [-1,1]:
			var sleeve:=part(Vector3(24.27,1.46,z+side*.23),Vector3(.09,.43,.12),"dark",rooms.G03)
			sleeve.rotation.x=side*.22
		for y in [1.25,1.43,1.61]: part(Vector3(24.325,y,z),Vector3(.008,.012,.012),"metal",rooms.G03)
	# Sink and privacy screen are complete fittings, outside the bed access lane.
	sink(Vector3(23.43,0,5.3),rooms.G02,PI/2)
	game.hardware.tube(PackedVector3Array([Vector3(19.25,3.20,.95),Vector3(19.25,2.89,.95),Vector3(19.25,2.89,3.05),Vector3(19.25,3.20,3.05)]),.018,rooms.G02)
	for z in [1.1,1.45,1.8,2.15,2.5,2.85]:
		part(Vector3(19.25,2.72,z),Vector3(.025,.28,.025),"metal",rooms.G02)
	part(Vector3(20.3,.73,5.5),Vector3(.48,.015,.35),"metal",rooms.G02)
	# Library: two shelf aisles terminate at a window-side reading place.
	book(Vector3(38,.847,2.5),rooms.G04,true)
	trolley(Vector3(38.5,0,5.6),rooms.G04)
	part(Vector3(38.3,.875,2.8),Vector3(.045,.06,.045),"wood",rooms.G04)
	cylinder(Vector3(38.3,.93,2.8),.025,.04,"dark",rooms.G04)
	for x in [33.2,35.8]: chart("LITERATURE",Vector3(x,1.8,4.24),0,rooms.G04,layout,.40)
	# AV reel and labels have hardware silhouettes rather than plain boxes.
	var reel:=group(Vector3(41.8,1.06,1.3),rooms.G05,"CableReel")
	for z in [-.06,.06]:
		var disc:=cylinder(Vector3(0,0,z),.17,.025,"metal",reel)
		disc.rotation.x=PI/2
	for i in range(7):
		var loop:=TorusMesh.new()
		loop.inner_radius=.105
		loop.outer_radius=.125
		loop.rings=32;loop.ring_segments=8
		var wire:=MeshInstance3D.new()
		wire.mesh=loop
		wire.rotation.x=PI/2
		wire.position.z=-.045+i*.015
		wire.material_override=game.materials.dark
		reel.add_child(wire)
	cassette(Vector3(42.3,.85,1.3),rooms.G05)
	game.hardware.tube(PackedVector3Array([Vector3(41.8,.90,1.3),Vector3(40.75,.88,1.3),Vector3(40.73,.12,1.3),Vector3(40.3,.12,1.3),Vector3(40.18,.28,1.3),Vector3(40.145,.28,1.3)]),.012,rooms.G05)
	part(Vector3(40.105,.28,1.3),Vector3(.045,.10,.12),"paper",rooms.G05)
	part(Vector3(40.145,.28,1.3),Vector3(.04,.035,.035),"dark",rooms.G05)
	# Art workstations: cutting surfaces, jars, stains and drying rack.
	for x in [28.3,31.3,35.0]:
		part(Vector3(x,.846,31.6),Vector3(.60,.006,.42),"chalk",rooms.G08)
		for i in range(6): part(Vector3(x-.25+i*.10,.85,31.6),Vector3(.001,.001,.38),"paper",rooms.G08)
		brushes(Vector3(x+.48,.847,31.4),rooms.G08)
		for i in range(4): cylinder(Vector3(x-.5+i*.06,.846,31.95),.016+i*.006,.002,"chalk" if i%2 else "paper",rooms.G08)
	trolley(Vector3(31.25,0,29.45),rooms.G08,true)
	sink(Vector3(37.7,0,35.43),rooms.G08)
	chart("CULTURE FESTIVAL / F-12",Vector3(29.6,1.8,29.90),PI,rooms.G08,layout,1.7)
	for y in [.65,1.0,1.35,1.7]:
		part(Vector3(39.5,y,33.3),Vector3(.48,.008,2.3),"paper",rooms.G08)
	# Scenery shapes, rolled cloth and portrait scraps leave the middle lane open.
	for i in range(3):
		var roll:=cylinder(Vector3(41.4,.20+i*.22,35.4),.13,1.25,"paper",rooms.G09)
		roll.rotation.z=PI/2
	var arch: MeshInstance3D=game.hardware.tube(PackedVector3Array([Vector3(47,0,30),Vector3(47,1.7,30),Vector3(46.8,2.1,30),Vector3(46.4,2.25,30),Vector3(46.0,2.1,30),Vector3(45.8,1.7,30)]),.055,rooms.G09)
	for i in range(3): part(Vector3(41.8+i*.15,1.31,34.85),Vector3(.22,.004,.27),"paper",rooms.G09)
	# Ordinary personal detail at Sakiko's seat, no shrine or progression key.
	part(Vector3(22.05,.86,4.2),Vector3(.14,.008,.025),"red",rooms.U02)
	# Science sink/counter, chart, instrument cluster.
	var counter_collision: MeshInstance3D=game.box(Vector3(31.3,.42,3.5),Vector3(.85,.84,4.7),"metal",true,rooms.U03)
	counter_collision.hide()
	# Countertop strips surround actual recessed basins rather than a painted hole.
	for x in [30.955,31.645]: part(Vector3(x,.80,3.5),Vector3(.16,.08,4.7),"metal",rooms.U03)
	for z in [1.15,2.5,4.45,5.85]: part(Vector3(31.3,.80,z),Vector3(.55,.08,.30),"metal",rooms.U03)
	for x in [30.95,31.65]:
		for z in [1.3,3.5,5.7]: part(Vector3(x,.39,z),Vector3(.045,.78,.045),"metal",rooms.U03)
	for z in [1.5,3.5,5.4]:
		part(Vector3(31.3,.64,z),Vector3(.50,.025,.50),"metal",rooms.U03)
		for x in [-.25,.25]: part(Vector3(31.3+x,.73,z),Vector3(.025,.18,.52),"metal",rooms.U03)
		for dz in [-.25,.25]: part(Vector3(31.3,.73,z+dz),Vector3(.52,.18,.025),"metal",rooms.U03)
		cylinder(Vector3(31.3,.656,z),.027,.003,"dark",rooms.U03)
		game.hardware.tube(PackedVector3Array([Vector3(31.6,.84,z),Vector3(31.6,1.25,z),Vector3(31.35,1.25,z)]),.018,rooms.U03)
		game.hardware.tube(PackedVector3Array([Vector3(31.3,.63,z),Vector3(31.3,.32,z),Vector3(31.94,.32,z)]),.022,rooms.U03)
	chart("LAB SAFETY / EYE PROTECTION",Vector3(24.10,2.1,6.3),PI/2,rooms.U03,layout,1.5)
	for x in [26.8,27.1,27.4]: cylinder(Vector3(x,.96,1.6),.035,.22,"glass",rooms.U03)
	# Media microphone, reels and clearly oriented mixing surface.
	var mic:=group(Vector3(42.9,.85,1.68),rooms.U05,"MicrophoneStand")
	cylinder(Vector3(0,.015,0),.11,.03,"dark",mic)
	cylinder(Vector3(0,.24,0),.012,.45,"metal",mic)
	var capsule:=cylinder(Vector3(0,.48,-.025),.035,.16,"dark",mic)
	capsule.rotation.x=PI/2
	game.finishing.model("broadcast_mixer",Vector3(42.6,.85,1.3),0,rooms.U05)
	game.hardware.tube(PackedVector3Array([Vector3(42.9,.88,1.68),Vector3(42.7,.87,1.63),Vector3(42.6,.87,1.58),Vector3(42.6,.96,1.54)]),.009,rooms.U05)
	part(Vector3(42.6,.96,1.525),Vector3(.025,.025,.035),"dark",rooms.U05)
	for room_id in ["G05","U05"]:
		chart("F-12 / FESTIVAL TAPES",Vector3(47.895,1.65,6.5),-PI/2,rooms[room_id],layout,.55)
	# Utility rack and supplies use the rear/side walls, leaving the centre free.
	part(Vector3(11.5,1.45,35.72),Vector3(1.6,.09,.08),"wood",rooms.G06)
	for x in [11,11.5,12]: part(Vector3(x,1.45,35.63),Vector3(.09,.06,.18),"metal",rooms.G06)
	var bucket:=group(Vector3(12.7,0,35.1),rooms.G06,"CleaningBucket")
	for inside in [false,true]:
		var shell:=MeshInstance3D.new()
		var shape:=CylinderMesh.new()
		shape.top_radius=.18 if inside else .19
		shape.bottom_radius=.13 if inside else .14
		shape.height=.35;shape.radial_segments=20
		shape.cap_top=false;shape.cap_bottom=false
		shape.flip_faces=inside
		shell.mesh=shape;shell.material_override=game.materials.metal
		shell.position.y=.18;bucket.add_child(shell)
	cylinder(Vector3(0,.025,0),.135,.015,"dark",bucket)
	var handle:=PackedVector3Array()
	for i in range(13):
		var a: float=i*PI/12
		handle.append(Vector3(cos(a)*.18,.34+sin(a)*.20,0))
	game.hardware.tube(handle,.008,bucket)
	for z in [32.1,32.5,32.9]: cylinder(Vector3(15.3,2.1,z),.065,.20,"paper",rooms.G06)
	# Archive vestibule return counter is clear of both door tracks.
	layout.table(Vector3(13.3,0,29.4),Vector2(1.8,.60),rooms.U06)
	book(Vector3(22,.85,33.2),rooms.U06,true)
	for x in [21.7,22.3]: part(Vector3(x,.86,33.4),Vector3(.18,.025,.25),"wood",rooms.U06)
	# Faded exhibition bunting follows the rear wall, above the viewing space.
	for i in range(10):
		var flag:=PrismMesh.new()
		flag.size=Vector3(.20,.26,.008)
		var pennant:=MeshInstance3D.new()
		pennant.mesh=flag
		pennant.material_override=game.materials.paper
		pennant.position=Vector3(25+i*1.3,2.7,35.75)
		pennant.rotation.z=PI
		rooms.U07.add_child(pennant)
	# Rehearsal: folded cardigan and absent-scenery dust edges, not debris.
	game.finishing.model("folded_cardigan",Vector3(44.95,.46,34.4),0,rooms.U08)
	for x in [42.7,46.4]:
		for z in [30.0,31.1]: part(Vector3(x,.003,z),Vector3(.75,.002,.025),"dark",rooms.U08)
	chart("FESTIVAL / 1999",Vector3(47.90,1.9,29.8),-PI/2,rooms.U08,layout,.9)
	# Sun-faded rectangle and screw holes left by a removed sign, on solid wall.
	var old_sign:=group(Vector3(42.5,1.95,27.895),rooms.U08,"RemovedSignOutline")
	part(Vector3.ZERO,Vector3(.82,.28,.006),"chalk",old_sign)
	for x in [-.36,.36]:
		for y in [-.09,.09]: part(Vector3(x,y,-.005),Vector3(.009,.009,.004),"dark",old_sign)
	layout.placement.admit(old_sign,layout.placement.Category.SOLID_WALL_MOUNT,AABB(old_sign.global_position-Vector3(.41,.14,.004),Vector3(.82,.28,.008)),"U08 removed sign outline")
	for x in [42.0,47.0]:
		part(Vector3(x,.12,27.88),Vector3(1.8,.18,.025),"wood",rooms.U08)
		for i in range(4): part(Vector3(x-.6+i*.33,.12+(i%2)*.025,27.862),Vector3(.15,.008,.003),"chalk",rooms.U08)
	# Ordinary student paintings are mounted only on the common/art solid walls.
	for i in range(2): painting(Vector3(18.4+i*2.0,1.9,35.88),PI,rooms.G07,layout,i)
	painting(Vector3(24.12,1.9,32.6),PI/2,rooms.G08,layout,2)
	# Entrance shoe zone: slippers, umbrella stand and a bench parallel to lockers.
	for z in [10.4,10.6]:
		var slipper:=group(Vector3(3.2,-.12,z),rooms.G10,"ForgottenIndoorSlipper")
		rounded_body(slipper,.25,.035,.09)
		part(Vector3(-.04,.055,0),Vector3(.10,.04,.09),"paper",slipper)
	var stand:=group(Vector3(.7,-.12,14.7),rooms.G10,"UmbrellaRack")
	for x in [-.25,.25]:
		for z in [-.18,.18]: part(Vector3(x,.35,z),Vector3(.025,.70,.025),"metal",stand)
	part(Vector3(0,.06,0),Vector3(.6,.04,.46),"dark",stand)
	for i in range(3):
		game.hardware.tube(PackedVector3Array([Vector3(-.18+i*.18,.08,0),Vector3(-.18+i*.18,.85,0),Vector3(-.12+i*.18,.90,0),Vector3(-.07+i*.18,.85,0)]),.009,stand)

func chart(text: String,point: Vector3,yaw: float,parent: Node3D,layout: Node,width:=.8) -> void:
	var root:=group(point,parent,"Mounted_"+text)
	root.rotation.y=yaw
	part(Vector3.ZERO,Vector3(width,.50,.02),"paper",root)
	for x in [-width*.44,width*.44]:
		for y in [-.21,.21]: part(Vector3(x,y,-.025),Vector3(.012,.012,.05),"metal",root)
	layout.text_surface(text,Vector3(0,.13,.012),0,.033,Color("343b36"),root)
	var body: String={"CLASS DUTY / 日直":"日直 / MON - FRI\n窓・黒板を確認\nLeave the board clean.","手洗い / HAND HYGIENE":"石けん → 指の間 → 流水\nSOAP / FINGERS / RINSE\n清潔なタオル","保健室 / HEALTH RECORD":"健康記録 / DAILY CARE\nReturn clean linen to storage.\nKeep the bedside clear.","返却 / RETURNS":"返却は受付へ / RETURN TO DESK\nKeep the original order.\nDo not refile loose pages.","LAB SAFETY / EYE PROTECTION":"保護眼鏡 / EYE PROTECTION\nWash hands after practical work.\nReturn instruments dry.","WEEKLY TIMETABLE":"職員連絡 / STAFF NOTICES\nMON - FRI / DAILY HANDOVER\nReturn keys to the cabinet.","LITERATURE":"文学 / FICTION\nREADING / RETURNS","F-12 / FESTIVAL TAPES":"文化祭 / EQUIPMENT RETURNS\nStore tapes in their cases.","CULTURE FESTIVAL / F-12":"乾燥棚 / DRYING RACK\n作品は平らに / STORE FLAT","FESTIVAL / 1999":"SCENERY STORAGE / RETURN\nKeep the doorways clear."}.get(text,"掲示 / SCHOOL NOTICE\nReturn borrowed equipment.")
	if not body.begins_with("掲示 / SCHOOL NOTICE"):
		layout.text_surface(body,Vector3(0,-.055,.013),0,.025,Color("424b40"),root)
	var bounds: AABB=root.global_transform*AABB(Vector3(-width/2,-.25,-.01),Vector3(width,.50,.02))
	layout.placement.admit(root,layout.placement.Category.SOLID_WALL_MOUNT,bounds,str(parent.name)+" chart "+text)

func painting(point: Vector3,yaw: float,parent: Node3D,layout: Node,index: int) -> void:
	var root:=group(point,parent,"StudentArtwork_"+str(index))
	root.rotation.y=yaw
	part(Vector3.ZERO,Vector3(.71,.93,.035),"wood",root)
	var surface:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(.65,.87)
	surface.mesh=quad
	surface.position.z=.019
	var paper:=StandardMaterial3D.new()
	paper.albedo_texture=load("res://assets/environment/generated/student_art_atlas.png")
	paper.uv1_scale=Vector3(1.0/3,1,1)
	paper.uv1_offset=Vector3(index/3.0,0,0)
	paper.roughness=1
	paper.metallic_specular=0
	surface.material_override=paper
	root.add_child(surface)
	var bounds: AABB=root.global_transform*AABB(Vector3(-.355,-.465,-.02),Vector3(.71,.93,.04))
	layout.placement.admit(root,layout.placement.Category.SOLID_WALL_MOUNT,bounds,str(parent.name)+" student artwork "+str(index))
