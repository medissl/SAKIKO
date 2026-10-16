extends RefCounted
var game: Node
var failed:=false
var checks:=0

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failed=true; push_error("SHELL FAIL "+label)
	print("SHELL ","PASS " if ok else "FAIL ",label)

func walk_to(point: Vector3) -> bool:
	var distance: float=Vector2(point.x-game.player.position.x,point.z-game.player.position.z).length()
	var deadline: int=Time.get_ticks_msec()+int((distance/(2.2*Engine.time_scale)+2.0)*1000)
	Input.action_press("forward")
	while Vector2(point.x-game.player.position.x,point.z-game.player.position.z).length()>.16 and Time.get_ticks_msec()<deadline:
		var diff: Vector3=point-game.player.position
		game.player.rotation.y=atan2(-diff.x,-diff.z)
		await game.get_tree().physics_frame
	Input.action_release("forward")
	game.player.velocity.x=0
	game.player.velocity.z=0
	await game.get_tree().physics_frame
	var reached: bool=Vector2(point.x-game.player.position.x,point.z-game.player.position.z).length()<.22 and absf(game.player.position.y-point.y)<.25
	if not reached: print("SHELL WALK target=",point," actual=",game.player.position)
	return reached

func asset_bounds(scene: PackedScene) -> AABB:
	var root: Node3D=scene.instantiate()
	game.world.add_child(root)
	var result:=AABB()
	var first:=true
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		var bounds: AABB=(root.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		result=bounds if first else result.merge(bounds)
		first=false
	root.free()
	return result

func run(g: Node) -> void:
	game=g
	await game.get_tree().physics_frame
	var desk:=asset_bounds(game.desk_asset)
	var chair:=asset_bounds(game.chair_asset)
	print("ASSET METRES desk=",desk," chair=",chair)
	game.layout.measured={"desk":desk,"chair":chair}
	Engine.time_scale=3
	game.player.position=Vector3(10,.03,10)
	for point in [Vector3(46,0,10),Vector3(46,0,26),Vector3(10,0,26),Vector3(10,0,19)]:
		if not await walk_to(point):
			check(false,"ground corridor loop")
			game.get_tree().quit(1)
			return
	check(true,"ground corridor loop physically traversed")
	for point in game.layout.stair_routes[0]:
		if not await walk_to(point):
			check(false,"west dogleg stairs ascend")
			game.get_tree().quit(1)
			return
	check(absf(game.player.position.y-4.2)<.15,"west stairs physically reach upper floor")
	for point in [Vector3(10,4.2,19),Vector3(10,4.2,10),Vector3(46,4.2,10),Vector3(46,4.2,26),Vector3(10,4.2,26),Vector3(10,4.2,19),Vector3(10,4.2,10),Vector3(46,4.2,10),Vector3(46,4.2,19)]:
		if not await walk_to(point):
			check(false,"upper corridor loop")
			game.get_tree().quit(1)
			return
	check(true,"upper corridor loop physically traversed")
	var descending: PackedVector3Array=game.layout.stair_routes[1].duplicate()
	descending.reverse()
	for point in descending:
		if not await walk_to(point):
			check(false,"east dogleg stairs descend")
			game.get_tree().quit(1)
			return
	check(absf(game.player.position.y)<.15,"east stairs physically return to ground floor")
	for id in game.layout.room_doors:
		var d: Dictionary=game.layout.room_doors[id][0]
		game.toggle_door(d,true)
		await game.get_tree().create_timer(.8).timeout
		var north: bool=d.get("north",d.origin.z<12)
		game.player.position=d.origin+Vector3(0,.02,1.3 if north else -1.3)
		game.player.velocity=Vector3.ZERO
		await game.get_tree().physics_frame
		check(await walk_to(d.origin+Vector3(0,0,-1.5 if north else 1.5)),id+" has a real traversable entrance")
	Engine.time_scale=1
	print("SHELL COMPLETE ",checks," checks; failures: ",failed)
	game.get_tree().quit(1 if failed else 0)
