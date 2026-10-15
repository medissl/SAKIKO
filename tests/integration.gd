extends RefCounted
var g: Node
var failed := false
var count := 0

func check(ok: bool,description: String) -> void:
	count += 1
	if not ok:
		failed = true
		push_error("CHECK FAILED: "+description)
	print("CHECK ","PASS " if ok else "FAIL ",description)

func aim(from: Vector3,to: Vector3) -> void:
	g.player.position = from
	g.player.velocity = Vector3.ZERO
	await g.get_tree().create_timer(.09).timeout
	g.player.camera.look_at(to)
	await g.get_tree().physics_frame

func use_point(point: Vector3,from: Vector3) -> void:
	await aim(from,point)
	g.interact()

func run(game: Node) -> void:
	g = game
	g.start_game()
	g.grace = 999
	await g.get_tree().create_timer(.8).timeout
	var puzzles = g.progression.story_puzzles
	var journal = g.progression.evidence
	check(g.doors.size()==24 and g.keys.size()==4 and g.entrance_locks.size()==4,"four keys and four visible entrance locks")
	check(not g.keys[0].visible and not puzzles.solved.has(true),"all four rewards start hidden")
	check(g.music.stream.get_length()>30 and g.sounds.sakiko_scream!=null,"music and recorded ghost vocal load")
	check(g.player.pant.stream.resource_path.ends_with("player_breath_male.mp3") and g.progression.cry.stream.resource_path.ends_with("sakiko_scream.ogg"),"male player breath and female ghost scream assigned separately")
	g.play_intro()
	check(g.mode=="intro" and g.expansion.figures.visible,"daytime intro with occupants")
	var skip := InputEventAction.new()
	skip.action = "interact"
	skip.pressed = true
	g.progression._unhandled_input(skip)
	check(g.mode=="playing" and not g.expansion.figures.visible,"intro can be skipped")
	g.play_intro()
	Engine.time_scale = 6
	await g.get_tree().create_timer(16).timeout
	Engine.time_scale = 1
	check(g.mode=="playing" and not g.progression.eyelids.visible,"intro completes naturally")
	g.start_game()
	g.grace = 999
	await use_point(Vector3(-26.42,1.4,0),Vector3(-24.8,0,0))
	check(g.progression.discovered and g.progression.objective().contains("/4"),"entrance discovers four-key objective")
	await use_point(Vector3(-18.6,1.35,-15.2),Vector3(-18.6,0,-13.4))
	check(g.mode=="document" and journal.collected.has("preparation"),"preparation photograph uses actual inspection target")
	journal.reverse = true
	journal.show_entry()
	check(journal.reverse and journal.entries.preparation.reverse.contains("Aya"),"photograph reverse preserves classmate clue")
	g.resume_game()
	await use_point(Vector3(-19.9,.85,-13.4),Vector3(-18.3,0,-13.4))
	check(puzzles.solved[0] and journal.collected.has("original") and journal.collected.has("folded"),"marked desk yields first key and original photo/note")
	g.resume_game()
	await use_point(g.keys[0].position,Vector3(-18.3,0,-13.4))
	check(g.collected==1,"desk key physically reachable")
	g.interact()
	check(g.collected==1,"duplicate pickup prevented")
	await use_point(Vector3(52.8,1.45,-15.4),Vector3(52.8,0,-13.5))
	check(journal.collected.has("sketch"),"mounting sketch can be inspected")
	g.resume_game()
	for i in range(3):
		await use_point(puzzles.piece_origins[i],Vector3(puzzles.piece_origins[i].x,0,-13.0))
		check(puzzles.held==i,"take unique display piece %d" % i)
		await use_point(puzzles.mount_points[i],Vector3(puzzles.mount_points[i].x,0,-13.4))
		check(puzzles.slots[i]==i,"mount display piece %d" % i)
	check(puzzles.solved[1] and puzzles.held<0,"three physical decorations release display compartment")
	await use_point(g.keys[1].position,Vector3(56,0,-12.8))
	check(g.collected==2,"display key physically reachable")
	await use_point(Vector3(55.1,1.1,-14.6),Vector3(55.1,0,-12.8))
	check(journal.collected.has("display"),"monstrous festival head photograph inspectable")
	g.resume_game()
	await use_point(Vector3(21,1.2,15.1),Vector3(21,0,13.5))
	check(not puzzles.solved[2],"AV case requires power and tape clue")
	await use_point(Vector3(12,1.5,15.2),Vector3(12,0,13.4))
	check(puzzles.power,"nearby labeled switch restores AV power")
	await use_point(Vector3(16,1.15,15.1),Vector3(16,0,13.3))
	check(puzzles.played and journal.collected.has("recording") and journal.entries.recording.body.contains("B two"),"recording has spoken clue and permanent readable captions")
	g.resume_game()
	await use_point(Vector3(21,1.2,15.1),Vector3(21,0,13.5))
	check(puzzles.solved[2] and journal.collected.has("account"),"B2 case yields key and exact handwritten account")
	g.resume_game()
	await use_point(g.keys[2].position,Vector3(21,0,13.3))
	check(g.collected==3,"AV key physically reachable")
	await use_point(Vector3(72,1.5,-15.35),Vector3(73.2,0,-13.5))
	check(journal.collected.has("plan"),"maintenance plan identifies concealed storeroom")
	g.resume_game()
	await use_point(Vector3(78.2,1,12),Vector3(77,0,12))
	check(puzzles.brake and not puzzles.opened,"archive shelf floor brake releases first")
	g.interact()
	await g.get_tree().create_timer(1.4).timeout
	check(puzzles.opened and puzzles.solved[3] and puzzles.shelf.position.z>15,"shelf physically reveals storeroom")
	await aim(Vector3(77,0,12),Vector3(82,1.58,12))
	g.player.rotation.y = -PI/2
	g.player.camera.rotation = Vector3.ZERO
	Input.action_press("forward")
	await g.get_tree().create_timer(1).timeout
	Input.action_release("forward")
	check(g.player.position.x>79.1,"physical player can enter concealed storeroom")
	await use_point(Vector3(81.1,.95,11.05),Vector3(80,0,11.1))
	if not journal.collected.has("letter"): print("LETTER DIAGNOSTIC ",g.mode," position ",g.player.position," eye ",g.player.camera.global_position," target ",g.interactable())
	check(journal.collected.has("letter"),"Sakiko's ordinary letter can be collected")
	g.resume_game()
	await use_point(Vector3(81.6,1.4,15.6),Vector3(80.7,0,14.4))
	check(journal.collected.has("maintenance") and journal.entries.maintenance.body.contains("18:10"),"two caretaker entries remain intact")
	g.resume_game()
	await use_point(g.keys[3].position,Vector3(80.2,0,14.4))
	check(g.collected==4,"fourth key physically reachable")
	journal.show_journal()
	check(g.mode=="document" and journal.journal_open,"journal reopens all collected evidence")
	g.resume_game()
	var saved: Vector3 = g.checkpoint
	g.return_to_checkpoint()
	check(g.collected==4 and not puzzles.solved.has(false) and journal.collected.has("original") and g.player.position==saved,"checkpoint preserves four puzzles, keys and evidence")
	await use_point(Vector3(-26.42,1.4,0),Vector3(-24.8,0,0))
	check(g.exit_open,"four keys unlock entrance")
	g.interact()
	check(g.mode=="ending" and is_instance_valid(g.ending),"escape triggers dedicated ending")
	if not is_instance_valid(g.ending):
		g.get_tree().quit(1)
		return
	var ending: Control = g.ending
	g.victory()
	check(g.ending==ending,"ending triggers exactly once")
	await g.get_tree().create_timer(.2).timeout
	ending.advance()
	check(ending.page==0 and ending.reveal.complete,"first input completes page without advancing")
	ending.advance()
	check(ending.page==1,"separate input advances page")
	ending.instant = true
	check(ending.page_complete() and ending.page==1,"instant text display completes current page without advancing")
	ending.instant = false
	ending.advance()
	ending.advance()
	check(ending.page==2,"continuous story reaches final screen without headings")
	ending.advance()
	check(ending.stage=="story","final reveal does not skip silence or start credits")
	await g.get_tree().create_timer(1.3).timeout
	ending.advance()
	await g.get_tree().create_timer(1).timeout
	check(ending.stage=="credits" and g.mode=="credits","final continue fades into credits")
	var y_before: float = ending.credits_y
	await g.get_tree().create_timer(.3).timeout
	check(ending.credits_y<y_before,"credits scroll upward")
	var normal_distance: float = y_before-ending.credits_y
	var fast_start: float = ending.credits_y
	var accelerate := InputEventKey.new()
	accelerate.physical_keycode = KEY_SPACE
	accelerate.pressed = true
	Input.parse_input_event(accelerate)
	await g.get_tree().create_timer(.3).timeout
	accelerate.pressed = false
	Input.parse_input_event(accelerate)
	check(ending.stage=="credits" and fast_start-ending.credits_y>normal_distance*3,"holding Space accelerates credits without activating skip")
	var count_medissl := 0
	var attribution := false
	for label in ending.credits.get_children():
		if label is Label:
			if label.text=="medissl": count_medissl += 1
			if label.text.contains("AuraVoice"): attribution = true
	check(count_medissl==17 and attribution,"credits preserve all original categories and separate third-party attribution")
	ending.finish()
	await g.get_tree().create_timer(1).timeout
	check(g.mode=="menu" and g.ending==null and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"credits skip fades back to menu and pointer")
	g.start_game()
	g.collected = 4
	g.victory()
	var natural: Control = g.ending
	natural.start_credits()
	await g.get_tree().create_timer(1).timeout
	natural.credits_y = -natural.credits.size.y-100
	await g.get_tree().create_timer(1).timeout
	check(g.mode=="menu" and g.ending==null,"natural end of credits returns to menu")
	g.start_game()
	g.grace = 999
	check(g.collected==0 and g.keys.size()==4 and journal.collected.is_empty() and not puzzles.solved.has(true) and not puzzles.opened and not g.ending_started,"replay resets four keys, evidence, shelf, puzzles and ending")
	var door: Dictionary = g.doors[0]
	await use_point(door.origin+Vector3(0,1.3,0),door.origin+Vector3(0,0,2.1))
	await g.get_tree().create_timer(.65).timeout
	check(door.open,"closed sliding door opens through interaction")
	await use_point(door.origin+Vector3(1.34,1.3,-signf(door.origin.z)*.18),door.origin+Vector3(1.1,0,2.1))
	await g.get_tree().create_timer(.65).timeout
	check(not door.open,"open frame catch closes door")
	# Physics-driven movement, grounded footsteps, wall obstruction, stamina hysteresis.
	await aim(Vector3(-10,0,-5),Vector3(0,1.58,-5))
	g.player.rotation.y = -PI/2
	g.player.camera.rotation = Vector3.ZERO
	var before: Vector3 = g.player.position
	Input.action_press("forward")
	Input.action_press("sprint")
	await g.get_tree().create_timer(.6).timeout
	Input.action_release("sprint")
	Input.action_release("forward")
	check(g.player.position.distance_to(before)>2.3 and g.player.stamina<95 and g.player.footstep_count>0,"actual sprint drains stamina and produces footsteps")
	g.player.stamina = .2
	g.player.update_stamina(.1,true)
	check(g.player.exhausted,"depletion forces exhaustion")
	g.player.update_stamina(.2,false)
	check(g.player.exhausted,"recovery threshold prevents sprint toggling")
	g.player.update_stamina(3,false)
	check(not g.player.exhausted and g.player.stamina>28,"stamina restores and clears exhaustion")
	await aim(Vector3(-26.5,0,-5),Vector3(-30,1.58,-5))
	g.player.rotation.y = PI/2
	g.player.camera.rotation = Vector3.ZERO
	Input.action_press("forward")
	await g.get_tree().create_timer(.4).timeout
	var steps: int = g.player.footstep_count
	await g.get_tree().create_timer(.7).timeout
	Input.action_release("forward")
	check(g.player.footstep_count==steps,"no footsteps while pushing into wall")
	# Flashlight attracts attention from outside the normal enemy FOV, but not through walls.
	g.enemy.position = Vector3(14,1.5,-5)
	g.enemy.rotation.y = -PI/2
	await aim(Vector3(0,0,-5),g.enemy.position)
	g.player.lamp.visible = false
	check(not g.sees_player(),"unlit player outside FOV unseen")
	g.player.lamp.visible = true
	check(g.flashlight_exposure() and g.sees_player(),"aimed flashlight raises detection outside FOV")
	g.enemy.position = Vector3(0,1.5,5)
	g.player.camera.look_at(g.enemy.position)
	await g.get_tree().physics_frame
	check(not g.flashlight_exposure() and not g.sees_player(),"walls block flashlight detection")
	g.progression.scream_cooldown = 0
	g.progression.spotted()
	var cooldown: float = g.progression.scream_cooldown
	g.progression.spotted()
	check(g.progression.scream_cooldown==cooldown and cooldown>0,"spot scream has cooldown")
	g.ai_state = "chase"
	g.state_time = 2
	g.last_seen = Vector3(10,1.5,-5)
	g.grace = 0
	g._physics_process(.016)
	check(g.ai_state=="investigate","lost sight investigates last seen position")
	g.path.clear()
	g._physics_process(.016)
	check(g.ai_state=="search","investigation becomes search")
	g.state_time = 5
	g._physics_process(.016)
	check(g.ai_state=="roam","search returns to roaming")
	g.start_game()
	g.grace = 999
	g.enemy.position = Vector3(35.5,1.5,-5)
	g.ai_state = "investigate"
	g.navigate(Vector3(35.5,1.5,-11))
	Engine.time_scale = 4
	await g.get_tree().create_timer(6).timeout
	Engine.time_scale = 1
	check(g.enemy.position.z < -8.2,"enemy opens and crosses east-wing door")
	g.show_pause()
	check(g.mode=="paused","pause")
	g.resume_game()
	check(g.mode=="playing","resume")
	var old: bool = g.settings.reduced
	g.settings.reduced = not old
	g.save_settings()
	g.load_settings()
	check(g.settings.reduced!=old,"reduced-effects preference persists")
	g.settings.reduced = old
	g.save_settings()
	var previous_volume: float = g.settings.sfx
	g.settings.sfx = .33
	g.save_settings()
	g.load_settings()
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")),linear_to_db(.33)),"volume control reaches SFX bus")
	g.settings.sfx = previous_volume
	g.save_settings()
	g.capture()
	g.capture()
	check(g.mode=="capture","capture only triggers once")
	await g.get_tree().create_timer(1.9).timeout
	check(g.mode=="dead","timed jumpscare reaches death")
	g.show_main_menu()
	check(g.mode=="menu" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"menu return restores pointer")
	print("VERIFY COMPLETE: ",count," checks; failures: ",failed)
	if failed: g.get_tree().quit(1)
	elif "--quit-after-verify" in OS.get_cmdline_user_args(): g.quit_game()
