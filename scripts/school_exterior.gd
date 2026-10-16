extends Node3D
## Shared exterior geometry, viewed directly through ordinary framed glazing.
var game: Node
var sun: DirectionalLight3D
var env: Environment
var panorama: PanoramaSkyMaterial
var leaf_mesh: ArrayMesh

func build(g: Node) -> void:
	game=g
	env=game.world.get_child(0).environment
	var sky:=Sky.new()
	panorama=PanoramaSkyMaterial.new()
	panorama.panorama=load("res://assets/environment/generated/school_panorama_night.png")
	sky.sky_material=panorama
	env.sky=sky
	env.background_mode=Environment.BG_SKY
	sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-38,-38,0)
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=75
	add_child(sun)
	var ground:=box(Vector3(28,-.31,18),Vector3(2048,.2,2048),"dark")
	ground.material_override=ground_material(false)
	# Paved apron and perimeter contain the short final exit route.
	var apron:=box(Vector3(28,-.205,18),Vector3(88,.05,68),"wall")
	apron.material_override=ground_material(false)
	for x in [-12,68]: box(Vector3(x,1.1,18),Vector3(.25,2.4,67),"wall")
	for z in [-16,52]: box(Vector3(28,1.1,z),Vector3(80,2.4,.25),"wall")
	# Courtyard sits below the internal timber floor, with drains along all four sides.
	var paving:=box(Vector3(28,-.15,18),Vector3(31.8,.10,11.8),"wall")
	paving.material_override=ground_material(true)
	for z in [12.24,23.76]: drain(Vector3(28,-.085,z),Vector2(31.2,.18))
	for x in [12.24,43.76]: drain(Vector3(x,-.085,18),Vector2(.18,11.2))
	for x in [23,33]:
		for dx in [-1.55,1.55]: box(Vector3(x+dx,.12,18),Vector3(.12,.45,2.4),"wall")
		for z in [16.85,19.15]: box(Vector3(x,.12,z),Vector3(3.2,.45,.12),"wall")
		box(Vector3(x,.20,18),Vector3(2.94,.08,2.14),"dark")
	build_leaf_mesh()
	tree(Vector3(23,.24,18),1.0,19)
	# Small plants occupy the second bed; they do not repeat the tree silhouette.
	for i in range(9): shrub(Vector3(32+(i%3)*.85,.24,17.25+(i/3)*.65),i)
	for structure in [[Vector3(28,0,-47),Vector3(61,9,13)],[Vector3(88,0,18),Vector3(13,12,45)]]:
		facade(structure[0],structure[1])
	for i in range(11): tree(Vector3(-24+i*11,-.2,-21-abs(i%3)*3),.65+(i%4)*.09,70+i)
	for i in range(7): tree(Vector3(76,-.2,-8+i*11),.7+(i%3)*.12,90+i)
	set_day(false)

func box(point: Vector3,size: Vector3,mat: String) -> MeshInstance3D:
	return game.box(point,size,mat,false,self)

func drain(point: Vector3,size: Vector2) -> void:
	box(point,Vector3(size.x,.025,size.y),"dark")
	var count: int=int(maxf(size.x,size.y)/.16)
	for i in range(count):
		var along_x: bool=size.x>size.y
		box(point+Vector3(-size.x/2+i*.16 if along_x else 0,.015,0 if along_x else -size.y/2+i*.16),Vector3(.024,.015,size.y) if along_x else Vector3(size.x,.015,.024),"metal")

func rod(a: Vector3,b: Vector3,radius: float,mat: Material,parent: Node3D) -> void:
	var mesh:=MeshInstance3D.new()
	var cylinder:=CylinderMesh.new()
	cylinder.top_radius=radius*.58
	cylinder.bottom_radius=radius
	cylinder.height=a.distance_to(b)
	cylinder.radial_segments=7
	mesh.mesh=cylinder
	mesh.material_override=mat
	parent.add_child(mesh)
	mesh.position=(a+b)*.5
	mesh.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_leaf_mesh() -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new()
	rng.seed=91015
	for i in range(95):
		var a: float=rng.randf()*TAU
		var h: float=rng.randf_range(-.7,.8)
		var p:=Vector3(cos(a),h,sin(a))*rng.randf_range(.10,1.0)
		var orientation:=Basis.from_euler(Vector3(rng.randf_range(-.7,.7),a,rng.randf_range(-.5,.5)))
		var side: Vector3=orientation.x*rng.randf_range(.24,.36)
		var up: Vector3=orientation.y*rng.randf_range(.26,.40)
		var corners: Array[Vector3]=[p-side+up,p+side+up,p+side-up,p-side-up]
		var uv: Array[Vector2]=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
		for j in [0,1,2,0,2,3]:
			st.set_color(Color.WHITE*rng.randf_range(.75,1.0))
			st.set_uv((uv[j]*.485+Vector2(.007,.007))+Vector2((i%2)*.5,floorf((i%4)/2.0)*.5))
			st.add_vertex(corners[j])
	st.generate_normals()
	leaf_mesh=st.commit()
	var leaves:=StandardMaterial3D.new()
	leaves.albedo_texture=load("res://assets/environment/generated/broadleaf_atlas.png")
	leaves.vertex_color_use_as_albedo=true
	leaves.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	leaves.alpha_scissor_threshold=.40
	leaves.cull_mode=BaseMaterial3D.CULL_DISABLED
	leaves.roughness=.95
	leaves.metallic_specular=.08
	leaf_mesh.surface_set_material(0,leaves)

