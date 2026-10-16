extends RefCounted
var originals: Array=[]
var batches: Array[MultiMeshInstance3D]=[]
## Merge opaque generated boxes by material in 4 m cells. Bodies remain intact.
## Called once before puzzles/actors exist; movable door ancestry is excluded.
func build(game: Node, boxes: Array[MeshInstance3D]) -> void:
	var groups: Dictionary={}
	var cube:=BoxMesh.new()
	cube.size=Vector3.ONE
	for node in boxes:
		if not node.is_visible_in_tree() or node.is_in_group("audit_ceilings"): continue
		var mat: Material=node.material_override
		if not mat is StandardMaterial3D or mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		var ancestor: Node=node
		var dynamic:=false
		while ancestor and ancestor!=game.world:
			if ancestor.get_meta("dynamic_nav",false) or (ancestor is MeshInstance3D and ancestor in game.exit_panels) or ancestor in game.entrance_locks:
				dynamic=true;break
			ancestor=ancestor.get_parent()
		if dynamic: continue
		var size: Vector3=node.mesh.size
		# Architectural solids occlude other rooms, with no change to collision.
		if node.get_child_count()>0 and ((size.y>2.8 and minf(size.x,size.z)<.25) or (size.y<.4 and minf(size.x,size.z)>3)):
			var occlusion:=OccluderInstance3D.new()
			var shape:=BoxOccluder3D.new()
			shape.size=size-Vector3.ONE*.015
			occlusion.occluder=shape
			game.world.add_child(occlusion)
			occlusion.global_transform=node.global_transform
		# Long surfaces stay individually culled instead of enlarging a cell.
		if size.x>4 or size.y>4 or size.z>4: continue
		var cell:=Vector3i(floor(node.global_position.x/4),floor(node.global_position.y/4),floor(node.global_position.z/4))
		var owner: Node=node.get_parent()
		while owner.get_parent()!=game.layout and owner.get_parent()!=game.world and owner.get_parent()!=null: owner=owner.get_parent()
		var key:=str(cell)+":"+str(owner.get_instance_id())+":"+str(mat.get_instance_id())
		if not groups.has(key): groups[key]=[]
		groups[key].append(node)
	# Measured batching regressions on Iris Xe: keep individual mesh culling by
	# default. Comparison mode retains the rejected candidate for reproducibility.
	if not "--profile-compare" in OS.get_cmdline_user_args() and not "--enable-static-batching" in OS.get_cmdline_user_args(): return
	var merged:=0
	for nodes in groups.values():
		if nodes.size()<3: continue
		var origin: Vector3=nodes[0].global_position.snapped(Vector3(4,4,4))
		var instances:=MultiMesh.new()
		instances.transform_format=MultiMesh.TRANSFORM_3D
		instances.mesh=cube
		instances.instance_count=nodes.size()
		for index in range(nodes.size()):
			var node: MeshInstance3D=nodes[index]
			var transform: Transform3D=node.global_transform
			transform.origin-=origin
			transform.basis=transform.basis.scaled_local(node.mesh.size)
			instances.set_instance_transform(index,transform)
		var batch:=MultiMeshInstance3D.new()
		batch.name="StaticCell"
		batch.multimesh=instances
		batch.material_override=nodes[0].material_override
		game.world.add_child(batch)
		batch.global_position=origin
		batches.append(batch)
		for node in nodes:
			if "--profile-compare" in OS.get_cmdline_user_args(): originals.append([node,node.mesh])
			node.mesh=null
		merged+=nodes.size()-1
	print("STATIC_GEOMETRY saved_instances=",merged," cells=",groups.size())

func select_batching(enabled: bool) -> void:
	for row in originals: row[0].mesh=null if enabled else row[1]
	for batch in batches: batch.visible=enabled
