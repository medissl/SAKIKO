extends "res://tests/flow_check.gd"
func fixture() -> void:
	g.start_game()
	flow=g.progression.story_puzzles
	flow.stage=6
	flow.flags={"original":true,"cassette":true,"portrait":true,"tape_done":true,"chase_started":true,"escape_done":true,"middle_section_active":true,"shutter_progress":0.0}
	flow.apply_state()
	var encounter: RefCounted=g.progression.encounters_controller
	encounter.chase_started=true
	encounter.reveal_finished=true
	encounter.pressure_cooldown=55
	g.enemy.position=Vector3(51.4,1.5,17.8)
	g.enemy.show()
	g.ai_state="roam"
	g.grace=0
	g.path.clear()
	g.save_checkpoint("CP5")
	g.player.position=Vector3(13.1,4.2,10.8)
	await g.get_tree().physics_frame
	aim(flow.WINCH_POINT)
func hold(seconds: float) -> void:
	aim(flow.WINCH_POINT)
	Input.action_press("interact")
	await g.get_tree().create_timer(seconds).timeout
	Input.action_release("interact")
	await g.get_tree().process_frame
	await g.get_tree().physics_frame
func run(game: Node) -> void:
	g=game
	Engine.time_scale=3
	await fixture()
	check(g.interactable(true).get("type","")=="winch","west-facing hand control is visible and reachable")
	check(not flow.can_open(flow.landing_door) and not flow.gates.upper_east.open and not flow.gates.upper_north_east.open,"two east bypasses and jammed shutter physically closed")
	check(flow.can_open(g.layout.room_doors.U01[0]) and flow.can_open(g.layout.room_doors.U01[1]),"both U01 doors form the west-side retreat loop")
	await hold(2)
	var partial: float=flow.flags.shutter_progress
	check(partial>.13 and partial<.2 and not flow.cranking and not flow.winch_audio.playing,"hold advances twelve-second task; release stops instantly")
	check(flow.gates.upper_north_east.root.position.y<5.4,"partial opening remains below standing clearance with matching collider")
	g.checkpoint_state.clear()
	g.load_saved_checkpoint()
	g.return_to_checkpoint()
	check(is_equal_approx(float(flow.flags.shutter_progress),partial),"partial progress survives on-disk reload at the safe anchor")
	check(g.nav.get_point_position(g.nav.get_closest_point(g.enemy.position)).distance_to(g.enemy.position)<.1,"middle retry actor anchor is on clear traversable floor")
	check(not flow.flags.get("middle_warning",false),"retry rearms the quiet approach cue without replaying story scares")
	g.player.position=Vector3(13.1,4.2,10.8)
	await g.get_tree().physics_frame
	aim(flow.WINCH_POINT)
	Input.action_press("interact")
	await g.get_tree().create_timer(.2).timeout
	var before: Vector3=g.player.position
	Input.action_press("back")
	await g.get_tree().create_timer(.5).timeout
	Input.action_release("back")
	Input.action_release("interact")
	check(g.player.position.distance_to(before)>.6 and not flow.cranking and not flow.winch_audio.playing,"holding crank never locks movement; leaving reach stops operation")
	g.player.position=Vector3(13.1,4.2,10.8)
	await g.get_tree().physics_frame
	aim(flow.WINCH_POINT)
	Input.action_press("interact")
	await g.get_tree().create_timer(.3).timeout
	g.input_focused=false
	g._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not flow.cranking and not flow.winch_audio.playing,"focus loss stops crank audio and operation")
	Input.action_release("interact")
	g.input_focused=true
	aim(flow.WINCH_POINT)
	Input.action_press("interact")
	await g.get_tree().create_timer(.2).timeout
	g.show_pause()
	check(not flow.cranking and not flow.winch_audio.playing,"pause clears the hand mechanism")
	Input.action_release("interact")
	g.resume_game()
	# Noise gives an investigation point at the station, never a live player transform.
	g.enemy.position=Vector3(9,5.7,16)
	g.ai_state="roam"
	flow.mechanism_noise()
	check(g.ai_state=="investigate" and g.last_seen==flow.WINCH_POINT,"same-floor mechanical noise reports the fixed station")
	g.enemy.position=Vector3(9,1.5,16)
	g.ai_state="roam"
	g.last_seen=Vector3(1,1,1)
	flow.mechanism_noise()
	check(g.ai_state=="roam" and g.last_seen==Vector3(1,1,1),"shutter noise cannot reveal coordinates through the floor")
	# Focused closed-barrier fixture: one actor on each side, no damage exemption.
	g.player.position=Vector3(15.4,4.2,10)
	g.enemy.position=Vector3(16.6,5.7,10)
	g.ai_state="investigate"
	g.lost_sight=0
	g.navigate(flow.WINCH_POINT)
	check(g.path.is_empty() and not g.clear_line(g.enemy.position,g.player.camera.global_position),"closed shutter blocks creature route and contact sight")
	await g.get_tree().create_timer(.3).timeout
	check(g.mode=="playing" and g.enemy.position.x>16.5,"creature cannot phase or capture through the partial shutter")
	g.player.position=Vector3(13.1,4.2,10.8)
	await g.get_tree().physics_frame
	# Real approach from west, with lethal contact enabled throughout.
	g.enemy.position=Vector3(9,5.7,16)
	g.enemy.look_at(flow.WINCH_POINT)
	g.ai_state="roam"
	g.path.clear()
	g.visual_notice=0
	g.lost_sight=0
	aim(flow.WINCH_POINT)
	Input.action_press("interact")
	var contact_wait:=0.0
	while g.mode=="playing" and contact_wait<18:
		await g.get_tree().physics_frame
		contact_wait+=g.get_physics_process_delta_time()
	Input.action_release("interact")
	print("MIDDLE ACTUAL CONTACT seconds=",contact_wait," progress=",flow.flags.get("shutter_progress",0))
	check(g.mode=="capture","standing at the noisy station permits a genuine physical capture")
	var death_progress: float=flow.flags.shutter_progress
	await g.get_tree().create_timer(4.1).timeout
	check(g.mode=="dead","middle capture completes the normal death sequence")
	g.return_to_checkpoint()
	check(float(flow.flags.shutter_progress)>=death_progress and not flow.cranking,"death keeps the greatest earned shutter effort")
	# Finish normally; the same physical actor remains distant downstairs after retry.
	g.player.position=Vector3(13.1,4.2,10.8)
	await g.get_tree().physics_frame
	await hold(12)
	await g.get_tree().create_timer(1.6).timeout
	check(flow.stage==7 and flow.flags.shutter_open and flow.flags.shutter_progress==1 and g.checkpoint_id=="MIDDLE_SHUTTER","shutter opens once and saves completion checkpoint")
	check(flow.gates.upper_north_east.root.position.y>7.2 and not flow.gates.upper_east.open,"real north opening; south bypass remains shut")
	var save:=FileAccess.open("res://tests/artifacts/middle-open.save",FileAccess.WRITE)
	save.store_var(g.checkpoint_state)
	save.close()
	# Approach-only latch checks are separate from the actual traversals.
	g.player.position=Vector3(49.2,4.2,19)
	flow.interact({"type":"landing_bolt"})
	check(not flow.flags.get("east_landing_unbolted",false),"east landing cannot be unbolted from below/stair side")
	g.player.position=Vector3(39,4.2,26)
	flow.interact({"type":"shortcut_latch"})
	check(not flow.flags.get("south_shortcut_released",false),"south shortcut cannot be released from the exhibition side")
	print("MIDDLE MECHANISM RESULT failures=",failures)
	finish()
