extends Node3D
## One authoritative layout. Rectangles are usable footprints, floor heights 0/4.2 m.
const FLOOR_HEIGHT := 4.2
const SEATED := Vector3(14.88,0,2.7)
const NIGHT := Vector3(15.46,0,2.7)
const EXIT_TARGET := Vector3(.19,1.4,12)
const CORRIDORS := [Rect2(8,8,40,4),Rect2(8,24,40,4),Rect2(8,12,4,12),Rect2(44,12,4,12)]
const ROOM_DATA := [
 ["G01","1-A",Rect2(8,0,8,8),[9.5,14.5],0],
 ["G02","保健室 / INFIRMARY",Rect2(16,0,8,8),[21.5],0],
 ["G03","職員室 / STAFF",Rect2(24,0,8,8),[29.0],0],
 ["G04","図書室 / LIBRARY",Rect2(32,0,8,8),[33.5,38.5],0],
 ["G05","視聴覚室 / AV",Rect2(40,0,8,8),[45.0],0],
 ["G06","用具室 / UTILITY",Rect2(8,28,8,8),[13.0],0],
 ["G07","談話室 / COMMON",Rect2(16,28,8,8),[18.0,22.0],0],
 ["G08","美術室 / ART",Rect2(24,28,16,8),[26.0,38.0],0],
 ["G09","倉庫 / SCENERY",Rect2(40,28,8,8),[45.0],0],
 ["U01","2-A",Rect2(8,0,8,8),[9.5,14.5],1],
 ["U02","2-B",Rect2(16,0,8,8),[17.5,22.5],1],
 ["U03","理科室 / SCIENCE",Rect2(24,0,8,8),[25.5,30.5],1],
 ["U04","準備室 / PREPARATION",Rect2(32,0,8,8),[37.0],1],
 ["U05","放送室 / BROADCAST",Rect2(40,0,8,8),[45.0],1],
 ["U06","資料室 / ARCHIVE",Rect2(8,28,16,8),[10.0,22.0],1],
 ["U07","文化祭展示 / EXHIBITION",Rect2(24,28,16,8),[26.0,38.0],1],
 ["U08","旧練習室 / REHEARSAL",Rect2(40,28,8,8),[45.0],1]]
const PATROL := [Vector3(10,1.5,10),Vector3(46,1.5,10),Vector3(46,1.5,26),Vector3(10,1.5,26),Vector3(10,5.7,10),Vector3(46,5.7,10),Vector3(46,5.7,26),Vector3(10,5.7,26)]
var placement=preload("res://scripts/school_placement.gd").new()
var exterior: Node3D
var game: Node
var room_roots := {}
var room_doors := {}
var rooms := {}
var room_floors := {}
var lesson_mesh: Label3D
var seats: Array[Vector3] = []
var inspection_lights: Array[OmniLight3D] = []
var windows: Array[MeshInstance3D] = []
var stair_routes: Array[PackedVector3Array] = []
var measured := {}
var rehearsal_door: Dictionary

func unit(title: String) -> Node3D:
	var root:=Node3D.new()
	root.name=title
	add_child(root)
	return root

func block(point: Vector3,size: Vector3,mat: String,root: Node3D,solid:=true) -> MeshInstance3D:
	return game.box(point,size,mat,solid,root)

func floor_area(area: Rect2,root: Node3D) -> void:
	var floor_mesh:=block(Vector3(area.get_center().x,-.15,area.get_center().y),Vector3(area.size.x,.3,area.size.y),"floor",root)
	floor_mesh.material_override=game.finishing.floor_material(str(root.name))
	floor_mesh.set_meta("step_surface","tile" if str(root.name) in ["G02","G03","G05","G06","G08","U03","U04","U05"] else "wood")
	var ceiling:=block(Vector3(area.get_center().x,3.3,area.get_center().y),Vector3(area.size.x,.2,area.size.y),"ceiling",root)
	ceiling.add_to_group("audit_ceilings")
	game.finishing.ceiling_joints(area,root)

func wall_x(x: float,z0: float,z1: float,root: Node3D) -> void:
	placement.solid(AABB(root.to_global(Vector3(x-.08,0,z0)),Vector3(.16,3.2,z1-z0)))
	block(Vector3(x,1.6,(z0+z1)/2),Vector3(.16,3.2,z1-z0),"wall",root)
	block(Vector3(x,.075,(z0+z1)/2),Vector3(.19,.15,z1-z0),"wood",root,false)
	block(Vector3(x,3.14,(z0+z1)/2),Vector3(.21,.10,z1-z0),"paper",root,false)

