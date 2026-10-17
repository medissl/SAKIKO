extends "res://tests/flow_check.gd"
func run(game: Node) -> void:
	g=game;g.start_game();flow=g.progression.story_puzzles
	flow.stage=6
	flow.flags={"tape_done":true,"chase_started":true,"escape_done":true,"middle_section_active":true,"shutter_progress":.35}
	flow.apply_state()
	g.progression.encounters_controller.chase_started=true
	g.progression.encounters_controller.reveal_finished=true
	g.progression.encounters_controller.pressure_cooldown=55
	g.enemy.position=Vector3(14,1.5,4)
	g.enemy.show()
	g.player.position=Vector3(13.1,4.2,10.8)
	await g.get_tree().create_timer(.4).timeout
	aim(flow.WINCH_POINT)
	Input.action_press("interact")
	await g.get_tree().create_timer(.3).timeout
	await capture_image("middle_station_active")
	Input.action_release("interact")
	await g.get_tree().create_timer(.2).timeout
	await capture_image("middle_station_released")
	# GPU sample at identical views before and after crank operation.
	var samples:=PackedFloat64Array()
	for frame in range(120):
		await g.get_tree().process_frame
		samples.append(g.get_process_delta_time()*1000)
	samples.sort()
	print("MIDDLE FRAME SAMPLE median_ms=",samples[60]," p95_ms=",samples[114]," renderer=",RenderingServer.get_current_rendering_method())
	g.player.position=Vector3(46,4.2,10)
	aim(Vector3(47.86,6.8,10.5))
	await capture_image("middle_east_turn_sign")
	g.player.position=Vector3(46.8,4.2,19)
	aim(flow.landing_bolt.global_position)
	await capture_image("middle_upper_bolt")
	check(g.layout.placement.rejected.is_empty(),"middle hardware signs pass placement contract")
	finish()
