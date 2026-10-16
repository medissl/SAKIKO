extends RefCounted
var g: Node
var failures := 0
var samples: Array = []
var capture: AudioEffectCapture
func check(ok: bool, description: String) -> void:
	print("POLISH PASS " if ok else "POLISH FAIL ",description)
	if not ok: failures += 1

func wait(seconds: float) -> void:
	await g.get_tree().create_timer(seconds).timeout

func capture_level(label: String, action: Callable, seconds: float) -> Dictionary:
	capture.clear_buffer()
	action.call()
	await wait(seconds)
	var frames := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	var square := 0.0
	for frame in frames:
		peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
		square+=frame.length_squared()*.5
	var level := {"clip":label,"frames":frames.size(),"peak_db":linear_to_db(maxf(peak,.000001)),"rms_db":linear_to_db(maxf(sqrt(square/maxi(1,frames.size())),.000001))}
	samples.append(level)
	print("POLISH MIX ",JSON.stringify(level))
	return level

func run(game: Node) -> void:
	g=game
	g.input_focused=true
	g.start_game()
	g.player_voice.flush()
	g.mode="inspection"
	await wait(.2)
	var evidence: Node=g.progression.evidence
	check(evidence.entries.letter.reverse.is_empty() and evidence.entries.notice.reverse.is_empty(),"unwritten paper backs contain no descriptive text")
	check(not evidence.entries.account.reverse.contains("blank") and not evidence.entries.maintenance.body.contains("underlined twice"),"document text no longer explains blankness or its own markings")
	check(evidence.entries.maintenance.body.contains("[u]inside[/u]"),"essential double-underlined clue retained")
	g.mode="playing"
	evidence.inspect("letter")
	var first_container: Control=evidence.preview_view.get_parent()
	check(first_container.modulate.a==0,"new preview starts transparent while its render target initializes")
	await wait(.6)
	check(first_container.modulate.a>.99 and evidence.preview_view.render_target_update_mode in [SubViewport.UPDATE_ONCE,SubViewport.UPDATE_DISABLED],"inspection presents a completed image in one-shot rendering mode")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png("C:/Users/media/OneDrive/Documents/sakiko/tests/artifacts/polish_paper_front.png")
	evidence.reverse=true
	evidence.update_preview()
	check(evidence.preview_view.render_target_update_mode==SubViewport.UPDATE_ONCE,"flipping requests one fresh preview frame")
	await wait(.15)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png("C:/Users/media/OneDrive/Documents/sakiko/tests/artifacts/polish_paper_blank_back.png")
	evidence.close()
	# Rapid reopen / close cannot let an old asynchronous preview reappear.
	evidence.inspect("program");evidence.show_journal();evidence.reopen("maintenance");evidence.close()
	await wait(.2)
	check(g.mode=="playing" and not g.menu.visible,"rapid inspection changes leave no stale overlay")
	var door: Dictionary=g.layout.rehearsal_door
	door.locked=true
	g.progression.story_puzzles.utility_inventory.erase(door.requirement)
	g.toggle_door(door)
	check(g.audio_trace.back().clip=="locked" and not door.open and g.sounds.locked.resource_path.ends_with("locked_rattle.wav"),"locked door rattles without opening")
	# Sample the actual output bus at all controls = 100%, with identical listener placement.
	if DisplayServer.get_name()!="headless":
		g.mode="inspection"
		g.set_process(false)
		g.player.set_physics_process(false)
		for key in ["master","ambience","sfx","voice"]: g.settings[key]=1.0
		g.apply_settings()
		for node in g.find_children("*","AudioStreamPlayer3D",true,false): node.stop()
		for node in g.find_children("*","AudioStreamPlayer",true,false): node.stop()
		await wait(.8)
		capture=AudioEffectCapture.new();capture.buffer_length=4
		AudioServer.add_bus_effect(0,capture)
		var point: Vector3=g.player.camera.global_position+(-g.player.camera.global_basis.z)*1.6
		var foot: Dictionary=await capture_level("wood walk",func(): g.footstep(false),.6)
		var door_level: Dictionary=await capture_level("sliding door",func(): g.world_sound("door_track",point,-12,.65),.85)
		var lock: Dictionary=await capture_level("locked rattle",func(): g.world_sound("locked",point,-19),.85)
		var paper: Dictionary=await capture_level("paper lift",func(): g.world_sound("paper_lift",point,-16),.65)
		await capture_level("paper menu focus",func(): g.sound("hover",-25),.3)
		await capture_level("mechanical menu confirm",func(): g.sound("press",-21),.3)
		await capture_level("dry capture impact",func(): g.sound("capture",-15),.5)
		var bed: Dictionary=await capture_level("room tone",func(): g.ambient.volume_db=0;g.ambient.play(),2)
		g.ambient.stop()
		check(foot.frames>0 and door_level.frames>0,"native audio output captured")
		check(door_level.peak_db>foot.peak_db and lock.peak_db>foot.peak_db,"door and blocked-handle cues rise above reduced footsteps")
		check(bed.rms_db>-42 and paper.peak_db>-30,"room tone and paper handling have audible output headroom")
		var unclipped:=true
		for sample in samples:
			if sample.peak_db>-.8: unclipped=false
		check(unclipped,"captured interaction mix remains below output ceiling")
		AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
		g.set_process(true)
		g.player.set_physics_process(true)
	# Stand-up finishes at the same pose as gameplay, including a gradual lamp ramp.
	g.play_intro()
	g.progression.intro_look=Vector2(.5,.2)
	g.progression.intro_time=144.95
	g.progression._process(.0)
	var before: Transform3D=g.player.camera.global_transform
	var lamp_before: float=g.player.lamp.light_energy
	g.progression.finish_intro()
	check(before.origin.distance_to(g.player.camera.global_position)<.01 and before.basis.z.distance_to(g.player.camera.global_basis.z)<.005,"stand-up and gameplay camera poses meet continuously")
	check(absf(lamp_before-g.player.lamp.light_energy)<.02,"flashlight ramps in before control handoff")
	check(g.progression.intro_stand and g.audio_trace.back().clip=="bag_fabric","stand-up adds one chair and clothing movement cue")
	check(g.expansion.lesson_audio[1].volume_db>-10 and g.expansion.lesson_audio[2].volume_db>-10,"daytime chatter and outdoor children raised")
	var ending_script=load("res://scripts/ending.gd")
	var epilogue: Control=ending_script.new()
	epilogue.game=g
	g.mode="ending"
	g.ending=epilogue
	g.gui.add_child(epilogue)
	var prose := ""
	for page in epilogue.pages: prose+=page.body+"\n\n"
	check(epilogue.pages.size()==3 and not prose.to_lower().contains("you ") and prose.contains("18:10") and prose.contains("08:40"),"third-person ending preserves the established timeline")
	check(prose.contains("library") and prose.contains("mother") and prose.contains("no record of opening the door again"),"ending keeps the human tragedy and unresolved second knocking")
	if DisplayServer.get_name()!="headless":
		for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
			g.get_window().size=size
			for index in range(3):
				epilogue.page=index;epilogue.instant=true;epilogue.show_page()
				await wait(.3)
				await RenderingServer.frame_post_draw
				check(g.get_viewport().get_visible_rect().encloses(epilogue.next.get_global_rect()),"ending controls fit "+str(size)+" page "+str(index+1))
				g.get_viewport().get_texture().get_image().save_png("C:/Users/media/OneDrive/Documents/sakiko/tests/artifacts/polish_ending_%d_%d.png" % [size.x,index+1])
		epilogue.finish()
		await wait(1.1)
		check(g.mode=="menu" and not is_instance_valid(g.studio_intro),"ending returns directly to menu without replaying developer splash")
	var report:=FileAccess.open("C:/Users/media/OneDrive/Documents/sakiko/tests/artifacts/playtest_polish.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures":failures,"audio_output":samples},"\t"));report.close()
	print("POLISH RESULT ",failures," failures")
	g.get_tree().quit(0 if failures==0 else 1)