func wall_z(z: float,x0: float,x1: float,root: Node3D) -> void:
	if x1-x0>.015:
		placement.solid(AABB(root.to_global(Vector3(x0,0,z-.08)),Vector3(x1-x0,3.2,.16)))
		block(Vector3((x0+x1)/2,1.6,z),Vector3(x1-x0,3.2,.16),"wall",root)
		block(Vector3((x0+x1)/2,.075,z),Vector3(x1-x0,.15,.19),"wood",root,false)
		block(Vector3((x0+x1)/2,3.14,z),Vector3(x1-x0,.10,.21),"paper",root,false)

func text_surface(value: String,point: Vector3,yaw: float,height: float,tint: Color,root: Node3D) -> Label3D:
	# Printed surface lettering: complex CJK outlines need no extruded geometry.
	var instance:=Label3D.new()
	instance.text=value
	instance.font=game.font
	instance.font_size=48
	instance.pixel_size=height/48.0
	instance.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	instance.outline_size=0
	instance.modulate=tint
	instance.shaded=true
	instance.no_depth_test=false
	instance.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	instance.alpha_cut=Label3D.ALPHA_CUT_DISCARD
	instance.position=point
	instance.rotation.y=yaw
	root.add_child(instance)
	return instance

func plaque(value: String,point: Vector3,yaw: float,root: Node3D,width:=1.3) -> void:
	var assembly:=Node3D.new()
	assembly.position=point
	assembly.rotation.y=yaw
	root.add_child(assembly)
	block(Vector3.ZERO,Vector3(width,.27,.025),"dark",assembly,false)
	text_surface(value,Vector3(0,0,.014),0,.065,Color("b0aa95"),assembly)
	var bounds: AABB=assembly.global_transform*AABB(Vector3(-width/2,-.135,-.015),Vector3(width,.27,.03))
	placement.admit(assembly,placement.Category.SOLID_WALL_MOUNT,bounds,str(root.name)+" sign "+value)

func window_strip(point: Vector3,width: float,yaw: float,root: Node3D,exterior:=false) -> void:
	var assembly:=Node3D.new()
	assembly.position=point
	assembly.rotation.y=yaw
	root.add_child(assembly)
	block(Vector3(0,.43,0),Vector3(width,.86,.16),"wall",assembly)
	block(Vector3(0,2.94,0),Vector3(width,.52,.16),"wall",assembly)
	var glass:=block(Vector3(0,1.76,0),Vector3(width-.12,1.78,.025),"glass",assembly)
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color(.32,.43,.43,.13)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness=.3
	mat.metallic_specular=.16
	glass.material_override=mat
	windows.append(glass)
	for x in [-width/2,0,width/2]: block(Vector3(x,1.76,0),Vector3(.065,1.84,.10),"wood",assembly)
	for y in [.86,1.76,2.67]: block(Vector3(0,y,0),Vector3(width,.055,.10),"wood",assembly,false)
	block(Vector3(0,.86,.025),Vector3(width+.04,.055,.26),"wood",assembly,false)
	block(Vector3(0,.075,0),Vector3(width,.15,.19),"wood",assembly,false)
	var opening: AABB=assembly.global_transform*AABB(Vector3(-width/2,.88,-.13),Vector3(width,1.78,.26))
	placement.reserve("window",opening,str(root.name)+" glazing "+str(point))
	assembly.set_meta("placement_category","WINDOW_ASSEMBLY")

