extends "res://tests/integration.gd"

func aim(from: Vector3,to: Vector3) -> void:
	g.player.position=from
	g.player.velocity=Vector3.ZERO
	await g.get_tree().physics_frame
	await g.get_tree().physics_frame
	if Vector2(to.x-from.x,to.z-from.z).length()>.001: g.player.look_at(Vector3(to.x,g.player.position.y,to.z))
	g.player.camera.rotation=Vector3(atan2(to.y-g.player.camera.global_position.y,Vector2(to.x-g.player.position.x,to.z-g.player.position.z).length()),0,0)
	await g.get_tree().physics_frame

func door_use(d: Dictionary,from: Vector3) -> void:
	await use(d.node.to_global(Vector3(0,1.3,float(d.track_side)*.27)),from)
	await g.get_tree().create_timer(.75).timeout

func utility(id: String,from: Vector3) -> void:
	await use(g.progression.story_puzzles.utility_nodes[id].global_position,from)
	check(g.progression.story_puzzles.utility_inventory.has(id),"physically collected utility "+id)

func checkpoint_check(id: String) -> void:
	var before: int=g.collected
	var utility_before: Dictionary=g.progression.story_puzzles.utility_inventory.duplicate()
	g.return_to_checkpoint()
	check(g.checkpoint_id==id and g.player.position.distance_to(g.SAFE_CHECKPOINTS[id])<.1,"safe checkpoint position "+id)
	check(g.collected==before and g.progression.story_puzzles.utility_inventory==utility_before and g.player.stamina==100,"checkpoint inventory and stamina "+id)
	check(g.player_voice.pending.is_empty() and not g.player_voice.speaker.playing and not g.progression.cry.playing,"checkpoint flushes stale speech and scream "+id)
	check(g.grace==8 and not g.sees_player(),"checkpoint reorientation and occluded enemy "+id)

func blocked(d: Dictionary,from: Vector3) -> void:
	await aim(from,d.origin+Vector3(0,1.3,0))
	g.toggle_door(d)
	check(d.locked and not d.open,"early gate remains locked "+str(d.get("room","")))
	var before: Vector3=d.node.to_local(g.player.position)
	Input.action_press("forward")
	await g.get_tree().create_timer(.9).timeout
	Input.action_release("forward")
	var after: Vector3=d.node.to_local(g.player.position)
	check(signf(before.z)==signf(after.z),"early gate has blocking physical collision "+str(d.get("room","")))

