extends RefCounted
var g: Node
var failures:=0
var finished:=false
var flow: Node
var body_nav: AStar3D
var body_nav_key:=""
func check(ok: bool, text: String) -> void:
	print("FLOW PASS " if ok else "FLOW FAIL ",text)
	if not ok: failures+=1
func aim(point: Vector3) -> void:
	var eye: Vector3=g.player.camera.global_position
	if Vector2(point.x-eye.x,point.z-eye.z).length()>.001: g.player.look_at(Vector3(point.x,g.player.position.y,point.z))
	g.player.pitch=atan2(point.y-eye.y,Vector2(point.x-eye.x,point.z-eye.z).length())
	g.player.camera.rotation=Vector3(g.player.pitch,0,0)
	g.aimed_frame=-1
func use(point: Vector3, kind: String) -> bool:
	Input.action_release("forward")
	aim(point)
	await g.get_tree().physics_frame
	var target: Dictionary=g.interactable(true)
	check(target.get("type","")==kind,"ordinary aimed interaction "+kind+" at "+str(g.player.position)+" got "+str(target.get("type","none")))
	if target.get("type","")!=kind: return false
	g.interact()
	await g.get_tree().physics_frame
	return true
func walk_to(destination: Vector3, running:=false) -> bool:
	# QA owns a cached body-sized route graph; retail AI retains its actual clearance.
	var routing_key: String=str(flow.stage)+str(flow.flags.get("bolted",false))+str(flow.flags.get("middle_section_active",false))+str(flow.flags.get("shutter_open",false))+str(flow.flags.get("east_landing_unbolted",false))+str(flow.flags.get("south_shortcut_released",false))
	if not body_nav or body_nav_key!=routing_key:
		var creature_nav: AStar3D=g.nav
		var creature_lookup: Dictionary=g.nav_lookup
		var creature_blocked: Dictionary=g.nav_blocked
		g.nav=AStar3D.new();g.nav_lookup={};g.nav_blocked={}
		g.build_navigation(.33)
		body_nav=g.nav;body_nav_key=routing_key
		g.nav=creature_nav;g.nav_lookup=creature_lookup;g.nav_blocked=creature_blocked
	var route: PackedVector3Array=body_nav.get_point_path(body_nav.get_closest_point(g.player.position+Vector3(0,1.5,0)),body_nav.get_closest_point(destination+Vector3(0,1.5,0)))
	if route.is_empty(): check(false,"walkable route "+str(destination)); return false
	for point in route:
		var target: Vector3=point-Vector3(0,1.5,0)
		var elapsed:=0.0
		while Vector2(g.player.position.x-target.x,g.player.position.z-target.z).length()>.18:
			if g.mode!="playing":
				Input.action_release("forward"); Input.action_release("sprint")
				check(false,"walking interrupted by "+g.mode+" toward "+str(destination))
				return false
			g.player.look_at(Vector3(target.x,g.player.position.y,target.z))
			g.player.camera.rotation=Vector3.ZERO
			Input.action_press("forward")
			if running: Input.action_press("sprint")
			await g.get_tree().physics_frame
			elapsed+=g.get_physics_process_delta_time()
			if elapsed>1.0:
				for d in g.doors:
					var distance: float=Vector2(g.player.position.x-d.origin.x,g.player.position.z-d.origin.z).length()
					if distance<1.8 and absf(g.player.position.y-d.origin.y)<1.1 and not d.open and not d.busy and flow.can_open(d):
						Input.action_release("forward")
						var local_x: float=0
						var centre: Vector3=d.node.to_global(Vector3(local_x,1.3,float(d.track_side)*.27))
						centre+=d.node.global_basis.z*.08*signf((g.player.position-centre).dot(d.node.global_basis.z))
						aim(centre)
						g.interact()
						await g.get_tree().create_timer(1.3).timeout
			if elapsed>12:
				Input.action_release("forward"); Input.action_release("sprint")
				check(false,"movement obstructed toward "+str(target)+" from "+str(g.player.position))
				return false
	Input.action_release("forward"); Input.action_release("sprint")
	await g.get_tree().create_timer(.1).timeout
	return true