func build_geometry(g: Node) -> void:
	game=g
	for level in range(2):
		var y: float=level*FLOOR_HEIGHT
		var corridor:=unit("CorridorLoop_"+str(level))
		corridor.position.y=y
		for area in CORRIDORS: floor_area(area,corridor)
		# All corner joins are floor, not dividing walls.
		for x in [8.0,48.0]:
			wall_x(x,12,16,corridor) if x==48 else wall_x(x,14,16,corridor)
		wall_x(48,8,12,corridor)
		wall_x(48,24,28,corridor)
		wall_x(8,24,28,corridor)
		# West lobby/alcove connects at Z=13, never through a solid wall.
		wall_x(8,8,12,corridor)
		for x in [14,18,22,26,30,34,38,42]:
			window_strip(Vector3(x,0,12),4,PI,corridor,true)
			window_strip(Vector3(x,0,24),4,0,corridor,true)
		for z in [14,18,22]:
			window_strip(Vector3(12,0,z),4,-PI/2,corridor,true)
			window_strip(Vector3(44,0,z),4,PI/2,corridor,true)
		for point in [Vector3(10,y+2.95,10),Vector3(46,y+2.95,10),Vector3(46,y+2.95,26),Vector3(10,y+2.95,26)]:
			game.lamp(point,.65 if level==0 else .40,Color("8b9c99"))
		build_lobby(level)
	for data in ROOM_DATA:
		var id: String=data[0]
		var area: Rect2=data[2]
		var level: int=data[4]
		var y: float=level*FLOOR_HEIGHT
		var root:=unit(id)
		root.position.y=y
		room_roots[id]=root
		rooms[id]=area
		room_floors[id]=level
		floor_area(area,root)
		var north: bool=area.position.y<8
		var front: float=7.4 if id=="G04" else (8.0 if north else 28.0)
		var back: float=0 if north else 36
		if area.position.x==8: wall_x(8,area.position.y,area.end.y,root)
		wall_x(area.end.x,area.position.y,area.end.y,root)
		if north: window_strip(Vector3(area.get_center().x,0,back),area.size.x,0,root,true)
		else: wall_z(back,area.position.x,area.end.x,root)
		var cursor: float=area.position.x
		room_doors[id]=[]
		var centres: Array=data[3]
		if id=="G04":
			wall_x(32,7.4,8,root)
			wall_x(40,7.4,8,root)
		if id=="G08":
			wall_x(32,28,30,root)
		for i in range(centres.size()):
			var cx: float=centres[i]
			var door_z: float=30.0 if id=="G08" and i==0 else (28.65 if id=="U06" and i==0 else front)
			var segment_end: float=32.0 if id=="G08" and i==0 else area.end.x
			if id=="G04" and i==1:
				wall_z(door_z,cursor,35.65,root)
				window_strip(Vector3(36,0,door_z),.7,0,root)
				wall_z(door_z,36.35,cx-1.08,root)
			else: wall_z(door_z,cursor,cx-1.08,root)
			var header:=block(Vector3(cx,2.96,door_z),Vector3(2.16,.48,.16),"wall",root)
			placement.solid(header.global_transform*header.get_aabb())
			game.make_door(Vector3(cx,y,door_z),-1 if north else 1)
			var door: Dictionary=game.doors.back()
			door.node.name=id+"_Door_"+str(i+1)
			door.slide_direction=1.0 if i==0 else -1.0
			door.room=id
			door.north=north
			room_doors[id].append(door)
			if id=="U08": rehearsal_door=door
			var requirements: Dictionary={"G05":"festival","G09":"festival","U06":"archive","U07":"archive","U05":"media","U08":"rehearsal_U08"}
			door.requirement=requirements.get(id,"")
			door.locked=not door.requirement.is_empty()
			var gate_label: String={"festival":"FESTIVAL STORE KEY","archive":"ARCHIVE COLLECTION KEY","media":"MEDIA ROOM KEY","rehearsal_U08":"U08 ACCESS KEY"}.get(door.requirement,"")
			door.lock_label=gate_label
			plaque(data[1],Vector3(cx,2.95,door_z+(.091 if north else -.091)),0 if north else PI,root)
			var travel_x: float=cx+(.55 if i==0 else -.55)
			placement.reserve("aisle",AABB(Vector3(cx-.75,y,door_z-1.3),Vector3(1.5,2.2,2.6)),str(door.node.name)+" approach")
			placement.reserve("door",AABB(Vector3(cx-1,y,door_z-.17),Vector3(2,2.72,.34)),str(door.node.name))
			placement.reserve("panel_travel",AABB(Vector3(travel_x-1.6,y,door_z+(-.42 if north else .10)),Vector3(3.2,2.72,.32)),str(door.node.name))
			if id=="G08" and i==0:
				wall_z(30,cx+1,32,root)
				cursor=32
			elif id=="U06" and i==0:
				wall_z(28.65,cx+1,12,root)
				wall_x(12,28,28.65,root)
				cursor=12
			else: cursor=cx+1.08
		wall_z(front,cursor,area.end.x,root)
		game.lamp(Vector3(area.get_center().x,y+2.95,area.get_center().y),.50 if level==0 else .30,Color("919c94"))
		var neutral:=OmniLight3D.new()
		neutral.position=Vector3(area.get_center().x,2.7,area.get_center().y)
		neutral.light_energy=2
		neutral.omni_range=12
		neutral.light_color=Color("e5e2d7")
		neutral.hide()
		root.add_child(neutral)
		inspection_lights.append(neutral)
	build_stairs(false)
	build_stairs(true)
	var court:=unit("FacadeBands")
	exterior=preload("res://scripts/school_exterior.gd").new()
	exterior.name="SharedExteriorDiorama"
	add_child(exterior)
	exterior.build(game)
	for z in [0,36]: block(Vector3(28,3.7,z),Vector3(40,1,.16),"wall",court)
	for x in [8,48]:
		for z in [4,32]: block(Vector3(x,3.7,z),Vector3(.16,1,8),"wall",court)
	block(Vector3(0,3.7,12),Vector3(.16,1,8),"wall",court)
	# Courtyard spandrels close the structural band between the two storeys.
	for z in [12,24]: block(Vector3(28,3.7,z),Vector3(32,1,.16),"wall",court)
	for x in [12,44]: block(Vector3(x,3.7,18),Vector3(.16,1,12),"wall",court)

