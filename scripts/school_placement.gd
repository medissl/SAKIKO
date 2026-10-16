extends RefCounted
## One placement contract shared by architecture, fixtures and authored props.
enum Category { SOLID_WALL_MOUNT, WINDOW_ASSEMBLY, DOORWAY_ASSEMBLY, FLOOR_FURNITURE, CEILING_FIXTURE, PUZZLE_OBJECT }
var supports: Array[AABB]=[]
var reserved: Array[Dictionary]=[]
var accepted: Array[Dictionary]=[]
var rejected: Array[String]=[]
var furniture_materials: Dictionary={}

func reserve(kind: String,bounds: AABB,owner: String) -> void:
	reserved.append({"kind":kind,"bounds":bounds,"owner":owner})

func solid(bounds: AABB) -> void:
	supports.append(bounds)

func admit(node: Node3D,category: Category,bounds: AABB,owner: String,assembly: String="") -> bool:
	var reason: String=""
	if category==Category.SOLID_WALL_MOUNT:
		var supported:=false
		for wall in supports:
			if wall.grow(.055).intersects(bounds): supported=true; break
		if not supported: reason="unsupported wall mount"
	for zone in reserved:
		if zone.owner==owner: continue
		if zone.kind in ["window","door","panel_travel","headroom","aisle"] and category in [Category.SOLID_WALL_MOUNT,Category.FLOOR_FURNITURE]:
			if zone.bounds.intersects(bounds): reason="intersects "+zone.kind+" / "+str(zone.owner); break
	if category==Category.FLOOR_FURNITURE:
		for other in accepted:
			if other.category==Category.FLOOR_FURNITURE and not assembly.is_empty() and assembly!=other.assembly and other.bounds.grow(.05).intersects(bounds.grow(.05)): reason="unrelated furniture clearance / "+str(other.owner); break
	if not reason.is_empty():
		rejected.append(owner+": "+reason)
		node.queue_free()
		push_error("PLACEMENT REJECTED "+owner+": "+reason)
		return false
	node.set_meta("placement_category",Category.keys()[category])
	node.set_meta("placement_owner",owner)
	accepted.append({"node":node,"category":category,"bounds":bounds,"owner":owner,"assembly":assembly})
	return true

func grounded_asset(scene: PackedScene,parent: Node3D,point: Vector3,yaw: float,scale_factor: float) -> Node3D:
	var pivot:=Node3D.new()
	parent.add_child(pivot)
	pivot.position=point
	pivot.rotation.y=yaw
	var asset: Node3D=scene.instantiate()
	pivot.add_child(asset)
	asset.scale=Vector3.ONE*scale_factor
	var bottom:=INF
	for mesh in asset.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var source: Material=mesh.get_active_material(surface)
			if source is StandardMaterial3D:
				var key:=source.get_instance_id()
				if not furniture_materials.has(key):
					var finish: StandardMaterial3D=source.duplicate()
					finish.roughness=maxf(.78,finish.roughness);finish.metallic_specular=.16
					furniture_materials[key]=finish
				mesh.set_surface_override_material(surface,furniture_materials[key])
		var bounds: AABB=(pivot.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		bottom=minf(bottom,bounds.position.y)
	if bottom!=INF: asset.position.y-=bottom
	pivot.set_meta("placement_category","FLOOR_FURNITURE")
	return pivot