func run(game: Node) -> void:
	g=game
	seed(15101999)
	g.get_tree().create_timer(260,true,false,true).timeout.connect(func():
		if not finished: push_error("Correction verification watchdog"); g.get_tree().quit(1))
	g.start_game()
	var p: Node=g.progression.story_puzzles
	var journal: Node=g.progression.evidence
	var walker=preload("res://tests/layout_shell.gd").new()
	walker.game=g
	check(g.layout.placement.rejected.is_empty(),"shared placement categories reject no current authored assembly")
	check(g.get_tree().get_nodes_in_group("exterior_panes").is_empty(),"no landscape cards remain in apertures")
	check(g.doors.size()==28 and g.layout.rooms.size()==17,"final shell has room doors plus two real stair gates")
	if "--capture-only" in OS.get_cmdline_user_args():
		g.capture()
		await g.get_tree().create_timer(.20).timeout
		check(g.capture_ghost.playing and g.capture_ghost.stream==g.sounds.sakiko_humming,"capture starts with Sakiko's creepy vocal")
		await g.get_tree().create_timer(.25).timeout
		check(g.capture_ghost.playing and g.capture_ghost.stream==g.sounds.sakiko_scream,"mouth approach has Sakiko's scream")
		await g.get_tree().create_timer(.88).timeout
		var male_playing:=false
		for node in g.get_children():
			if node is AudioStreamPlayer and node.stream==g.sounds.player_pain and node.playing: male_playing=true
		check(g.pain_triggered and g.curtain.modulate.a==1 and male_playing and not g.capture_ghost.playing,"blackout has dry male pain without overlapping female scream")
		await g.get_tree().create_timer(.65).timeout
		check(g.mode=="dead","revised capture reaches death screen")
		finished=true
		print("CAPTURE VERIFY COMPLETE: ",count," checks; failures: ",failed)
		g.quit_game()
		return
	if "--routes-only" in OS.get_cmdline_user_args():
		await route_focus()
		finished=true
		print("ROUTE VERIFY COMPLETE: ",count," checks; failures: ",failed)
		if failed: g.get_tree().quit(1)
		else: g.quit_game()
		return
	if "--audio-only" in OS.get_cmdline_user_args():
		await audio_focus()
		finished=true
		print("AUDIO VERIFY COMPLETE: ",count," checks; failures: ",failed)
		if failed: g.get_tree().quit(1)
		else: g.quit_game()
		return
	if "--exit-only" in OS.get_cmdline_user_args():
		await exit_focus()
		finished=true
		print("EXIT VERIFY COMPLETE: ",count," checks; failures: ",failed)
		if failed: g.get_tree().quit(1)
		else: g.quit_game()
		return
	if "--mechanisms-only" not in OS.get_cmdline_user_args():
		g.play_intro()
		await g.get_tree().process_frame
		check(not g.hud.visible and not g.progression.stamina_bar.visible and not g.interaction_hints.visible,"intro hides gameplay interfaces")
		var skip:=InputEventAction.new()
		skip.action="interact";skip.pressed=true
		g.progression._unhandled_input(skip)
		g.progression._unhandled_input(skip)
		check(g.progression.intro_time==125 and g.mode=="intro","skip enters mandatory shared transition once")
		Engine.time_scale=6
		await g.get_tree().create_timer(6).timeout
		check(g.progression.intro_dark and g.progression.intro_chime,"sleep black and one normal-pitch chime")
		await g.get_tree().create_timer(15).timeout
		Engine.time_scale=1
		check(g.mode=="playing" and not g.expansion.figures.visible,"skip finishes waking in same classroom")
		g.play_intro()
		Engine.time_scale=12
		await g.get_tree().create_timer(146).timeout
		Engine.time_scale=1
		check(g.mode=="playing" and g.player.position.distance_to(g.layout.NIGHT)<.2,"normal full lesson reaches same night anchor")
	g.start_game()
	await use(g.layout.EXIT_TARGET,Vector3(1.3,0,12))
	check(g.progression.discovered and not g.player_voice.speaker.playing,"actual exit attempt establishes objective without spoken dialogue")
	for d in g.doors:
		if d.get("room","")=="STAIR_W": await blocked(d,Vector3(9.5,0,19))
		if d.get("room","")=="STAIR_E": await blocked(d,Vector3(46.9,0,19))
	await blocked(g.layout.room_doors.G05[0],Vector3(45,0,9.5))
	await blocked(g.layout.room_doors.U06[1],Vector3(22,4.2,26.9))
	await container("archive_12",Vector3(14.3,4.2,34.04))
	check(not p.containers.archive_12.open,"guessing shelf number cannot bypass portrait rear key")
	await document("handover",Vector3(26.2,0,7.0))
	await container("service_drawer",Vector3(26.2,0,7.3))
	await use(p.service_key.global_position,Vector3(26.2,0,7.1))
	check(p.service_taken,"service drawer utility key reachable")
	await container("staff_cabinet",Vector3(30.2,0,2))
	await key(0,Vector3(30.2,0,2))
	await checkpoint_check("key1")
	await utility("upper",Vector3(30.4,0,1.3))
	await utility("festival",Vector3(30.4,0,1.3))
	check(g.progression.encounters_controller.chair_done and not g.progression.hunt_enabled,"one staff-completion scrape, no early hunting")
	for d in g.doors:
		if str(d.get("room","")).begins_with("STAIR_"):
			await door_use(d,Vector3(46.9,0,19) if d.room=="STAIR_E" else Vector3(9.5,0,19))
			check(d.open and not d.locked,"same reusable upper key opens "+str(d.room))
	await document("sketch",Vector3(29.6,0,33.5))
	await container("art_1",Vector3(27,0,33.7))
	await container("packing_envelope",Vector3(27,0,34.0))
	await document("original",Vector3(27,0,34.0))
	check(not g.player_voice.attempted.has("P05"),"original photograph gives no unseen comparison knowledge")
	await utility("archive",Vector3(27.05,0,34.0))
	await door_use(g.layout.room_doors.U07[0],Vector3(26,4.2,26.6))
	check(g.layout.room_doors.U07[0].open,"art envelope grants physical exhibition access")
	await use(p.evidence_models.display.global_position,Vector3(32,4.2,34.3))
	check(g.mode=="document","altered F-12 panel can be inspected")
	journal.reverse=true;journal.update_preview();journal.refresh_sleeve_action()
	check(journal.sleeve_button.visible and journal.entries.display.reverse.contains("B3"),"physical portrait reverse exposes existing compartment reference and sleeve key")
	p.collect_utility("compartment")
	journal.close()
	check(g.progression.encounters_controller.portrait_seen and not g.progression.hunt_enabled,"portrait close schedules one distant reveal before hunting")
	await door_use(g.layout.room_doors.U06[1],Vector3(22,4.2,26.9))
	await container("archive_12",Vector3(14.3,4.2,34.04))
	print("ARCHIVE STATE open=",p.containers.archive_12.open," utility=",p.utility_inventory," keypoint=",g.keys[1].global_position," keyvisible=",g.keys[1].visible)
	await aim(Vector3(13.8,4.2,34.05),g.keys[1].global_position)
	var debug_q:=PhysicsRayQueryParameters3D.create(g.player.camera.global_position,g.keys[1].global_position,1)
	debug_q.exclude=[g.player.get_rid()]
	var debug_hit: Dictionary=g.get_world_3d().direct_space_state.intersect_ray(debug_q)
	print("KEY2 RAY ",debug_hit.get("position",Vector3.INF)," object=",debug_hit.get("collider",null)," dot=",(-g.player.camera.global_basis.z).dot((g.keys[1].global_position-g.player.camera.global_position).normalized()))
	if not debug_hit.is_empty(): print("KEY2 COLLIDER ",debug_hit.collider.get_path())
	await key(1,Vector3(13.8,4.2,34.05))
	await checkpoint_check("key2")
	await utility("tape",Vector3(14.1,4.2,34.05))
	await utility("media",Vector3(14.37,4.2,34.05))
	await document("program",Vector3(14.68,4.2,34.04))
	check(journal.entries.program.body.contains("15 OCTOBER") and journal.entries.recording.body.contains("Month, then day"),"muted-voice transcript and program solve 1015")
	if g.collected!=2: finished=true; g.get_tree().quit(1); return
	await door_use(g.layout.room_doors.U05[0],Vector3(45,4.2,9.5))
	await use(target("recording").point,Vector3(41.65,4.2,2.7))
	check(p.inserted and not p.played,"cassette manually inserts before transport play")
	await use(target("recording").point,Vector3(41.65,4.2,2.7))
	check(p.recording.playing and not g.player_voice.speaker.playing and g.player_voice.pending.is_empty(),"actual tape plays without overlapping player speech")
	await g.get_tree().create_timer(p.recording.stream.get_length()+.5).timeout
	# The audio callback uses its own clock; a loaded/headless run can deliver
	# stream completion after a SceneTree timer. Await the real transport end.
	for attempt in range(100):
		if p.tape_done: break
		await g.get_tree().create_timer(.1).timeout
	print("TAPE COMPLETION mode=",g.mode," done=",p.tape_done," playing=",p.recording.playing," position=",p.recording.get_playback_position()," hunt=",g.progression.hunt_enabled)
	check(p.tape_done and not g.progression.hunt_enabled,"recording completion waits for released inspection controls")
	if g.mode=="document": journal.close()
	await g.get_tree().create_timer(3.4).timeout
	check(g.progression.hunt_enabled and g.progression.encounters_controller.chase_started and g.grace<=0,"tape opens a genuine lethal encounter")
	Input.action_press("sprint")
	var escaped:=true
	for point in [Vector3(44.8,4.2,4.5),Vector3(45,4.2,9.5),Vector3(46,4.2,17.8)]:
		if not await walker.walk_to(point): escaped=false; break
	var descending: PackedVector3Array=g.layout.stair_routes[1].duplicate();descending.reverse()
	if escaped:
		for point in descending:
			if not await walker.walk_to(point): escaped=false; break
	Input.action_release("sprint")
	check(escaped and g.mode=="playing","first lethal pursuit has a physically traversable east-stair escape")
	check(not g.sees_player(),"corners and slabs break enemy sight after escape")
	if g.mode!="playing": finished=true; g.get_tree().quit(1); return
	await checkpoint_check("tape")
	await door_use(g.layout.room_doors.G05[0],Vector3(45,0,9.5))
	await container("av_case",Vector3(46.2,0,2.8))
	check(not p.submit_combination("1001") and p.submit_combination("1015"),"manual wheels reject wrong and accept known correct date")
	await g.get_tree().create_timer(.8).timeout
	await key(2,Vector3(46,0,2.3))
	await checkpoint_check("key3")
	await utility("rehearsal_U08",Vector3(46.5,0,2.5))
	await document("case_reference",Vector3(46.35,0,2.5))
	await door_use(g.layout.room_doors.G09[0],Vector3(45,0,26.5))
	await use(target("shelf").point,Vector3(44.5,0,31.7))
	check(p.brake and not p.opened,"shelf brake releases before moving")
	g.interact();await g.get_tree().create_timer(1.4).timeout
	check(p.opened,"mobile shelf clears the report sleeve on its visible track")
	await document("maintenance",Vector3(46.3,0,34.5))
	await door_use(g.layout.room_doors.U08[0],Vector3(45,4.2,26.6))
	await container("bag",Vector3(45.6,4.2,33.3))
	await key(3,Vector3(45.4,4.2,33.4))
	await checkpoint_check("key4")
	await document("letter",Vector3(45.8,4.2,33.5))
	check(g.collected==4 and journal.entries.maintenance.body.contains("18:10"),"four physical keys and unchanged unresolved knocking detail")
	# Capture remains enabled throughout the flow; contact test uses no intervening wall.
	await aim(Vector3(28,0,10),Vector3(28,1.4,10.8))
	g.grace=0;g.enemy.position=Vector3(28,1.4,10.8);g.ai_state="search";g.path.clear()
	g._physics_process(.016)
	check(g.mode=="capture" and not g.player_voice.speaker.playing,"real close contact captures and preempts dialogue")
	await g.get_tree().create_timer(1.3).timeout
	check(g.pain_triggered and g.curtain.modulate.a==1,"capture cuts black before synchronized pain")
	await g.get_tree().create_timer(.65).timeout
	check(g.mode=="dead","capture reaches death")
	g.return_to_checkpoint()
	check(g.collected==4 and p.tape_done and p.opened and p.rehearsal_taken and g.checkpoint_id=="key4","death restores completed phases without replaying ambush or duplicating keys")
	await verify_stairs()
	await aim(Vector3(28,0,10),Vector3(28,5.7,10))
	g.enemy.position=Vector3(28,5.7,10);g.player.lamp.show()
	check(not g.sees_player() and not g.flashlight_exposure(),"floor slabs block creature and flashlight sight")
	for i in range(4):
		await use(g.layout.EXIT_TARGET,Vector3(1.3,0,12))
		await g.get_tree().create_timer(.6).timeout
		for attempt in range(20):
			if not g.hardware.busy: break
			await g.get_tree().create_timer(.05).timeout
		check(g.hardware.released[i] and not g.hardware.locks[i].lock.visible,"matching metal padlock releases "+str(i+1))
	await use(g.layout.EXIT_TARGET,Vector3(1.3,0,12))
	await g.get_tree().create_timer(.8).timeout
	check(g.exit_open,"entrance opens after all physical padlocks release")
	g.player.rotation.y=PI/2;g.player.camera.rotation=Vector3.ZERO
	Input.action_press("forward");await g.get_tree().create_timer(1.5).timeout;Input.action_release("forward")
	check(g.mode=="ending" and is_instance_valid(g.ending) and not g.player_voice.speaker.playing,"walking outside starts preserved silent ending")
	if is_instance_valid(g.ending): g.ending.start_credits();await g.get_tree().create_timer(1).timeout;g.ending.finish();await g.get_tree().create_timer(1).timeout
	check(g.mode=="menu","credits return to unchanged menu")
	finished=true
	print("CORRECTION VERIFY COMPLETE: ",count," checks; failures: ",failed)
	if failed: g.get_tree().quit(1)
	else: g.quit_game()