func build_lobby(level: int) -> void:
	var root:=unit("G10_Lobby" if level==0 else "U10_InformationLanding")
	root.position.y=level*FLOOR_HEIGHT
	room_roots["G10" if level==0 else "U10"]=root
	if level==0:
		var tiles:=block(Vector3(2,-.23,12),Vector3(4,.20,8),"wall",root)
		tiles.set_meta("step_surface","tile")
		block(Vector3(6,-.15,12),Vector3(4,.30,8),"floor",root)
		# A real shallow timber threshold bevel makes the 13 cm genkan rise walkable.
		var angle: float=atan2(.13,.4)
		var threshold:=block(Vector3(3.8,-.065-.02*cos(angle),12),Vector3(sqrt(.4*.4+.13*.13),.04,7.8),"wood",root)
		threshold.rotation.z=angle
		var ceiling:=block(Vector3(4,3.3,12),Vector3(8,.2,8),"ceiling",root)
		ceiling.add_to_group("audit_ceilings")
		for z in range(16): block(Vector3(2,-.124,8.25+z*.5),Vector3(3.9,.003,.009),"dark",root,false)
		for x in range(8): block(Vector3(.25+x*.5,-.124,12),Vector3(.009,.003,7.9),"dark",root,false)
	else: floor_area(Rect2(0,8,8,8),root)
	wall_z(8,0,8,root)
	wall_z(16,0,8,root)
	if level==1: wall_x(0,8,16,root)
	else:
		wall_x(0,8,11,root)
		wall_x(0,13,16,root)
		var lintel:=block(Vector3(0,3.02,12),Vector3(.16,.36,2),"wall",root)
		placement.solid(lintel.global_transform*lintel.get_aabb())
		for i in [-1,1]: game.exit_panels.append(block(Vector3(-.02,1.4,12+i*.5),Vector3(.10,2.8,.98),"metal",root))
		for i in range(4): game.entrance_locks.append(game.hardware.padlock(Vector3(.13,.65+i*.35,12),PI/2,root,i))
		plaque("玄関 / EXIT",Vector3(.13,3.0,12),PI/2,root,1.5)
		var outside:=unit("ExteriorEscapeArea")
		block(Vector3(-2,-.28,12),Vector3(4,.3,4),"floor",outside)
		for z in [9.9,14.1]: block(Vector3(-2,.6,z),Vector3(4,1.2,.1),"metal",outside)

	game.lamp(Vector3(4,level*4.2+2.9,12),.9,Color("a2b1a5"))

func core_x(local_x: float,east: bool) -> float:
	return 56-local_x if east else local_x

