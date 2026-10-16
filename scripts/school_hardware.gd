extends RefCounted
var game: Node
var locks: Array[Dictionary]=[]
var released: Array[bool]=[false,false,false,false]
var busy:=false

func tube(points: PackedVector3Array,radius: float,parent: Node3D) -> MeshInstance3D:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var tangent: Vector3=(points[i+1]-points[i]).normalized()
		var normal: Vector3=tangent.cross(Vector3.RIGHT if absf(tangent.dot(Vector3.FORWARD))>.9 else Vector3.FORWARD).normalized()
		var binormal: Vector3=tangent.cross(normal).normalized()
		for side in range(8):
			var a: float=side*TAU/8
			var b: float=(side+1)*TAU/8
			var v0: Vector3=(normal*cos(a)+binormal*sin(a))*radius
			var v1: Vector3=(normal*cos(b)+binormal*sin(b))*radius
			for p in [points[i]+v0,points[i+1]+v0,points[i+1]+v1,points[i]+v0,points[i+1]+v1,points[i]+v1]: st.add_vertex(p)
	st.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.mesh=st.commit()
	mesh.material_override=game.materials.metal
	parent.add_child(mesh)
	return mesh

func padlock(point: Vector3,yaw: float,parent: Node3D,index: int) -> Node3D:
	var root:=Node3D.new()
	root.position=point
	root.rotation.y=yaw
	parent.add_child(root)
	root.set_meta("placement_category","PUZZLE_OBJECT")
	# Separate plates bolt to each entrance leaf. The hinged strap bridges the seam.
	for x in [-.085,.085]:
		var plate: MeshInstance3D=game.box(Vector3(x,0,0),Vector3(.09,.065,.018),"metal",false,root)
		if x<0: plate.reparent(game.exit_panels[1],true)
		for dy in [-.018,.018]:
			var bolt: MeshInstance3D=game.box(Vector3(x,dy,.012),Vector3(.009,.009,.006),"dark",false,root)
			bolt.reparent(plate,true)
	var strap: MeshInstance3D=game.box(Vector3.ZERO,Vector3(.18,.032,.018),"metal",false,root)
	strap.position.z=.02
	var eye:=Node3D.new()
	root.add_child(eye)
	tube(PackedVector3Array([Vector3(-.012,-.018,.03),Vector3(-.012,-.018,.065),Vector3(.012,-.018,.065),Vector3(.012,-.018,.03)]),.006,eye)
	eye.reparent(game.exit_panels[1],true)
	var lock:=Node3D.new()
	lock.position=Vector3(0,-.065,.06)
	root.add_child(lock)
	var body: MeshInstance3D=game.box(Vector3.ZERO,Vector3(.085,.085,.038),"metal",false,lock)
	var keyway: MeshInstance3D=game.box(Vector3(0,-.012,.021),Vector3(.008,.017,.002),"dark",false,lock)
	var shackle:=Node3D.new()
	lock.add_child(shackle)
	var curve:=PackedVector3Array([Vector3(-.026,.032,0),Vector3(-.026,.064,0)])
	for i in range(13):
		var a: float=PI-i*PI/12
		curve.append(Vector3(cos(a)*.026,.064+sin(a)*.026,0))
	curve.append(Vector3(.026,.032,0))
	tube(curve,.006,shackle)
	game.box(Vector3(.065,-.045,.003),Vector3(.047,.035,.004),"paper",false,lock)
	var tag: Label3D=game.label3(["I","II","III","IV"][index],Vector3.ZERO,0,.0005,Color("42382d"))
	tag.reparent(lock,false)
	tag.position=Vector3(.065,-.045,.006)
	root.reparent(game.exit_panels[0],true)
	locks.append({"root":root,"lock":lock,"shackle":shackle,"strap":strap,"origin":lock.position})
	return root

func reset() -> void:
	released=[false,false,false,false]
	busy=false
	for item in locks:
		item.lock.show()
		item.lock.position=item.origin
		item.shackle.position=Vector3.ZERO

func release(index: int) -> void:
	if busy or released[index]: return
	busy=true
	var item: Dictionary=locks[index]
	game.world_sound("lock_turn",item.root.global_position,-14)
	var tw: Tween=game.create_tween()
	tw.tween_property(item.shackle,"position:y",.035,.22)
	tw.tween_callback(func(): game.world_sound("shackle_release",item.root.global_position,-16))
	tw.tween_property(item.lock,"position",item.origin+Vector3(.08,-.18,.12),.30)
	tw.tween_callback(func():
		released[index]=true
		item.lock.hide()
		busy=false
		if not game.checkpoint_state.is_empty():
			game.checkpoint_state.locks=released.duplicate()
			game.persist_voice_flags()
		pass)