func verify_stairs() -> void:
	g.player.position=Vector3(4,0,12)
	g.grace=0
	g.enemy.position=Vector3(10,1.5,19)
	g.ai_state="investigate";g.state_time=0;g.navigate(Vector3(10,5.7,19))
	Engine.time_scale=3
	await g.get_tree().create_timer(22).timeout
	Engine.time_scale=1
	check(g.enemy.position.y>5.3,"Sakiko physically climbs west stair")
	g.enemy.position=Vector3(46,5.7,19)
	g.ai_state="investigate";g.state_time=0;g.navigate(Vector3(46,1.5,19))
	Engine.time_scale=3
	await g.get_tree().create_timer(22).timeout
	Engine.time_scale=1
	check(g.enemy.position.y<2,"Sakiko physically descends east stair")

func use(point: Vector3,from: Vector3) -> void:
	await aim(from,point)
	var chosen: Dictionary=g.interactable()
	print("USE ",chosen.get("type","none"),":",chosen.get("id","")," eye=",g.player.camera.global_position," point=",point," mode=",g.mode)
	if chosen.is_empty():
		var q:=PhysicsRayQueryParameters3D.create(g.player.camera.global_position,point,1)
		q.exclude=[g.player.get_rid()]
		print("MISS RAY ",g.get_world_3d().direct_space_state.intersect_ray(q).get("position",Vector3.INF))
	g.interact()