func build_stairs(east: bool) -> void:
	var root:=unit("EastStairs_Blue" if east else "WestStairs_Green")
	root.set_meta("dynamic_nav",true)
	var tint:=StandardMaterial3D.new()
	tint.albedo_color=Color("34464d") if east else Color("3e4e40")
	tint.roughness=1
	for x in [0,8]:
		if x==8:
			for zspan in [[16.0,18.0],[20.0,24.0]]:
				var wall:=block(Vector3(core_x(x,east),3.7,(zspan[0]+zspan[1])/2),Vector3(.16,7.4,zspan[1]-zspan[0]),"wall",root)

			block(Vector3(core_x(x,east),3.7,19),Vector3(.16,1,2),"wall",root)
		else:
			for zspan in [[16.0,18.0],[22.0,24.0]]: block(Vector3(core_x(0,east),3.7,(zspan[0]+zspan[1])/2),Vector3(.16,7.4,zspan[1]-zspan[0]),"wall",root)
			for level in range(2):
				var glazing:=unit("StairExteriorGlazing")
				glazing.position.y=level*4.2
				window_strip(Vector3(core_x(0,east),0,20),4,PI/2 if not east else -PI/2,glazing,true)
			block(Vector3(core_x(0,east),3.7,20),Vector3(.16,1,4),"wall",root)
	placement.solid(AABB(Vector3(core_x(8,east)-.08,0,20),Vector3(.16,7.4,4)))
	# Both lower stair entrances are physical doors; the upper exits stay ordinary.
	game.make_door(Vector3(core_x(8,east),0,19),1)
	var gate: Dictionary=game.doors.back()
	gate.node.rotation.y=PI/2
	gate.room="STAIR_E" if east else "STAIR_W"
	gate.slide_direction=1.0
	gate.requirement="upper"
	gate.lock_label="UPPER WING KEY / CLOSED"
	gate.locked=true
	placement.reserve("headroom",AABB(Vector3(core_x(5.8,east),0,18.8) if not east else Vector3(48,0,18.8),Vector3(2.2,2.5,1.2)),str(gate.room))

	block(Vector3(core_x(4,east),3.7,24),Vector3(8,7.4,.16),"wall",root)
	block(Vector3(core_x(4,east),3.7,16),Vector3(8,1,.16),"wall",root)
	block(Vector3(core_x(4,east),-.15,20),Vector3(8,.3,8),"floor",root)
	var roof:=block(Vector3(core_x(4,east),7.5,20),Vector3(8,.2,8),"ceiling",root)
	roof.add_to_group("audit_ceilings")
	# Actual upper slab openings: only the arrival landing and side connector exist.
	block(Vector3(core_x(4,east),4.1,17.4),Vector3(8,.2,2.8),"floor",root)
	block(Vector3(core_x(7,east),4.1,19.4),Vector3(2,.2,1.2),"floor",root)
	block(Vector3(core_x(3.25,east),2.0,23.08),Vector3(5.1,.2,1.84),"floor",root)
	for flight in range(2):
		var cx: float=4.6 if flight==0 else 1.8
		var start_y: float=0 if flight==0 else 2.1
		for i in range(12):
			var z: float=18.8+(i+.5)*.28 if flight==0 else 22.16-(i+.5)*.28
			var y: float=start_y+(i+1)*.175
			block(Vector3(core_x(cx,east),y-.0875,z),Vector3(2.2,.175,.28),"wood",root,false)
			# Pale non-emissive nosing catches the reflected window moonlight.
			block(Vector3(core_x(cx,east),y+.002,z+(-.125 if flight==0 else .125)),Vector3(2.08,.006,.025),"paper",root,false)
		var angle: float=-atan2(2.1,3.36) if flight==0 else atan2(2.1,3.36)
		var ramp:=block(Vector3(core_x(cx,east),start_y+1.05-.04*cos(angle),20.48-.04*sin(angle)),Vector3(2.2,.08,sqrt(3.36*3.36+2.1*2.1)),"metal",root)
		ramp.set_meta("step_surface","stair")
		ramp.rotation.x=angle
		ramp.hide()
		for edge in [-1,1]:
			var rail:=block(Vector3(core_x(cx+edge*1.05,east),start_y+1.95,20.48),Vector3(.045,.045,sqrt(3.36*3.36+2.1*2.1)),"metal",root)
			rail.rotation.x=angle
			for i in range(5):
				var t: float=i/4.0
				var z: float=18.8+t*3.36 if flight==0 else 22.16-t*3.36
				block(Vector3(core_x(cx+edge*1.05,east),start_y+t*2.1+.45,z),Vector3(.045,.90,.045),"metal",root)
	# The turn landing and upper opening have visible guardrails.
	for x in [1.0,3.25,5.5]: block(Vector3(core_x(x,east),2.55,23.85),Vector3(.045,.9,.045),"metal",root)
	block(Vector3(core_x(3.25,east),3.0,23.85),Vector3(4.5,.045,.045),"metal",root)
	block(Vector3(core_x(4.6,east),5.1,18.82),Vector3(2.3,.045,.045),"metal",root)
	for level in [0,1]:
		game.lamp(Vector3(core_x(6.8,east),level*4.2+2.9,18.2),.7,Color("7a929e") if east else Color("81917d"))
		plaque(("EAST / 東階段" if east else "WEST / 西階段")+"  "+str(level+1)+"F",Vector3(core_x(7.86,east),level*4.2+2.45,22.0),PI/2 if east else -PI/2,root,1.7)
	for y in [.6,4.8]:
		var coating:=block(Vector3(core_x(.085,east),y-.2,20),Vector3(.006,.8,8),"wall",root,false)
		coating.material_override=tint
		for span in [[17.0,2.0],[22.0,4.0]]:
			coating=block(Vector3(core_x(7.915,east),y,span[0]),Vector3(.006,1.2,span[1]),"wall",root,false)
			coating.material_override=tint
		for z in [16.085,23.915]:
			coating=block(Vector3(core_x(4,east),y,z),Vector3(8,1.2,.006),"wall",root,false)
			coating.material_override=tint
	if east:
		for y in [1.7,5.9]:
			var poster:=MeshInstance3D.new()
			var paper:=QuadMesh.new()
			paper.size=Vector2(.44,.62)
			poster.mesh=paper
			var mat:=StandardMaterial3D.new()
			mat.albedo_texture=load("res://assets/story/documents/rendered/program.png")
			mat.roughness=1
			mat.metallic_specular=0
			poster.material_override=mat
			poster.position=Vector3(55.91,y,17.5)
			poster.rotation=Vector3(0,-PI/2,.02)
			root.add_child(poster)
	var route:=PackedVector3Array()
	for point in [Vector3(7,0,19),Vector3(6.8,0,17.8),Vector3(4.6,0,18.3)]: route.append(Vector3(core_x(point.x,east),point.y,point.z))
	for i in range(13): route.append(Vector3(core_x(4.6,east),i*.175,18.8+i*.28))
	for point in [Vector3(4.6,2.1,23.0),Vector3(1.8,2.1,23.0)]: route.append(Vector3(core_x(point.x,east),point.y,point.z))
	for i in range(13): route.append(Vector3(core_x(1.8,east),2.1+i*.175,22.16-i*.28))
	for point in [Vector3(1.8,4.2,18.3),Vector3(6.8,4.2,18.2),Vector3(6.8,4.2,19),Vector3(7.5,4.2,19)]: route.append(Vector3(core_x(point.x,east),point.y,point.z))
	stair_routes.append(route)

