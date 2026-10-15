extends CharacterBody3D
## A continuous face annulus, matching concave mouth and closed rear skull.
var rig: Node3D
var age := 0.0
var scare := 0.0

func profile(y: float) -> Vector3:
	var sections := [Vector4(1.34,.01,.02,.02),Vector4(1.22,.54,.32,.43),Vector4(1.02,.83,.47,.64),Vector4(.75,.98,.62,.77),Vector4(.40,1.00,.65,.76),Vector4(.15,1.04,.74,.70),Vector4(-.12,.99,.77,.62),Vector4(-.40,.92,.70,.52),Vector4(-.68,.81,.62,.41),Vector4(-.92,.65,.59,.28),Vector4(-1.08,.36,.48,.13),Vector4(-1.13,.01,.19,.04)]
	for i in range(sections.size()-1):
		var a: Vector4 = sections[i]
		var b: Vector4 = sections[i+1]
		if y<=a.x and y>=b.x:
			var t := smoothstep(a.x,b.x,y)
			return Vector3(lerpf(a.y,b.y,t),lerpf(a.z,b.z,t),lerpf(a.w,b.w,t))
	return Vector3(.01,.02,.02)

func face_z(x: float,y: float) -> float:
	var p := profile(y)
	var z := -p.y*sqrt(maxf(0.0,1-pow(x/maxf(.01,p.x),2)))
	z -= .045*exp(-pow((absf(x)-.57)/.28,2)-pow((y+.06)/.28,2))
	z += .055*exp(-pow((absf(x)-.43)/.25,2)-pow((y-.39)/.17,2))
	z -= .075*exp(-pow(x/.15,2)-pow((y-.20)/.30,2))
	z -= .13*exp(-pow(x/.19,2)-pow((y+.10)/.13,2))
	return z

func mouth(a: float) -> Vector3:
	var x := cos(a)*.70
	var y := -.62+sin(a)*.28+.35*pow(absf(cos(a)),3)
	return Vector3(x,y,face_z(x,y))

func contour(a: float) -> Vector3:
	var y := clampf(.105+1.235*sin(a),-1.13,1.34)
	var x := profile(y).x*(1 if cos(a)>=0 else -1)
	if absf(cos(a))<.0001: x=0
	return Vector3(x,y,0)

func mesh_from_grid(parent: Node3D,columns: int,rows: int,point: Callable,mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows):
		for column in range(columns):
			var quad: Array[Vector3] = []
			for uv in [Vector2(column,row),Vector2(column+1,row),Vector2(column+1,row+1),Vector2(column,row+1)]: quad.append(point.call(uv.x/columns,uv.y/rows))
			for index in [0,1,2,0,2,3]:
				var p: Vector3 = quad[index]
				st.set_uv(Vector2(.5+p.x/2.5,.5-p.y/2.8))
				st.add_vertex(p)
	st.index()
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = mat
	parent.add_child(instance)
	return instance

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1
	m.metallic_specular = 0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = .8
	collision.shape = shape
	add_child(collision)
	rig = Node3D.new()
	add_child(rig)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D face_image:source_color,filter_linear_mipmap;
