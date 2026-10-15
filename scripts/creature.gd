extends CharacterBody3D
## Sculpted parametric skull with real mouth opening, concave cavity and hinged teeth.
var rig: Node3D
var jaw: Node3D
var locks: Array[Node3D] = []
var age := 0.0
var scare := 0.0

func material(c: Color, rough := .95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 24
	mesh.rings = 16
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.scale = size
	n.position = pos
	n.material_override = mat
	parent.add_child(n)
	return n

func surface(parent: Node3D, vertices: PackedVector3Array, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in vertices: st.add_vertex(p)
	st.generate_normals()
	var n := MeshInstance3D.new()
	n.mesh = st.commit()
	n.material_override = mat
	parent.add_child(n)
	return n

func face_z(x: float,y: float) -> float:
	var z := -.78*sqrt(maxf(.015,1-pow(x/1.02,2)-pow((y-.12)/1.19,2)))
	# Brow, cheeks and a tapered projecting bridge are sculpted into the skull.
	z -= .14*exp(-pow((absf(x)-.55)/.31,2)-pow((y+.05)/.33,2))
	z -= .10*exp(-pow((absf(x)-.45)/.38,2)-pow((y-.62)/.12,2))
	z += .15*exp(-pow((absf(x)-.43)/.25,2)-pow((y-.39)/.19,2))
	z -= .15*exp(-pow(x/.14,2)-pow((y-.23)/.33,2))
	z -= .17*exp(-pow(x/.19,2)-pow((y-.03)/.13,2))
	return z

func mouth_point(a: float,r: float,depth := 0.0) -> Vector3:
	var x := cos(a)*.82*r
	# Corners turn up into the unnatural grin.
	var y := -.43+sin(a)*.37*r+.16*pow(absf(cos(a)),3)*r
	return Vector3(x,y,face_z(x,y)-.012+depth)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .8
	shape.shape = sphere
	add_child(shape)
	rig = Node3D.new()
	add_child(rig)
	var skin := material(Color("b4b6ac"))
	var skin_shader := Shader.new()
	skin_shader.code = "shader_type spatial; render_mode cull_disabled; void fragment(){float n=fract(sin(dot(floor(VERTEX*110.0),vec3(12.9,78.2,36.1)))*43758.5); ALBEDO=vec3(.62,.64,.60)*(0.86+n*.14); ROUGHNESS=.97;}"
	var flesh := ShaderMaterial.new()
	flesh.shader = skin_shader
	var black := material(Color("040506"))
	var eye := material(Color("040406"),.75)
	var lip := material(Color("453033"))
	var teeth := material(Color("b8b2a0"))
	var vertices := PackedVector3Array()
	var cols := 112
	var rows := 72
	for row in range(rows):
		for col in range(cols):
			var quad: Array[Vector3] = []
			var omit := false
			for uv in [Vector2(col,row),Vector2(col+1,row),Vector2(col+1,row+1),Vector2(col,row+1)]:
				var lat: float = .015+(uv.y/rows)*(PI-.03)
				var lon: float = uv.x/cols*TAU
				var x := 1.02*sin(lat)*sin(lon)
				var y := .12+1.19*cos(lat)
				var z := -.78*sin(lat)*cos(lon)
				if cos(lon)>0:
					z = face_z(x,y)
					var my := (y+.43-.16*pow(absf(x/.82),3))/.37
					if pow(x/.82,2)+my*my<.99: omit = true
				quad.append(Vector3(x,y,z))
			if not omit:
				for i in [0,2,1,0,3,2]: vertices.append(quad[i])
	surface(rig,vertices,flesh)
	# Concave black mouth bowl goes INTO the head. A rim hides the skull opening.
	vertices.clear()
	for i in range(96):
		var a := float(i)/96*TAU
		var b := float(i+1)/96*TAU
		for ring in range(6):
			var r1 := 1.04-float(ring)/6*1.04
			var r2 := 1.04-float(ring+1)/6*1.04
			var p1 := mouth_point(a,r1,.64*(1-r1*r1))
			var p2 := mouth_point(b,r1,.64*(1-r1*r1))
			var p3 := mouth_point(b,r2,.64*(1-r2*r2))
			var p4 := mouth_point(a,r2,.64*(1-r2*r2))
			for p in [p1,p2,p3,p1,p3,p4]: vertices.append(p)
	surface(rig,vertices,black)
	vertices.clear()
	for i in range(96):
		var a := float(i)/96*TAU
		var b := float(i+1)/96*TAU
		for p in [mouth_point(a,1.11,-.008),mouth_point(b,1.11,-.008),mouth_point(b,.98,-.02),mouth_point(a,1.11,-.008),mouth_point(b,.98,-.02),mouth_point(a,.98,-.02)]: vertices.append(p)
	surface(rig,vertices,lip)
	# Deep dark eyes with small wet highlights, sunk into the sculpted brow.
	for side in [-1.0,1.0]:
		var x: float = side*.43
		ellipsoid(rig,Vector3(x,.39,face_z(x,.39)-.015),Vector3(.58,.44,.12),lip)
		ellipsoid(rig,Vector3(x,.39,face_z(x,.39)-.046),Vector3(.49,.36,.07),eye)
		ellipsoid(rig,Vector3(x-.045,.44,face_z(x,.39)-.085),Vector3(.023,.018,.008),skin)
		ellipsoid(rig,Vector3(side*.085,-.018,-1.075),Vector3(.052,.028,.018),black)
	jaw = Node3D.new()
	jaw.position = Vector3(0,-.48,-.10)
	rig.add_child(jaw)
	# Lower lip and chin travel with the teeth, preserving a solid jaw silhouette.
	vertices.clear()
	for i in range(48):
		var a := PI+float(i)/48*PI
		var b := PI+float(i+1)/48*PI
		var p1 := mouth_point(a,1.02,-.01)
		var p2 := mouth_point(b,1.02,-.01)
		var p3 := mouth_point(b,1.14,.06)+Vector3(0,-.12,0)
		var p4 := mouth_point(a,1.14,.06)+Vector3(0,-.12,0)
		for p in [p1,p2,p3,p1,p3,p4]: vertices.append(p-jaw.position)
	surface(jaw,vertices,flesh)
	for i in range(13):
		var x := float(i-6)*.116
		var t := x/.82
		var top_y := -.43+.37*sqrt(maxf(0,1-t*t))+.16*pow(absf(t),3)
		var bottom_y := -.43-.37*sqrt(maxf(0,1-t*t))+.16*pow(absf(t),3)
		var height := .105+fmod(i*.047,.065)
		for upper in [true,false]:
			var tooth := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(.083+fmod(i*.017,.015),height,.085)
			tooth.mesh = mesh
			tooth.material_override = teeth
			var y := top_y-height*.42 if upper else bottom_y+height*.42
			tooth.position = Vector3(x,y,face_z(x,y)-.025)
			tooth.rotation.z = sin(i*13.0)*.12
			if upper: rig.add_child(tooth)
			else:
				tooth.position -= jaw.position
				jaw.add_child(tooth)
	# Hair cap: irregular scalp shell, followed by thin tapered, curved mesh locks.
	ellipsoid(rig,Vector3(0,.65,.21),Vector3(2.16,1.44,1.72),black)
	for i in range(112):
		var a := float(i)/112*TAU
		var front := cos(a)>.5
		var root := Node3D.new()
		root.position = Vector3(sin(a)*1.01,.94,-cos(a)*.76)
		rig.add_child(root)
		var length := .23+fmod(i*.137,.33) if front else 1.65+fmod(i*.213,.55)
		var width := .055+fmod(i*.034,.045)
		vertices.clear()
		for seg in range(9):
			var f1 := float(seg)/9
			var f2 := float(seg+1)/9
			var pts: Array[Vector3] = []
			for pair in [Vector2(-1,f1),Vector2(1,f1),Vector2(1,f2),Vector2(-1,f2)]:
				var f: float = pair.y
				var center := Vector3(sin(a)*(.04+sin(f*PI)*.06),-length*f,cos(a)*(.015-f*.04))
				center.x += sin(f*4+i)*.018
				pts.append(center+Vector3(cos(a),0,sin(a))*pair.x*width*(1-f*.92))
			for idx in [0,1,2,0,2,3]: vertices.append(pts[idx])
		surface(root,vertices,black)
		locks.append(root)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0,.25,-1.5)
	fill.light_color = Color("879d9e")
	fill.light_energy = .13
	fill.omni_range = 2.8
	rig.add_child(fill)

func _process(delta: float) -> void:
	age += delta
	if not is_instance_valid(rig): return
	rig.position.y = sin(age*1.4)*.065
	rig.rotation.z = sin(age*.79)*.04+scare*.17
	rig.rotation.x = sin(age*.53)*.02
	jaw.rotation.x = -.02-scare*.20
	jaw.position.y = -.48-scare*.10
	for i in range(locks.size()): locks[i].rotation.x = sin(age*1.8+i)*.024