func allowed_position(point: Vector3) -> bool:
	var level: int=roundi(point.y/4.2)
	var flat:=Vector2(point.x,point.z)
	if level==0 and Rect2(24,28,8,2).has_point(flat): return true
	for area in CORRIDORS:
		if area.grow(.01).has_point(flat): return true
	if Rect2(0,8,8,8).has_point(flat): return true
	for id in rooms:
		if room_floors[id]==level and rooms[id].has_point(flat): return true
	# Navigation excludes the void/opening under stair flights; ordered ramp nodes
	# are linked separately, with exactly the same elevations as the collision ramps.
	for east in [false,true]:
		var local_x: float=56-point.x if east else point.x
		if Rect2(.9,16.4,6.4,2.35).has_point(Vector2(local_x,point.z)): return true
		if Rect2(6.2,18,1.8,2).has_point(Vector2(local_x,point.z)): return true
	return false

func table(point: Vector3,size: Vector2,root: Node3D) -> void:
	var assembly:=Node3D.new()
	assembly.position=point
	root.add_child(assembly)
	var owner: String=str(root.name)+" table "+str(point)
	if not placement.admit(assembly,placement.Category.FLOOR_FURNITURE,AABB(assembly.global_position-Vector3(size.x/2,0,size.y/2),Vector3(size.x,.84,size.y)),owner,owner): return
	block(Vector3(0,.80,0),Vector3(size.x,.08,size.y),"wood",assembly)
	for x in [-1,1]:
		for z in [-1,1]: block(Vector3(x*(size.x-.14)/2,.39,z*(size.y-.14)/2),Vector3(.045,.78,.045),"metal",assembly)

func cabinet(point: Vector3,size: Vector3,root: Node3D,yaw:=0.0) -> void:
	var assembly:=Node3D.new()
	root.add_child(assembly)
	assembly.position=point
	assembly.rotation.y=yaw
	var bounds: AABB=assembly.global_transform*AABB(-size*.5,size)
	if not placement.admit(assembly,placement.Category.FLOOR_FURNITURE,bounds,str(root.name)+" cabinet "+str(point),str(root.name)+" cabinet "+str(point)): return
	var skin: String="filecabinet" if str(root.name) in ["G03","G06","U04"] else "wood"
	block(Vector3.ZERO,size,skin,assembly)
	for x in [-.25,.25]:
		block(Vector3(x*size.x,0,-size.z/2-.021),Vector3(size.x*.47,size.y-.06,.025),skin,assembly,false)
		block(Vector3(x*size.x,0,-size.z/2-.043),Vector3(.07,.17,.025),"metal",assembly,false)

func shelf(point: Vector3,length: float,root: Node3D) -> void:
	var assembly:=Node3D.new()
	assembly.position=point
	root.add_child(assembly)
	var owner: String=str(root.name)+" shelf "+str(point)
	if not placement.admit(assembly,placement.Category.FLOOR_FURNITURE,AABB(assembly.global_position-Vector3(.275,0,length/2),Vector3(.55,2.2,length)),owner,owner): return
	for z in [-length/2,length/2]:
		var end_panel:=block(Vector3(0,1.1,z),Vector3(.55,2.2,.05),"wood",assembly)
		placement.solid(end_panel.global_transform*end_panel.get_aabb())
	for y in [.18,.72,1.28,1.86]:
		block(Vector3(0,y,0),Vector3(.55,.05,length),"wood",assembly)
		game.finishing.book_row(assembly,length,y,str(root.name))
		if str(root.name)=="U06": text_surface(str(1996+int(y/.54)),Vector3(0,y+.09,length/2+.028),0,.034,Color("716956"),assembly)