func exit_focus() -> void:
	g.collected=4
	for key_node in g.keys: key_node.set_meta("collected",true)
	var walk=preload("res://tests/layout_shell.gd").new()
	walk.game=g
	g.player.position=Vector3(3.2,-.13,12)
	check(await walk.walk_to(Vector3(5.1,0,12)),"controller climbs actual low genkan step")
	for i in range(4):
		await use(g.layout.EXIT_TARGET,Vector3(1.3,-.13,12))
		await g.get_tree().create_timer(.6).timeout
		check(g.hardware.released[i],"physical padlock release "+str(i+1))
	await use(g.layout.EXIT_TARGET,Vector3(1.3,-.13,12))
	await g.get_tree().create_timer(.8).timeout
	g.save_checkpoint("key4")
	g.return_to_checkpoint()
	check(g.exit_open and g.hardware.released.all(func(value): return value) and absf(g.exit_panels[0].position.z-g.progression.exit_origins[0].z+1.3)<.01,"checkpoint preserves released hardware and open entrance leaves")
	g.player.position=Vector3(1.3,-.13,12)
	g.player.rotation.y=PI/2;g.player.camera.rotation=Vector3.ZERO
	Input.action_press("forward");await g.get_tree().create_timer(1.5).timeout;Input.action_release("forward")
	print("EXIT FOOT ",g.player.position," mode=",g.mode)
	check(g.mode=="ending","flush tiled apron permits actual escape ending")
	if is_instance_valid(g.ending): g.ending.start_credits();await g.get_tree().create_timer(1).timeout;g.ending.finish();await g.get_tree().create_timer(1).timeout
	check(g.mode=="menu","ending credits return to menu")

