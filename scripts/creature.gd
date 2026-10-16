extends CharacterBody3D
## A continuous face annulus, matching concave mouth and closed rear skull.
var face_material: ShaderMaterial
var blink_time:=-1.0
var rig: Node3D
var age := 0.0
var scare := 0.0
var detection := 0.0
var pursuing := false
var animated_materials: Array[ShaderMaterial] = []
# Shared jaw warp. Front UVs stay fixed; the skull has a separate rounded volume.
const MOUTH_VERTEX := "uniform float jaw_open = 0.0; void vertex(){float w=exp(-pow((VERTEX.y+.80)/.29,2.0))*(1.0-smoothstep(.50,.85,abs(VERTEX.x)))*(1.0-smoothstep(-.3,.1,VERTEX.z)); VERTEX.y-=jaw_open*w;}"


func profile(y: float) -> Vector3:
	var sections := [Vector4(1.39,.01,.02,.02),Vector4(1.32,.38,.34,.36),Vector4(1.22,.62,.55,.55),Vector4(1.02,.86,.66,.70),Vector4(.75,.98,.70,.78),Vector4(.40,1.00,.65,.76),Vector4(.15,1.04,.74,.70),Vector4(-.12,.99,.77,.62),Vector4(-.40,.92,.70,.52),Vector4(-.68,.81,.62,.41),Vector4(-.92,.65,.59,.28),Vector4(-1.08,.36,.48,.13),Vector4(-1.13,.01,.19,.04)]
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
	z -= .075*exp(-pow((absf(x)-.57)/.28,2)-pow((y+.06)/.28,2))
	z += .10*exp(-pow((absf(x)-.43)/.25,2)-pow((y-.39)/.17,2))
	z -= .14*exp(-pow(x/.15,2)-pow((y-.20)/.30,2))
	z -= .20*exp(-pow(x/.19,2)-pow((y+.10)/.13,2))
	return z

func mouth(a: float) -> Vector3:
	var x := cos(a)*.70
	var y := -.62+sin(a)*.28+.35*pow(absf(cos(a)),3)
	return Vector3(x,y,face_z(x,y))

func contour(a: float) -> Vector3:
	var y := clampf(.13+1.26*sin(a),-1.13,1.39)
	var x := profile(y).x*(1 if cos(a)>=0 else -1)
	if absf(cos(a))<.0001: x=0
	return Vector3(x,y,0)

func skull_point(a: float,t: float) -> Vector3:
	var edge:=contour(a)
	var theta:=t*PI*.5
	# Rounded occiput rather than a fan collapsing every contour to one cone tip.
	return Vector3(edge.x*cos(theta),.12+(edge.y-.12)*cos(theta),.93*sin(theta))

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