func build_furniture() -> void:
	for id in ["G01","U01","U02"]: classroom(id)
	for id in ["G10","U10"]:
		var root: Node3D=room_roots[id]
		if id=="G10":
			for z in [8.4,15.6]:
				var side:=1.0 if z<12 else -1.0
				var body:=block(Vector3(4.4,.95,z),Vector3(5.8,1.9,.45),"wood",root)
				body.hide()
				block(Vector3(4.4,.95,z-side*.20),Vector3(5.8,1.9,.035),"wood",root,false)
				for column in range(8): block(Vector3(1.5+column*(5.8/7),.95,z),Vector3(.025,1.9,.45),"wood",root,false)
				for y in [.02,.63,1.26,1.89]: block(Vector3(4.4,y,z),Vector3(5.8,.025,.45),"wood",root,false)
				for column in range(7):
					for row in range(3):
						var x: float=1.5+(column+.5)*(5.8/7)
						var y: float=.31+row*.63
						if column==2 and row==1:
							for dx in [-.11,.11]: block(Vector3(x+dx,.68,z),Vector3(.13,.055,.28),"dark",root,false)
							continue
						block(Vector3(x,y,z+side*.23),Vector3(.78,.57,.025),"wood",root,false)
						block(Vector3(x+.28,y,z+side*.25),Vector3(.022,.085,.018),"metal",root,false)
			block(Vector3(5.1,.44,14.7),Vector3(2.3,.06,.55),"wood",root)
			for x in [-.95,.95]: block(Vector3(5.1+x,.215,14.7),Vector3(.06,.43,.44),"metal",root)
		directory(Vector3(3.8,1.9,8.10),0,root,0 if id=="G10" else 1)
	var staff: Node3D=room_roots.G03
	for x in [26.2,29.8]:
		for z in [2.5,5.7]: game.finishing.model("staff_desk",Vector3(x,0,z),PI,staff,Vector3(1.8,.84,.85),"Staff workstation "+str(Vector2(x,z)))
	for z in [1.3,3.0]: cabinet(Vector3(24.45,1.05,z),Vector3(1.3,2.1,.6),staff,-PI/2)
	var library: Node3D=room_roots.G04
	for x in [33.2,35.8]: shelf(Vector3(x,0,3.0),2.4,library)
	table(Vector3(38,0,2.5),Vector2(1.35,1.7),library)
	var av: Node3D=room_roots.G05
	game.finishing.model("av_bench",Vector3(41.8,0,1.25),PI,av,Vector3(2,.84,.85))
	shelf(Vector3(47.4,0,4.8),2.6,av)
	game.finishing.model("office_chair",Vector3(42.15,0,2.4),0,room_roots.U05,Vector3(.55,.47,.55))
	for x in [26.2,29.8]:
		for z in [2.5,5.7]: game.finishing.model("office_chair",Vector3(x+.55,0,z+.83),0,staff,Vector3(.55,.47,.55),"Staff workstation "+str(Vector2(x,z)))
	var art: Node3D=room_roots.G08
	for x in [28.3,31.3,35.0]:
		game.finishing.model("art_workbench",Vector3(x,0,31.6),0,art,Vector3(2.2,.84,1.2))
		for dx in [-.42,.42]:
			game.finishing.model("art_stool",Vector3(x+dx,0,32.45),0,art)
	table(Vector3(30,0,34.7),Vector2(2.3,.9),art)
	for y in [.6,1.0,1.4,1.8]: block(Vector3(39.5,y,33.3),Vector3(.5,.035,2.5),"metal",art,false)
	var sick: Node3D=room_roots.G02
	for z in [2.0,5.4]:
		game.finishing.model("clinic_bed",Vector3(18,0,z),0,sick,Vector3(1.45,.76,2.1))
	game.finishing.model("nurse_station",Vector3(22.4,0,2),PI,sick,Vector3(1.4,.84,.8))
	game.finishing.curtain(sick)
	var storage: Node3D=room_roots.G09
	shelf(Vector3(40.6,0,30.5),3.5,storage)
	shelf(Vector3(47.5,0,32.8),2.3,storage)
	block(Vector3(41.6,.65,34.85),Vector3(2.2,1.3,1.7),"paper",storage)
	var utility: Node3D=room_roots.G06
	game.props.sink(Vector3(9,0,35.43),utility)
	for x in [11,11.5,12.0]:
		block(Vector3(x,1,35.6),Vector3(.035,1.85,.035),"wood",utility,false)
		block(Vector3(x,.12,35.6),Vector3(.27,.12,.14),"paper",utility,false)
	cabinet(Vector3(15.4,1,32.7),Vector3(.65,2,2.2),utility)
	var common: Node3D=room_roots.G07
	for x in [18.0,21.8]:
		table(Vector3(x,0,32),Vector2(1.4,1.3),common)
		for z in [30.8,33.2]:
			seat(Vector3(x,0,z),0 if z<32 else PI,common)
	table(Vector3(22.8,0,35.3),Vector2(1.3,.65),common)
	var science: Node3D=room_roots.U03
	for x in [27.1,29.4]:
		for z in [1.6,4.8]: game.finishing.model("laboratory_bench",Vector3(x,0,z),0,science,Vector3(1.3,.84,1.3))
	game.finishing.model("demo_bench",Vector3(24.8,0,3.7),-PI/2,science,Vector3(3,.84,.8))
	var prep: Node3D=room_roots.U04
	for z in [1.3,3.3,5.3]: cabinet(Vector3(39.5,1,z),Vector3(1.5,2,.6),prep,PI/2)
	game.finishing.model("demo_bench",Vector3(33,0,4),-PI/2,prep,Vector3(3,.84,.8))
	var media: Node3D=room_roots.U05
	game.finishing.model("broadcast_desk",Vector3(42,0,1.3),PI,media,Vector3(2.4,.84,1))
	shelf(Vector3(47.4,0,3),3.5,media)
	var archive: Node3D=room_roots.U06
	for x in [9.3,12.3,16.3,19.3]:
		shelf(Vector3(x,0,32.0),3.4,archive)
		plaque("B"+str([9.3,12.3,16.3,19.3].find(x)+1),Vector3(x,1.92,33.74),0,archive,.35)
	table(Vector3(22,0,33.2),Vector2(1.35,1.7),archive)
	var exhibition: Node3D=room_roots.U07
	for x in [25.6]:
		var panel:=block(Vector3(x,1.15,35.55),Vector3(1.4,2.3,.18),"wood",exhibition)
		placement.solid(panel.global_transform*panel.get_aabb())
		plaque("文化祭 / 1999",Vector3(x,2.05,35.43),PI,exhibition,1.2)
	var rehearsal: Node3D=room_roots.U08
	# The student bag rests on an ordinary storage bench, not attached legs.
	block(Vector3(45.6,.425,34.4),Vector3(1.8,.07,.65),"wood",rehearsal)
	for x in [44.9,46.3]: block(Vector3(x,.195,34.4),Vector3(.06,.39,.55),"metal",rehearsal)
	for x in [41.0,47.1]:
		var outer: float=-1 if x<44 else 1
		block(Vector3(x+outer*.28,1.1,33.2),Vector3(.04,2.2,3.6),"wood",rehearsal)
		for z in [31.43,34.97]: block(Vector3(x-outer*.27,1.1,z),Vector3(.045,2.2,.045),"metal",rehearsal)
		for y in [.2,.9,1.7]: block(Vector3(x,y,33.2),Vector3(.60,.05,3.6),"metal",rehearsal)
	for x in [42.4,43.0]:
		for level in range(3):
			var carton: Node3D=game.finishing.model("archive_box",Vector3(x,level*.30,35.3),0,rehearsal)
			carton.scale=Vector3(1,.30/.3025,1.5)

