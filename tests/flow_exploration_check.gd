extends "res://tests/flow_check.gd"
func press_toward(point: Vector3, seconds: float) -> void:
	aim(point)
	g.player.camera.rotation.x=0
	Input.action_press("forward")
	await g.get_tree().create_timer(seconds).timeout
	Input.action_release("forward")
	await g.get_tree().create_timer(.1).timeout
func run(game: Node) -> void:
	g=game
	g.start_game()
	flow=g.progression.story_puzzles
	Engine.time_scale=3
	await g.get_tree().create_timer(.8).timeout
	if not await walk_to(Vector3(22,0,10)): return finish()
	if not await walk_to(Vector3(29,0,5.5)): return finish()
	check(flow.in_room("G03") and flow.stage==0 and flow.objective()=="Find the main entrance.","early staff visit remains understandable without granting breaker progress")
	if not await walk_to(Vector3(21.5,0,6)): return finish()
	check(flow.in_room("G02") and flow.stage==0,"initial optional infirmary can be explored without changing the objective")
	if not await walk_to(Vector3(10,0,14.8)): return finish()
	await press_toward(Vector3(10,1.5,19),1.1)
	check(g.player.position.z<15.75 and flow.stage==0,"wrong turn: physical shutter prevents wandering into south wing early")
	if not await walk_to(Vector3(1.5,0,12)): return finish()
	if not await use(g.layout.EXIT_TARGET,"exit"): return finish()
	await g.get_tree().create_timer(1.6).timeout
	if not await walk_to(Vector3(10,0,14.8)): return finish()
	await press_toward(Vector3(10,1.5,19),1)
	check(g.player.position.z<15.75 and flow.stage==1,"trying entrance does not skip the breaker task")
	if not await walk_to(Vector3(29,0,9.0)): return finish()
	var staff: Dictionary=g.layout.room_doors.G03[0]
	if not staff.open:
		if not await use(staff.node.to_global(Vector3(0,1.3,staff.track_side*.27)),"door"): return finish()
		await g.get_tree().create_timer(1.3).timeout
	aim(Vector3(29,1.58,2))
	check(g.player.camera.is_position_in_frustum(flow.lever.global_position) and g.clear_line(g.player.camera.global_position,flow.lever.global_position),"breaker is visible through the doorway without searching behind furniture")
	await capture_image("staff_entry_affordance")
	if not await walk_to(Vector3(31.2,0,3.6)): return finish()
	if not await use(flow.lever.global_position,"breaker"): return finish()
	check(flow.stage==2 and is_equal_approx(flow.cover.rotation.y,1.3),"one interaction resets already-open breaker")
	aim(flow.lever.global_position)
	await capture_image("breaker_open")
	await g.get_tree().create_timer(1.6).timeout
	check(not flow.can_open(g.layout.room_doors.G05[0]) and not flow.can_open(g.layout.room_doors.U08[0]),"breaker cannot unlock AV or rehearsal out of order")
	if not await walk_to(Vector3(28.3,0,30.5)): return finish()
	if not await use(flow.evidence_models.original.position,"evidence"): return finish()
	await g.get_tree().create_timer(.4).timeout
	g.progression.evidence.close()
	check(flow.stage==2 and not flow.flags.get("cassette",false),"required original photo supplies story before cassette action")
	aim(flow.tape.position)
	await capture_image("quiet_objective_and_table")
	if not await use(flow.tape.position,"cassette"): return finish()
	await g.get_tree().create_timer(1.6).timeout
	if not await walk_to(Vector3(37.5,4.2,29.5)): return finish()
	var right_door: Dictionary=g.layout.room_doors.U07[1]
	g.toggle_door(right_door)
	check(not right_door.open and flow.stage==3,"exhibition's other doorway cannot bypass portrait and sighting")
	check(not flow.can_open(g.layout.room_doors.G05[0]) and not flow.can_open(g.layout.room_doors.U08[0]),"upstairs exploration cannot skip to AV or final key")
	if not await walk_to(Vector3(31.5,4.2,34.3)): return finish()
	if not await use(flow.evidence_models.display.position,"evidence"): return finish()
	await g.get_tree().create_timer(.5).timeout
	await capture_image("readable_exhibit")
	g.progression.evidence.close()
	if not await walk_to(Vector3(26,4.2,26)): return finish()
	g.player.look_at(Vector3(10,4.2,26))
	await g.get_tree().create_timer(8).timeout
	var encounter: RefCounted=g.progression.encounters_controller
	check(not encounter.reveal_finished and encounter.notice_hold<.4,"looking away preserves the pending presentation independently of access")
	check(flow.can_open(g.layout.room_doors.G05[0]) and flow.stage==4,"looking away never blocks AV progression")
	var ids: Array=g.progression.evidence.entries.keys()
	check(ids.size()==5 and ids.has("letter") and ids.has("notice") and ids.has("original"),"story limited to two short presentations, two optional records and final letter")
	var subtle:=true
	for item in flow.available_targets():
		if str(item.get("label","")).contains("F-12") or str(item.get("label","")).contains("entrance key"): subtle=false
	check(subtle and g.hud.get_theme_font_size("font_size")==16,"generic object actions and compact objective instead of solution labels")
	check(g.progression.evidence.entries.display.body.length()<170 and g.progression.evidence.entries.recording.body.contains("I thought you were going back"),"mandatory discoveries connect altered photo to someone being left locked inside")
	# No new progress: at most one delayed hint, never while an encounter is active.
	flow.stalled=60
	flow.hinted.clear()
	await g.get_tree().create_timer(.2).timeout
	check(flow.hinted.is_empty(),"stalled hint is suppressed during the sighting")
	# Continue without looking back: missed presentation must not block the tape.
	if not await walk_to(Vector3(42.3,0,2.5)): return finish()
	check(encounter.reveal_finished and flow.stage==4,"leaving watcher section completes presentation telemetry without a gate dependency")
	AudioServer.set_bus_mute(0,true)
	if not await use(Vector3(42.3,1.0,1.3),"recording"): return finish()
	if not await use(Vector3(42.3,1.0,1.3),"recording"): return finish()
	flow.close_tape()
	check(flow.stage==4 and not flow.flags.get("tape_done",false) and not encounter.chase_started,"closing playback early permits replay and cannot arm pursuit")
	if not await use(Vector3(42.3,1.0,1.3),"recording"): return finish()
	flow.step_transcript(1)
	flow.step_transcript(-1)
	check(flow.captions.text.contains("front-door key"),"manual transcript review works with all sound muted")
	for block in range(4): flow.step_transcript(1)
	check(flow.stage==5 and g.checkpoint_id=="CP4" and g.mode=="playback_review" and not g.progression.hunt_enabled,"manual completion saves safe AV checkpoint with readable full review")
	flow.close_tape()
	g.progression.hunt_enabled=true
	g.ai_state="chase"
	g.progression.evidence.inspect("letter")
	check(g.mode=="playing" and not g.progression.evidence.collected.has("letter"),"active pursuit cannot be erased by inspecting final evidence")
	g.progression.evidence.show_journal()
	check(g.mode=="playing","journal cannot freeze an active pursuit")
	g.return_to_checkpoint()
	check(not flow.recording.playing and g.player.stamina==100 and not encounter.chase_started,"CP4 cancels old playback and rearms corridor pursuit")
	print("EXPLORATION RESULT failures=",failures)
	finish()