func audio_focus() -> void:
	var p: Node=g.progression.story_puzzles
	var v: Node=g.player_voice
	v.wake_delay=-1
	await document("sketch",Vector3(29.6,0,33.5))
	await g.get_tree().create_timer(.1).timeout
	check(v.active=="P06" and v.speaker.playing and v.subtitle.text==v.lines.P06.text,"actual inspected discovery triggers matching audio and subtitle")
	v.request("P04")
	await g.get_tree().create_timer(3).timeout
	check(not v.played.has("P04"),"ordinary comments respect 25-second minimum")
	v.clock=v.last_comment+15
	v._process(.016)
	check(not v.has_event("P04"),"outdated comment expires instead of building backlog")
	v.reference_known=false
	v.hint()
	check(not v.attempted.has("H02"),"archive hint has no unseen reference knowledge")
	v.reference_known=true
	v.hint()
	var queued: int=v.pending.size()
	v.hint()
	check(v.has_event("H02") and v.pending.size()==queued,"one eligible hint per phase")
	var voice_bus: int=AudioServer.get_bus_index("Voice")
	var original_mute: bool=AudioServer.is_bus_mute(voice_bus)
	AudioServer.set_bus_mute(voice_bus,true)
	p.utility_inventory.tape=true
	await use(target("recording").point,Vector3(41.65,4.2,2.7))
	await use(target("recording").point,Vector3(41.65,4.2,2.7))
	check(p.recording.playing and not v.speaker.playing and v.pending.is_empty(),"tape preempts and flushes player comments")
	var original_subtitles: bool=g.settings.subtitles
	g.settings.subtitles=false
	p._process(.016);v._process(.016)
	check(not p.captions.visible and not v.subtitle_panel.visible,"subtitle option hides dialogue captions")
	g.settings.subtitles=true
	p._process(.016)
	check(p.captions.visible,"muted tape retains enabled captions")
	v.request("P02",2)
	await g.get_tree().create_timer(p.recording.stream.get_length()+.4).timeout
	check(p.tape_done and g.progression.evidence.entries.recording.body.contains("Month, then day"),"muted playback completes with permanent exact transcript")
	g.progression.evidence.close()
	await g.get_tree().create_timer(3.5).timeout
	check(not v.played.has("P02") and not v.speaker.playing,"stale player speech does not fill tape silence or first danger")
	check(g.checkpoint_id=="tape" and g.checkpoint_state.voice.played.has("P06"),"tape checkpoint persists one-shot discovery flags")
	check(p.submit_combination("1015"),"muted-voice clue still solves exact case code")
	g.return_to_checkpoint()
	v.request("P06")
	check(v.pending.is_empty() and v.played.has("P06") and p.tape_done,"retry flushes queue and does not replay discovery or first tape")
	AudioServer.set_bus_mute(voice_bus,original_mute)
	g.settings.subtitles=original_subtitles
	g.start_game()
	v.wake_delay=-1
	g.player.position=Vector3(2,-.13,12)
	g.player.rotation.y=-PI/2
	Input.action_press("forward")
	await g.get_tree().create_timer(.65).timeout
	Input.action_release("forward")
	var tiled:=false
	for event in g.audio_trace:
		if str(event.clip).begins_with("foot_tile"): tiled=true
	check(tiled,"actual tile displacement selects tile footsteps")
	g.player.position=Vector3(4.6,.50,19.6)
	g.player.rotation.y=PI
	Input.action_press("forward")
	await g.get_tree().create_timer(.65).timeout
	Input.action_release("forward")
	var stair:=false
	for event in g.audio_trace:
		if str(event.clip).begins_with("foot_stair"): stair=true
	check(stair,"actual ramp displacement selects stair footsteps")
	g.player.position=Vector3(46.8,0,10)
	g.player.rotation.y=-PI/2
	Input.action_press("forward")
	await g.get_tree().create_timer(1).timeout
	var blocked_steps: int=g.player.footstep_count
	await g.get_tree().create_timer(.7).timeout
	check(g.player.footstep_count==blocked_steps,"blocked grounded input produces no footsteps")
	Input.action_release("forward")
	g.player.position=Vector3(10,1.5,10)
	g.player.velocity=Vector3.ZERO
	var air_steps: int=g.player.footstep_count
	Input.action_press("forward")
	await g.get_tree().create_timer(.1).timeout
	check(g.player.footstep_count==air_steps,"airborne displacement produces no footsteps")
	Input.action_release("forward")
	g.player.position=Vector3(10,0,10)
	g.player.rotation.y=-PI/2
	g.player.reset()
	await g.get_tree().create_timer(.1).timeout
	Input.action_press("forward");Input.action_press("sprint")
	await g.get_tree().create_timer(6.3).timeout
	check(g.player.exhausted and g.player.stamina<5 and g.player.pant.playing,"six-second sustained sprint produces real exhaustion and one pant source")
	Input.action_release("forward");Input.action_release("sprint")
	await g.get_tree().create_timer(7).timeout
	check(g.player.stamina>95 and not g.player.pant.playing,"recovery stops panting at full stamina")