func classroom(id: String) -> void:
	var root: Node3D=room_roots[id]
	var origin: Vector2=rooms[id].position
	var floor_y: float=room_floors[id]*4.2
	# Measured imported pair is ~1.40 m deep. 4x5 would remove teaching/rear
	# circulation; 3x4 preserves ~0.75 m row access and a 1.88 m south route.
	for x in [1.75,3.9,6.05]:
		for z in [1.2,2.7,4.2,5.7]:
			var point:=Vector3(origin.x+x,floor_y,origin.y+z)
			var pair: Node3D=game.desk(point,PI/2)
			pair.reparent(root,true)
			if id=="G01": seats.append(point+Vector3(.83,0,0))
	block(Vector3(origin.x+.13,2.03,origin.y+4),Vector3(.05,1.35,4.2),"chalk",root,false)
	block(Vector3(origin.x+.21,1.32,origin.y+4),Vector3(.18,.05,4.3),"wood",root,false)
	var writing:=text_surface("LITERATURE / 15 OCTOBER\n\nDescribe a familiar place.",Vector3(origin.x+.161,2.08,origin.y+4),PI/2,.10,Color("787f71"),root)
	if id=="G01": lesson_mesh=writing
	if id=="U02":
		block(Vector3(22.15,1.0,1.22),Vector3(.26,.32,.17),"dark",root,false)
		block(Vector3(22.05,.86,1.38),Vector3(.18,.035,.08),"wood",root,false)
		block(Vector3(21.95,.85,.99),Vector3(.22,.018,.25),"paper",root,false)

func directory(point: Vector3,yaw: float,root: Node3D,level: int) -> void:
	var assembly:=Node3D.new()
	assembly.position=point
	assembly.rotation.y=yaw
	root.add_child(assembly)
	block(Vector3.ZERO,Vector3(2.6,1.25,.035),"wood",assembly,false)
	var value: String="1F   NORTH: 1-A / INFIRMARY / STAFF / LIBRARY / AV\n\nSOUTH: UTILITY / COMMON / ART / SCENERY STORE\nWEST: ENTRANCE + GREEN STAIRS   EAST: BLUE STAIRS"
	if level==1: value="2F   NORTH: 2-A / 2-B / SCIENCE / PREP / BROADCAST\n\nSOUTH: ARCHIVE / EXHIBITION / REHEARSAL\nGREEN STAIRS WEST   BLUE STAIRS EAST   BOTH TO 1F"
	text_surface(value,Vector3(0,0,.020),0,.063,Color("ada694"),assembly)

func seat(point: Vector3,yaw: float,root: Node3D) -> void:
	placement.grounded_asset(game.chair_asset,root,point,yaw,.91)
	var collision:=block(point+Vector3(0,.43,0),Vector3(.50,.10,.50),"wood",root)
	collision.hide()