func tree(point: Vector3,size: float,seed_value: int) -> void:
	var root:=Node3D.new()
	root.position=point
	root.scale=Vector3.ONE*size
	add_child(root)
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	var bark:=StandardMaterial3D.new()
	bark.albedo_color=Color("3a332a")
	bark.roughness=1
	bark.metallic_specular=0
	rod(Vector3.ZERO,Vector3(.18,4.6,.03),.20,bark,root)
	for i in range(9):
		var angle: float=i*2.399+rng.randf_range(-.2,.2)
		var start:=Vector3(.1,2.1+i*.23,0)
		var end:=Vector3(cos(angle)*(1.5 if i<6 else .9),3.6+i*.17,sin(angle)*1.25)
		rod(start,end,.075,bark,root)
		var leaves:=MeshInstance3D.new()
		leaves.mesh=leaf_mesh
		leaves.position=end
		leaves.rotation.y=angle
		leaves.scale=Vector3(1.15,.85,1.1)
		leaves.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if seed_value==19 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(leaves)

func shrub(point: Vector3,index: int) -> void:
	var plant:=MeshInstance3D.new()
	plant.mesh=leaf_mesh
	plant.position=point+Vector3(0,.25,0)
	plant.scale=Vector3(.35,.30,.35)
	plant.rotation.y=index*1.7
	plant.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plant)

func facade(point: Vector3,size: Vector3) -> void:
	box(point+Vector3(0,size.y*.5,0),size,"wall")
	box(point+Vector3(0,size.y+.12,0),Vector3(size.x+.6,.24,size.z+.6),"dark")
	for y in [3.4,6.6]: box(point+Vector3(0,y,size.z/2+.04),Vector3(size.x,.16,.12),"metal")
	for x in [-size.x/2+.3,size.x/2-.3]: box(point+Vector3(x,size.y*.5,size.z/2+.13),Vector3(.08,size.y,.08),"metal")
	var finish:=StandardMaterial3D.new()
	finish.albedo_texture=load("res://assets/environment/generated/school_facade_bay.png")
	finish.roughness=1
	finish.metallic_specular=.05
	finish.uv1_scale=Vector3(size.x/(size.y*.5),1,1)
	var front:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(size.x,size.y)
	front.mesh=quad
	front.position=point+Vector3(0,size.y/2,size.z/2+.02)
	front.material_override=finish
	add_child(front)
	var flank:=MeshInstance3D.new()
	var side:=QuadMesh.new()
	side.size=Vector2(size.z,size.y)
	flank.mesh=side
	flank.position=point+Vector3(-size.x/2-.02,size.y/2,0)
	flank.rotation.y=-PI/2
	flank.material_override=finish.duplicate()
	flank.material_override.uv1_scale=Vector3(size.z/(size.y*.5),1,1)
	add_child(flank)

func set_day(on: bool) -> void:
	sun.light_energy=.9 if on else .045
	sun.light_color=Color("e4dfc5") if on else Color("93aabd")
	panorama.panorama=load("res://assets/environment/generated/school_panorama_day.png" if on else "res://assets/environment/generated/school_panorama_night.png")
	panorama.energy_multiplier=.9 if on else .20

func ground_material(pavers: bool) -> ShaderMaterial:
	var mat:=ShaderMaterial.new()
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
varying vec3 wp;
uniform bool pavers=false;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 cell=floor(wp.xz/1.2);
 float grit=hash(floor(wp.xz*120.0));
 float coarse=hash(floor(wp.xz*1.4));
 vec3 base=pavers?vec3(.22,.23,.21):vec3(.11,.125,.12);
 base*=.85+grit*.18+coarse*.09;
 if(pavers){vec2 edge=min(fract(wp.xz/1.2),1.0-fract(wp.xz/1.2));float seam=step(min(edge.x,edge.y),.006);base*=1.0-seam*.32;base*=.95+hash(cell)*.10;}
 ALBEDO=base;ROUGHNESS=.96;SPECULAR=.08;
}
"""
	mat.shader=shader
	mat.set_shader_parameter("pavers",pavers)
	return mat
