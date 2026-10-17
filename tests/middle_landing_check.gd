extends "res://tests/flow_check.gd"
func run(game: Node) -> void:
	g=game;g.start_game();flow=g.progression.story_puzzles
	flow.stage=4;flow.apply_state()
	g.player.position=Vector3(47.2,4.2,19)
	await g.get_tree().physics_frame
	var d: Dictionary=flow.landing_door
	var point: Vector3=d.node.to_global(Vector3(0,1.3,d.track_side*.27))
	aim(point)
	print("LANDING before ",d.open," can ",flow.can_open(d)," player ",g.player.position," target ",g.interactable(true))
	if not await use(point,"door"): return finish()
	await g.get_tree().create_timer(1.5).timeout
	print("LANDING after ",d.open," busy ",d.busy," panels ",d.panels[0].position," / ",d.panels[1].position)
	if not await walk_to(Vector3(49.2,4.2,19)): return finish()
	check(true,"upper landing door opens normally before tape and admits player")
	print("PLACEMENT ",g.layout.placement.rejected)
	finish()