void fragment(){
 vec3 c=texture(face_image,UV).rgb;
 vec2 iris=vec2((abs(UV.x-.5)-.17)/.061,(UV.y-.35)/.047);
 if(length(iris)<.88)c=vec3(.00035,.00045,.00045)+min(c,vec3(.025))*.20;
 ALBEDO=c*vec3(.93,.96,.94); ROUGHNESS=1.0; SPECULAR=0.0;
}"""
	var flesh := ShaderMaterial.new()
	flesh.shader = shader
	flesh.set_shader_parameter("face_image",load("res://assets/textures/sakiko_face.png"))
	# Both boundaries use the identical mouth() curve. There are no removed cells.
	mesh_from_grid(rig,160,42,func(u: float,v: float) -> Vector3:
		var a := u*TAU
		var inside := mouth(a)
		var outside := contour(a)
		var p := inside.lerp(outside,v)
		p.z = face_z(p.x,p.y)
		return p,flesh)
	mesh_from_grid(rig,160,24,func(u: float,v: float) -> Vector3:
		var outside := contour(u*TAU)
		outside.z = face_z(outside.x,outside.y)
		var p := outside.lerp(Vector3(0,.1,.73),v)
		p.z = lerpf(outside.z,.73,sin(v*PI/2))
		return p,material(Color("0a0b0b")))
	mesh_from_grid(rig,160,20,func(u: float,v: float) -> Vector3:
		var rim := mouth(u*TAU)
		var p := rim.lerp(Vector3(0,-.62,.12),v)
		p.z = lerpf(rim.z,.10,sin(v*PI/2))
		return p,material(Color("080405")))
	# Curved dental arches preserve the original enamel/gum detail and tooth silhouettes.
	var dental_shader := Shader.new()
	dental_shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D enamel:source_color,filter_linear_mipmap;
void fragment(){vec3 c=texture(enamel,UV).rgb; if(max(c.r,max(c.g,c.b))<.027)discard; ALBEDO=c*vec3(.85,.83,.74); ROUGHNESS=.96; SPECULAR=0.0;}
"""
	var dental := ShaderMaterial.new()
	dental.shader = dental_shader
	dental.set_shader_parameter("enamel",load("res://assets/textures/sakiko_face.png"))
	for upper in [true,false]:
		mesh_from_grid(rig,140,12,func(u: float,v: float) -> Vector3:
			var x := lerpf(-.68,.68,u)
			var t := x/.70
			var root_y := -.62+(.28 if upper else -.28)*sqrt(maxf(0,1-t*t))+.35*pow(absf(t),3)
			var y: float = root_y+(-1 if upper else 1)*(.012+v*.145)
			return Vector3(x,y,face_z(x,root_y)-.012-sin(v*PI)*.035),dental)
	build_hair()

func hair_point(angle: float,t: float) -> Vector3:
	if t<.43:
		var lat := .035+t/.43*1.43
		return Vector3(sin(angle)*1.20*sin(lat),.13+1.30*cos(lat),-cos(angle)*.90*sin(lat))
	var f := (t-.43)/.57
	return Vector3(sin(angle)*1.20,.267-f*2.02,-cos(angle)*(.90+f*.025))

func build_hair() -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D hair_image:source_color,filter_linear_mipmap;
varying vec3 p;
void vertex(){p=VERTEX;}
void fragment(){float a=atan(p.x,-p.z);vec2 uv=vec2(.055+fract(a/6.28318*3.0)*.075,clamp((1.45-p.y)/3.8,.05,.94));ALBEDO=texture(hair_image,uv).rgb*.36;ROUGHNESS=1.0;SPECULAR=0.0;}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("hair_image",load("res://assets/textures/sakiko_face.png"))
	# Back and side coat only. The photograph supplies the irregular front fringe.
	var start := acos(.59)
	mesh_from_grid(rig,144,38,func(u: float,v: float) -> Vector3:
		return hair_point(lerpf(start,TAU-start,u),v*.96),mat)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in range(720):
		var angle := lerpf(start,TAU-start,float(strand)/719)
		var end := .965+fmod(strand*.037,.035)
		for segment in range(22):
			var t1 := float(segment)/22*end
			var t2 := float(segment+1)/22*end
			var p1 := hair_point(angle,t1)
			var p2 := hair_point(angle,t2)
			var width := .0015*(1-t1*.8)
			var side := Vector3(cos(angle),0,sin(angle))*width
			for p in [p1-side,p1+side,p2+side,p1-side,p2+side,p2-side]:
				st.set_normal(Vector3(sin(angle),.1,-cos(angle)).normalized())
				st.add_vertex(p)
	var fibres := MeshInstance3D.new()
	fibres.mesh = st.commit()
	fibres.material_override = material(Color("080a0b"))
	rig.add_child(fibres)

func _process(delta: float) -> void:
	age += delta
	if not rig: return
	rig.position.y = sin(age*1.4)*.035
	rig.rotation.z = sin(age*.79)*.022+scare*.11
	rig.rotation.x = sin(age*.53)*.012
