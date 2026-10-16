extends Node3D
## CC0 textured MakeHuman figures, with authored seated and standing reading poses.
var teacher := false
var actor: Node3D
var elapsed := 0.0

func _ready() -> void:
	var scene: PackedScene = load("res://assets/characters/%s.glb" % ("teacher_reading" if teacher else "seated_reading"))
	actor = scene.instantiate()
	add_child(actor)
	var bounds := AABB()
	var first := true
	for mesh in actor.find_children("*","MeshInstance3D",true,false):
		var local: AABB = (global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
		for i in range(mesh.mesh.get_surface_count()):
			var source = mesh.get_active_material(i)
			if source is StandardMaterial3D:
				var mat: StandardMaterial3D = source.duplicate()
				mat.metallic = 0
				mat.roughness = maxf(mat.roughness,.82)
				mat.metallic_specular = .15
				mesh.set_surface_override_material(i,mat)
	var factor := (1.76 if teacher else 1.29)/maxf(.01,bounds.size.y)
	actor.scale *= factor
	actor.position.y -= bounds.position.y*factor

func class_activity(t: float) -> void:
	if not actor: return
	var phase := absf(position.x*1.7+position.z*.83)
	var shift := exp(-pow((fmod(t+phase,27.3)-8)/1.8,2))
	actor.rotation.z = sin(t*.33+phase)*.003+shift*.009
	actor.position.x = shift*.018
	actor.rotation.y = sin(t*.43+phase)*.004
	if teacher:
		# Brief turns toward the class punctuate work at the board.
		actor.rotation.y += .48*(smoothstep(19,21,fmod(t,40))*(1-smoothstep(25,27,fmod(t,40))))
	else:
		var notice := smoothstep(52,53,t)*(1-smoothstep(55,57,t))
		if position.x> -16: actor.rotation.y += notice*.20