func route_focus() -> void:
	for d in g.doors:
		d.locked=false
		g.toggle_door(d,true)
	await g.get_tree().create_timer(.8).timeout
	var w=preload("res://tests/layout_shell.gd").new()
	w.game=g
	Engine.time_scale=3
	g.player.position=Vector3(10,0,10)
	for point in [Vector3(46,0,10),Vector3(46,0,26),Vector3(10,0,26),Vector3(10,0,19)]:
		if not await w.walk_to(point): check(false,"furnished ground loop");Engine.time_scale=1;return
	check(true,"furnished ground loop connected around courtyard")
	for point in g.layout.stair_routes[0]:
		if not await w.walk_to(point): check(false,"player west stair ascent");Engine.time_scale=1;return
	check(absf(g.player.position.y-4.2)<.2,"player physically ascends west stairs and landing")
	for point in [Vector3(10,4.2,19),Vector3(10,4.2,10),Vector3(46,4.2,10),Vector3(46,4.2,26),Vector3(10,4.2,26),Vector3(10,4.2,19),Vector3(10,4.2,10),Vector3(46,4.2,10),Vector3(46,4.2,19)]:
		if not await w.walk_to(point):check(false,"furnished upper loop");Engine.time_scale=1;return
	check(true,"furnished upper loop connected around courtyard")
	var down: PackedVector3Array=g.layout.stair_routes[1].duplicate();down.reverse()
	for point in down:
		if not await w.walk_to(point):check(false,"player east stair descent");Engine.time_scale=1;return
	check(absf(g.player.position.y)<.2,"player physically descends east stairs and landing")
	for id in g.layout.room_doors:
		var d: Dictionary=g.layout.room_doors[id][0]
		g.player.position=d.origin+Vector3(0,.02,1.3 if d.north else -1.3)
		g.player.velocity=Vector3.ZERO
		await g.get_tree().physics_frame
		check(await w.walk_to(d.origin+Vector3(0,0,-1.5 if d.north else 1.5)),id+" furnished entrance and changed frontage traversable")
	Engine.time_scale=1
	var d: Dictionary=g.layout.room_doors.G01[0]
	g.player.position=d.origin+Vector3(0,0,.25)
	g.toggle_door(d)
	check(d.open and not d.busy,"door refuses to close on a player in its aperture")
	g.player.position=d.origin+Vector3(0,0,2)
	g.toggle_door(d)
	await g.get_tree().create_timer(.20).timeout
	g.player.position=d.origin+Vector3(0,0,.25)
	await g.get_tree().create_timer(.9).timeout
	check(d.open and not d.busy,"closing door reverses safely when obstructed")