func material(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_disabled;"+MOUTH_VERTEX+"void fragment(){ALBEDO=vec3(%f,%f,%f);ROUGHNESS=1.0;SPECULAR=0.0;}" % [color.r,color.g,color.b]
	m.shader=shader
	animated_materials.append(m)
	return m

func mouth_material() -> ShaderMaterial:
	var mat:=ShaderMaterial.new()
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode cull_disabled;
varying vec3 tissue_pos;
uniform float jaw_open=0.0;
void vertex(){tissue_pos=VERTEX; float w=exp(-pow((VERTEX.y+.80)/.29,2.0))*(1.0-smoothstep(.50,.85,abs(VERTEX.x)))*(1.0-smoothstep(-.3,.1,VERTEX.z)); VERTEX.y-=jaw_open*w;}
void fragment(){
 float depth=smoothstep(-.52,.10,tissue_pos.z);
 float ridge=pow(.5+.5*sin(tissue_pos.x*43.0+sin(tissue_pos.y*28.0)*2.0+tissue_pos.z*19.0),5.0);
 vec3 tissue=mix(vec3(.005,.0006,.0011),vec3(.014,.0015,.0025),ridge);
 ALBEDO=mix(tissue,vec3(.00008,.00002,.00003),depth);
 ROUGHNESS=.91; SPECULAR=.06;
}
"""
	mat.shader=shader
	animated_materials.append(mat)
	return mat

func detected() -> void:
	detection = .35

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
uniform sampler2D closed_eyes:source_color,filter_linear_mipmap;
uniform float blink=0.0;
uniform float eye_wide=0.0;
uniform float presence=1.0;
void fragment(){
 vec3 c=texture(face_image,UV).rgb;
 vec2 iris=vec2((abs(UV.x-.5)-.17)/.061,(UV.y-.35)/.047);
 iris.y/=1.0+eye_wide*.13;
 if(length(iris)<.88)c=vec3(.00035,.00045,.00045)+min(c,vec3(.025))*.20;
 // Matched authored closed-eye texture; only the two eye islands can change.
 vec2 lid=vec2((abs(UV.x-.5)-.17)/.112,(UV.y-.351)/.078);
 float region=1.0-smoothstep(.88,1.08,length(lid));
 float edge=mix(.265,.448,smoothstep(0.0,1.0,blink))+.018*lid.x*lid.x;
 float cover=(1.0-smoothstep(edge-.012,edge+.012,UV.y))*smoothstep(0.0,.08,blink);
 c=mix(c,texture(closed_eyes,UV).rgb,region*cover);
 ALBEDO=c*vec3(.86,.89,.87)*presence; ROUGHNESS=1.0; SPECULAR=0.0;
}"""
	var flesh := ShaderMaterial.new()
	shader.code = shader.code.replace("void fragment()",MOUTH_VERTEX+"void fragment()")
	flesh.shader = shader
	face_material=flesh
	animated_materials.append(flesh)
	flesh.set_shader_parameter("face_image",load("res://assets/textures/sakiko_face.png"))
	flesh.set_shader_parameter("closed_eyes",load("res://assets/textures/sakiko_eyes_closed.png"))
	# Both boundaries use the identical mouth() curve. There are no removed cells.
	mesh_from_grid(rig,160,42,func(u: float,v: float) -> Vector3:
		var a := u*TAU
		var inside := mouth(a)
		var outside := contour(a)
		var p := inside.lerp(outside,v)
		p.z = face_z(p.x,p.y)
		return p,flesh)
	mesh_from_grid(rig,160,24,func(u: float,v: float) -> Vector3:
		return skull_point(u*TAU,v),material(Color("111110")))
	mesh_from_grid(rig,160,20,func(u: float,v: float) -> Vector3:
		var rim := mouth(u*TAU)
		var p := rim.lerp(Vector3(0,-.62,.12),v)
		p.z = lerpf(rim.z,.10,sin(v*PI/2))
		return p,mouth_material())
	# Curved dental arches preserve the original enamel/gum detail and tooth silhouettes.
	var dental_shader := Shader.new()
	dental_shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D enamel:source_color,filter_linear_mipmap;
uniform float presence=1.0;
void fragment(){vec3 c=texture(enamel,UV).rgb; if(max(c.r,max(c.g,c.b))<.027)discard; ALBEDO=c*vec3(.85,.83,.74)*presence; ROUGHNESS=.96; SPECULAR=0.0;}
"""
	var dental := ShaderMaterial.new()
	dental_shader.code = dental_shader.code.replace("void fragment()",MOUTH_VERTEX+"void fragment()")
	dental.shader = dental_shader
	animated_materials.append(dental)
	dental.set_shader_parameter("enamel",load("res://assets/textures/sakiko_face.png"))
	for upper in [true,false]:
		mesh_from_grid(rig,140,12,func(u: float,v: float) -> Vector3:
			var x := lerpf(-.68,.68,u)
			var t := x/.70
			var root_y := -.62+(.28 if upper else -.28)*sqrt(maxf(0,1-t*t))+.35*pow(absf(t),3)
			var y: float = root_y+(-1 if upper else 1)*(.012+v*.135*sqrt(maxf(0,1-t*t)))
			return Vector3(x,y,face_z(x,root_y)+.045+sin(v*PI)*.025),dental)
	build_hair()

func build_hair() -> void:
	var groom: Node3D=preload("res://assets/characters/sakiko_hair.glb").instantiate()
	groom.name="FittedCurveGroom"
	rig.add_child(groom)
	var hair:=ShaderMaterial.new()
	var shader:=Shader.new()
	shader.code="shader_type spatial; void fragment(){ALBEDO=vec3(.0065);ROUGHNESS=.90;SPECULAR=.05;}"
	hair.shader=shader
	for mesh in groom.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=hair
		# Fine strands are under half a pixel wide beyond 8 m at the gameplay FOV.
		# Keep scalp/crown/main locks at every distance and the full groom up close.
		if str(mesh.name).contains("FineStrands"): mesh.visibility_range_end=8.0

func _process(delta: float) -> void:
	age += delta
	if not rig or not is_visible_in_tree(): return
	detection = maxf(0,detection-delta)
	if blink_time>=0:
		blink_time+=delta
		face_material.set_shader_parameter("blink",sin(clampf(blink_time/.85,0,1)*PI))
		if blink_time>.85: blink_time=-1
	face_material.set_shader_parameter("eye_wide",1.0 if detection>0 or pursuing else 0.0)
	var tension := .035 if pursuing else 0.0
	var opening := minf(.11,scare*.08)+tension+(.045 if detection>0 else 0.0)
	for mat in animated_materials: mat.set_shader_parameter("jaw_open",opening)
	rig.position.y = sin(age*1.4)*.035
	rig.rotation.z = sin(age*.79)*.022+scare*.11
	rig.rotation.x = -.025 if detection>0 else sin(age*.53)*.012

func slow_blink() -> void:
	blink_time=0

func set_presence(value: float) -> void:
	for mat in animated_materials: mat.set_shader_parameter("presence",value)
