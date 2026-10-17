extends "res://tests/flow_check.gd"
func run(game: Node) -> void:
	g=game
	g.start_game()
	flow=g.progression.story_puzzles
	var save:=FileAccess.open("user://checkpoint-flow-v3.save",FileAccess.READ)
	g.checkpoint_state=save.get_var()
	g.return_to_checkpoint()
	Engine.time_scale=3
	if not await walk_to(Vector3(28.3,0,30.5)): return finish()
	if not await use(flow.evidence_models.original.position,"evidence"): return finish()
	await g.get_tree().create_timer(.5).timeout
	g.progression.evidence.close()
	aim(flow.tape.position)
	await g.get_tree().physics_frame
	var point: Vector3=flow.tape.position
	var eye: Vector3=g.player.camera.global_position
	var q:=PhysicsRayQueryParameters3D.create(eye,point,1|4)
	q.exclude=[g.player.get_rid()]
	var hit: Dictionary=g.get_world_3d().direct_space_state.intersect_ray(q)
	print("TABLE DEBUG stage=",flow.stage," eye=",eye," target=",point," distance=",eye.distance_to(point)," dot=",(-g.player.camera.global_basis.z).dot((point-eye).normalized())," visible=",g.target_visible(point,1.65,.96)," hit=",hit)
	if not hit.is_empty(): print("TABLE COLLIDER ",hit.collider.get_path()," endgap=",hit.position.distance_to(point))
	await capture_image("table_support_check")
	await use(point,"cassette")
	finish()