func capture_image(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png("res://tests/artifacts/flow_"+name+".png")
func run(game: Node) -> void:
	g=game
	g.get_tree().create_timer(600,true,false,true).timeout.connect(func():
		if not finished: print("FLOW WATCHDOG"); g.get_tree().quit(1))
	var resumed: Dictionary={}
	if "--resume-cp4" in OS.get_cmdline_user_args():
		var prior:=FileAccess.open("res://tests/artifacts/flow-cp3.save",FileAccess.READ)
		if prior: resumed=prior.get_var();prior.close()
	elif "--resume-route" in OS.get_cmdline_user_args():
		var prior:=FileAccess.open("user://checkpoint-flow-v5.save",FileAccess.READ)
		if prior: resumed=prior.get_var();prior.close()
	g.start_game()
	flow=g.progression.story_puzzles
	Engine.time_scale=3
	check(flow.stage==0 and g.keys.is_empty() and g.hardware.locks.size()==1,"clean new route: one lock, no old spawned keys")
	check(flow.can_open(g.layout.room_doors.G03[0]) and not flow.can_open(g.layout.room_doors.U08[0]),"staff accessible early; rehearsal remains latched")
	check(g.layout.placement.rejected.is_empty(),"new prop placement contract")
	if not g.layout.placement.rejected.is_empty(): print("FLOW PLACEMENT ",g.layout.placement.rejected)
	var encounter: RefCounted=g.progression.encounters_controller
	if "--resume-route" in OS.get_cmdline_user_args() or "--resume-cp4" in OS.get_cmdline_user_args():
		g.checkpoint_state=resumed
		g.return_to_checkpoint()
		check(flow.stage==(5 if "--resume-cp4" in OS.get_cmdline_user_args() else 4),"continue from organically reached story checkpoint")
	else:
		await g.get_tree().create_timer(.8).timeout
		if not await walk_to(Vector3(9.5,0,10)): return finish()
		if not await walk_to(Vector3(1.5,0,12)): return finish()
		if not await use(g.layout.EXIT_TARGET,"exit"): return finish()
		check(flow.stage==1,"first entrance interaction releases staff gate")
		await g.get_tree().create_timer(1.6).timeout
		if not await walk_to(Vector3(31.2,0,3.6)): return finish()
		if not await use(flow.lever.global_position,"breaker"): return finish()
		check(flow.stage==2 and g.checkpoint_id=="CP1","breaker directly restores south wing and CP1")
		await g.get_tree().create_timer(1.6).timeout
		if not await walk_to(Vector3(29,0,30.6)): return finish()
		check(not flow.flags.get("original",false) and not flow.available_targets().any(func(item): return item.type=="cassette"),"cassette waits for original photo inspection")
		if not await use(flow.evidence_models.original.position,"evidence"): return finish()
		await g.get_tree().create_timer(.5).timeout
		g.progression.evidence.close()
		check(flow.flags.get("original",false),"required ordinary photograph saved as journal image")
		aim(flow.tape.position)
		await capture_image("packing_table")
		if not await use(flow.tape.position,"cassette"): return finish()
		check(flow.flags.get("cassette",false) and flow.stage==3,"visible cassette alone opens west stair route")
		await g.get_tree().create_timer(1.6).timeout
		if not await walk_to(Vector3(31.5,4.2,34.3)): return finish()
		if not await use(flow.evidence_models.display.position,"evidence"): return finish()
		await g.get_tree().create_timer(.5).timeout
		await capture_image("portrait_caption")
		g.progression.evidence.close()
		if not await walk_to(Vector3(26,4.2,26)): return finish()
		g.player.look_at(Vector3(10,4.2,26))
		await g.get_tree().create_timer(.5).timeout
		check(encounter.reveal_time>=0 and not encounter.reveal_finished,"offscreen staging on mandatory exhibition exit")
		aim(g.enemy.position)
		g.player.lamp.hide()
		await capture_image("sighting_light_off")
		await g.get_tree().create_timer(.8).timeout
		g.player.look_at(Vector3(10,4.2,26))
		await g.get_tree().create_timer(.6).timeout
		check(encounter.notice_hold>.6 and not encounter.reveal_seen,"looking away preserves partial actual-visible time")
		aim(g.enemy.position)
		g.player.lamp.show()
		await capture_image("sighting_light_on")
		await g.get_tree().create_timer(7).timeout
		check(encounter.reveal_finished and flow.stage==4 and g.checkpoint_id=="CP3","two-second observed blink and real doorway withdrawal; route already released")
		if flow.stage!=4: return finish()
	if flow.stage==4:
		if not await walk_to(Vector3(46.8,4.2,19)): return finish()
		if not await use(flow.landing_door.node.to_global(Vector3(0,1.3,.19)),"door"): return finish()
		await g.get_tree().create_timer(1.3).timeout
		if not await walk_to(Vector3(42.3,0,2.5)): return finish()
		if not await use(Vector3(42.3,1.0,1.3),"recording"): return finish()
		if not await use(Vector3(42.3,1.0,1.3),"recording"): return finish()
		Engine.time_scale=1
		check(g.mode=="playback" and not g.progression.hunt_enabled,"AV playback blocks controls and lethal AI")
		await g.get_tree().create_timer(25).timeout
	Engine.time_scale=1
	check(flow.stage==5 and g.checkpoint_id=="CP4" and not encounter.chase_started,"playback complete safely at CP4")
	var cp3:=FileAccess.open("res://tests/artifacts/flow-cp3.save",FileAccess.WRITE)
	cp3.store_var(g.checkpoint_state)
	cp3.close()
	await capture_image("tape_review")
	g.resume_game()
	g.return_to_checkpoint()
	check(flow.stage==5 and not flow.recording.playing and not encounter.chase_started and g.player.stamina==100,"CP4 retains transcript and rearms doorway, no playback repeat")
	if not await walk_to(Vector3(45,0,10)): return finish()
	check(encounter.chase_started and encounter.approach_time>0,"first chase requires actual AV exit crossing")
	print("FLOW REACTION anchor distance ",g.enemy.position.distance_to(g.player.camera.global_position)," approach seconds ",encounter.approach_time)
	if not await walk_to(Vector3(29,0,10),true): return finish()
	if not await walk_to(Vector3(27,0,5.5),true): return finish()
	await g.get_tree().create_timer(18).timeout
	check(flow.stage>=6,"ordinary sprint and staff-room line-of-sight escape disengages pursuit")
	if flow.stage<6: return finish()
	g.return_to_checkpoint()
	check(flow.flags.get("escape_done",false) and encounter.chase_started and flow.stage==6,"CP5 cannot repeat first pursuit")
	Engine.time_scale=1
	var middle_start: float=g.clock
	var middle_wall_start: int=Time.get_ticks_msec()
	if not await walk_to(Vector3(13.1,4.2,10.8)): return finish()
	check(flow.flags.get("middle_section_active",false) and not flow.can_open(flow.landing_door) and not flow.gates.upper_east.open,"ordinary first escape leads to west shutter, with east bypasses closed")
	if not await use(flow.WINCH_POINT,"winch"): return finish()
	await capture_image("middle_winch")
	Input.action_press("interact")
	var crank_elapsed:=0.0
	while flow.stage==6 and g.mode=="playing" and crank_elapsed<16:
		await g.get_tree().physics_frame
		crank_elapsed+=g.get_physics_process_delta_time()
	Input.action_release("interact")
	check(flow.stage==7 and flow.flags.get("shutter_open",false),"normal held input opens noisy shutter without a control lock")
	if flow.stage!=7: return finish()
	await g.get_tree().create_timer(1.5).timeout
	for point in [Vector3(17.5,4.2,6.9),Vector3(22.5,4.2,6.9),Vector3(22.5,4.2,10),Vector3(25.5,4.2,6.9),Vector3(30.5,4.2,6.9),Vector3(30.5,4.2,10),Vector3(46,4.2,10)]:
		if not await walk_to(point): return finish()
	check(flow.flags.get("far_arrived",false),"U02 and U03 connected routes reach safe far-side checkpoint")
	if not await walk_to(Vector3(46.8,4.2,19)): return finish()
	if not await use(flow.landing_bolt.global_position,"landing_bolt"): return finish()
	await g.get_tree().create_timer(1.3).timeout
	check(flow.can_open(flow.landing_door),"upper-side bolt opens the east stair shortcut")
	if not await walk_to(Vector3(41.8,4.2,26.8)): return finish()
	if not await use(flow.shortcut_latch.global_position,"shortcut_latch"): return finish()
	await g.get_tree().create_timer(1.5).timeout
	if not await walk_to(Vector3(45.8,4.2,33.3)): return finish()
	aim(flow.exit_key.position)
	await capture_image("key_chair")
	if not await use(flow.exit_key.position,"exit_key"): return finish()
	check(flow.stage==8 and g.collected==1 and g.checkpoint_id=="CP6","single entrance key picked up normally")
	print("MIDDLE SECTION ELAPSED wall_seconds=",float(Time.get_ticks_msec()-middle_wall_start)/1000.0," game_seconds=",g.clock-middle_start," (ordinary walking, both room loops and optional shortcuts)")
	g.checkpoint_state.clear()
	g.load_saved_checkpoint()
	check(g.checkpoint_state.get("id","")=="CP6" and g.checkpoint_state.flow.flags.key,"on-disk checkpoint reload retains completed key route")
	g.return_to_checkpoint()
	check(g.collected==1 and not flow.exit_key.visible and flow.flags.get("escape_done",false),"CP6 retains key without replaying chase")
	check(flow.flags.get("east_landing_unbolted",false) and flow.flags.get("south_shortcut_released",false) and flow.flags.get("shutter_open",false),"CP6 retains all middle shortcuts and completed shutter")
	if not await walk_to(Vector3(49.2,0,17.8)): return finish()
	if not await walk_to(Vector3(1.5,0,12)): return finish()
	if not await use(g.layout.EXIT_TARGET,"exit"): return finish()
	await g.get_tree().create_timer(.8).timeout
	if not await use(g.layout.EXIT_TARGET,"exit"): return finish()
	await g.get_tree().create_timer(1).timeout
	check(g.exit_open and g.hardware.released==[true],"one key physically unlocks single entrance lock")
	# Exit area is outside the interior nav bounds: ordinary forward input across threshold.
	aim(Vector3(-2,1.5,12))
	Input.action_press("forward")
	await g.get_tree().create_timer(1.4).timeout
	Input.action_release("forward")
	check(g.ending_started,"normal exit reaches existing ending")
	if g.ending_started:
		await g.get_tree().create_timer(.2).timeout
		for page in range(3):
			g.ending.next.pressed.emit()
			await g.get_tree().create_timer(.1).timeout
			if page==2: await g.get_tree().create_timer(1.4).timeout
			g.ending.next.pressed.emit()
			await g.get_tree().create_timer(.2).timeout
		await g.get_tree().create_timer(1.8).timeout
		check(g.mode=="credits","story pages lead into existing credits")
	finish()
func finish() -> void:
	finished=true
	Engine.time_scale=1
	print("FLOW RESULT failures=",failures)
	g.quit_game(0 if failures==0 else 1)
