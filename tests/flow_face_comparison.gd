extends "res://tests/flow_check.gd"
func pair(name: String, creature: Node) -> void:
	creature.set_process(false)
	for variant in [0.0,1.0]:
		creature.face_material.set_shader_parameter("face_variant",variant)
		await g.get_tree().process_frame
		await capture_image("face_"+name+("_baseline" if variant==0 else "_material"))
	creature.set_process(true)
func run(game: Node) -> void:
	g=game
	g.start_game()
	flow=g.progression.story_puzzles
	flow.stage=4
	flow.flags.portrait=true
	flow.apply_state()
	g.player.position=Vector3(26,4.2,26)
	g.player.rotation.y=PI/2
	g.player.pitch=0
	var encounter: RefCounted=g.progression.encounters_controller
	encounter.reveal_requested=true
	await g.get_tree().create_timer(.4).timeout
	check(encounter.reveal_time>=0,"watcher stages at distant authored corridor end")
	check(g.enemy.position.distance_to(g.player.camera.global_position)>=19,"watcher remains at least nineteen metres from exhibition exit")
	g.player.lamp.hide()
	aim(g.enemy.position)
	await pair("distant",g.enemy)
	# Focused visual fixture: inspect the same material pair nearer a real doorway.
	g.mode="visual_comparison"
	g.player.position=Vector3(40,4.2,26)
	aim(g.enemy.position)
	await pair("doorway",g.enemy)
	g.mode="playing"
	g.capture()
	await g.get_tree().create_timer(.9).timeout
	g.set_process(false)
	await pair("capture",g.scare_head)
	g.set_process(true)
	print("FACE COMPARISON RESULT failures=",failures)
	finish()
