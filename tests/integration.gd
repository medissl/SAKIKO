extends RefCounted
var g: Node
var count:=0
var failed:=false
var finished:=false

func check(ok: bool,label: String) -> void:
	count+=1
	if not ok: failed=true; push_error("CHECK FAILED: "+label)
	print("CHECK ","PASS " if ok else "FAIL ",label)

func aim(from: Vector3,to: Vector3) -> void:
	g.player.position=from
	g.player.velocity=Vector3.ZERO
	await g.get_tree().physics_frame
	await g.get_tree().physics_frame
	g.player.camera.look_at(to)
	await g.get_tree().physics_frame

func use(point: Vector3,from: Vector3) -> void:
	await aim(from,point)
	if g.interactable().is_empty():
		var q:=PhysicsRayQueryParameters3D.create(g.player.camera.global_position,point,1)
		q.exclude=[g.player.get_rid()]
		var hit: Dictionary=g.get_world_3d().direct_space_state.intersect_ray(q)
		print("AIM MISS eye=",g.player.camera.global_position," point=",point," hit=",hit.get("position",Vector3.INF))
	g.interact()

func target(kind: String,id: String="") -> Dictionary:
	for item in g.progression.story_puzzles.available_targets():
		if item.type==kind and (id.is_empty() or item.get("id","")==id): return item
	return {}

func container(id: String,from: Vector3) -> void:
	var item:=target("container",id)
	check(not item.is_empty(),"physical mechanism "+id+" available")
	if item.is_empty(): return
	await use(item.point,from)
	await g.get_tree().create_timer(.8).timeout

func key(index: int,from: Vector3) -> void:
	await use(g.keys[index].global_position,from)
	check(g.keys[index].get_meta("collected",false),"entrance key "+str(index+1)+" physically collected")
	var before: int=g.collected
	g.interact()
	check(g.collected==before,"duplicate entrance pickup prevented "+str(index+1))
	if g.mode=="document": g.progression.evidence.close()

func document(id: String,from: Vector3) -> void:
	await use(g.progression.story_puzzles.evidence_models[id].global_position,from)
	check(g.mode=="document" and g.progression.evidence.collected.has(id),"physical document "+id+" inspectable")
	if g.mode=="document": g.progression.evidence.close()

func run(game: Node) -> void:
	g=game
	g.get_tree().create_timer(120,true,false,true).timeout.connect(func():
		if not finished: push_error("Verification watchdog expired"); g.get_tree().quit(1))
	g.start_game()
	g.grace=999
	var p: Node=g.progression.story_puzzles
	var journal: Node=g.progression.evidence
	var walker=preload("res://tests/layout_shell.gd").new()
	walker.game=g
	if "--bag-only" in OS.get_cmdline_user_args():
		await container("bag",Vector3(45.6,4.2,33.3))
		await key(3,Vector3(45.4,4.2,33.4))
		finished=true
		print("BAG VERIFY COMPLETE: ",count," checks; failures: ",failed)
		if failed: g.get_tree().quit(1)
		else: g.quit_game()
		return
	if "--final-focus" in OS.get_cmdline_user_args():
		await verify_final_changes()
		finished=true
		print("FOCUSED VERIFY COMPLETE: ",count," checks; failures: ",failed)
		if failed: g.get_tree().quit(1)
		else: g.quit_game()
		return
	if "--stairs-only" in OS.get_cmdline_user_args():
		await verify_stair_routes()
		finished=true
		print("STAIR VERIFY COMPLETE: ",count," checks; failures: ",failed)
		if failed: g.get_tree().quit(1)
		else: g.quit_game()
		return
	check(g.doors.size()==26 and g.layout.rooms.size()==17,"final map has 17 rooms and 26 actual room doors across two floors")
	check(g.keys.size()==4 and g.entrance_locks.size()==4,"four physical keys and matching exit locks")
	check(g.layout.seats.size()==12 and g.expansion.figures.get_child_count()==12,"measured classroom layout has twelve seats and eleven classmates")
	check(not p.solved.has(true) and not g.enemy.visible,"new night starts with concealed keys and no early monster")
	for i in range(4): check(g.keys[i].get_parent()==p.containers[p.KEY_CONTAINERS[i]].tray,"key preexists inside container "+str(i))
	# Both skip and normal playback use the same mandatory sleep/bell/waking path.
	g.play_intro()
	await g.get_tree().process_frame
	check(not g.hud.visible and not g.prompt.visible and not g.progression.stamina_bar.visible and g.interactable().is_empty(),"intro disables gameplay UI and targets")
	var skip:=InputEventAction.new()
	skip.action="interact"
	skip.pressed=true
	g.progression._unhandled_input(skip)
	g.progression._unhandled_input(skip)
	check(g.mode=="intro" and g.progression.intro_time==125,"skip enters shared sleep transition and repeated input cannot skip waking")
	Engine.time_scale=6
	await g.get_tree().create_timer(6).timeout
	check(g.mode=="intro" and g.progression.intro_dark and g.progression.intro_chime,"mandatory blackout plays the school bell")
	var transition_time: float=g.progression.intro_time
	g.progression._unhandled_input(skip)
	check(g.mode=="intro" and g.progression.intro_time<transition_time+.5,"late skip input cannot bypass transition")
	await g.get_tree().create_timer(15).timeout
	Engine.time_scale=1
	var skipped: Vector3=g.player.position
	check(g.mode=="playing" and not g.expansion.figures.visible and skipped.distance_to(g.layout.NIGHT)<.2,"skip reaches valid nighttime classroom after waking")
	g.play_intro()
	Engine.time_scale=12
	await g.get_tree().create_timer(146).timeout
	Engine.time_scale=1
	check(g.mode=="playing" and g.player.position.distance_to(skipped)<.2 and not g.enemy.visible,"full lesson naturally reaches identical night state")
	g.start_game()
	g.grace=999
	await use(g.layout.EXIT_TARGET,Vector3(1.4,0,12))
	check(g.progression.discovered and g.progression.objective().contains("0/4"),"entrance establishes objective without granting anything")
	check(not g.progression.hunt_enabled,"exit discovery alone does not start hunting")
	await document("handover",Vector3(26.2,0,7.0))
	await container("staff_cabinet",Vector3(30,0,1.9))
	check(not p.containers.staff_cabinet.open,"cabinet physically requires service key")
	await container("service_drawer",Vector3(26.2,0,7.3))
	await use(p.service_key.global_position,Vector3(26.2,0,7.1))
	check(p.service_taken and g.collected==0,"desk service key is utility inventory, not entrance count")
	await container("staff_cabinet",Vector3(30,0,1.9))
	await key(0,Vector3(29.85,0,1.75))
	await document("envelope",Vector3(29.85,0,1.75))
	await document("sketch",Vector3(29.6,0,33.5))
	check(journal.entries.sketch.body.contains("F-12"),"art ID is reviewable F-12")
	await document("display",Vector3(32,4.2,34.5))
	await document("exhibit",Vector3(33.1,4.2,34.5))
	check(journal.entries.exhibit.body.contains("B3-12"),"exhibit supplies exact archive compartment reference")
	# This drawer has no clue-read gate or unrelated lock.
	await container("archive_12",Vector3(14.3,4.2,33.75))
	await key(1,Vector3(13.8,4.2,33.95))
	await document("loan",Vector3(14.65,4.2,34.0))
	await use(target("recording").point,Vector3(41.65,4.2,2.7))
	check(not p.played,"unpowered playback device stays off")
	await use(target("av_power").point,Vector3(41.5,4.2,3))
	check(p.power,"local broadcast breaker powers playback")
	await use(target("recording").point,Vector3(41.65,4.2,2.7))
	check(p.played and journal.collected.has("recording"),"recording plays and stores readable transcript")
	if g.mode=="document": journal.close()
	await document("program",Vector3(42.55,4.2,2.5))
	check(journal.entries.recording.body.contains("Month first") and journal.entries.program.body.contains("15 OCTOBER"),"spoken clue and dated program agree on month/day code")
	await container("av_case",Vector3(46.2,0,2.8))
	check(g.mode=="puzzle" and not p.submit_combination("323"),"four-digit manual lock rejects old/incorrect combination")
	check(p.submit_combination("1015"),"festival date combination accepted")
	await g.get_tree().create_timer(.8).timeout
	await key(2,Vector3(46,0,2.3))
	var before_utility: int=g.collected
	await use(p.rehearsal_key.global_position,Vector3(46.5,0,2.4))
	check(p.rehearsal_taken and p.utility_inventory.has("rehearsal_U08") and g.collected==before_utility,"rehearsal access key stays separate from exit counter")
	await use(target("shelf").point,Vector3(44.5,0,31.7))
	check(p.brake and not p.opened,"visible shelving brake releases first")
	g.interact()
	await g.get_tree().create_timer(1.4).timeout
	check(p.opened and p.shelf.position.x<43,"shelf moves along visible short track")
	await document("maintenance",Vector3(46.3,0,34.5))
	check(journal.entries.maintenance.body.contains("U08") and journal.entries.maintenance.body.contains("18:10"),"report identifies rehearsal and retains unresolved inside knocking")
	var door: Dictionary=g.layout.rehearsal_door
	await use(door.origin+Vector3(0,1.3,-.14),Vector3(45,4.2,26.7))
	await g.get_tree().create_timer(.8).timeout
	check(door.open and not door.locked,"ordinary access key opens U08")
	await container("bag",Vector3(45.6,4.2,33.3))
	await key(3,Vector3(45.4,4.2,33.4))
	await document("letter",Vector3(45.8,4.2,33.5))
	check(g.collected==4,"all four entrance keys collected through final-map physical routes")
	journal.show_journal()
	check(g.mode=="document" and journal.journal_open,"journal reopens collected evidence safely")
	journal.reopen("handover")
	journal.reverse=true
	journal.update_preview()
	check(journal.entries.handover.get("reverse","")=="","blank document back stays blank")
	journal.close()
	# Furnished room entries: walk through actual door collision after opening.
	Engine.time_scale=3
	for id in g.layout.room_doors:
		var d: Dictionary=g.layout.room_doors[id][0]
		g.toggle_door(d,true)
		await g.get_tree().create_timer(.8).timeout
		var north: bool=d.origin.z==8
		g.player.position=d.origin+Vector3(0,.02,1.3 if north else -1.3)
		g.player.velocity=Vector3.ZERO
		await g.get_tree().physics_frame
		check(await walker.walk_to(d.origin+Vector3(0,0,-1.5 if north else 1.5)),id+" entrance remains traversable with furniture")
	Engine.time_scale=1
	await verify_stair_routes()
	g.mode="paused"
	await aim(Vector3(28,0,10),Vector3(28.3,5.7,10))
	g.enemy.position=Vector3(28.3,5.7,10)
	g.enemy.rotation.y=PI/2
	g.player.lamp.show()
	check(not g.sees_player() and not g.flashlight_exposure(),"slabs block between-floor enemy and flashlight detection")
	g.mode="playing"
	await aim(Vector3(4,0,12),Vector3(4,1.4,12.7))
	g.enemy.position=Vector3(4,1.4,12.7)
	g.grace=0
	g.ai_state="search"
	g.path.clear()
	g._physics_process(.016)
	check(g.mode=="capture","active enemy contact starts existing capture sequence")
	await g.get_tree().create_timer(1.25).timeout
	check(g.pain_triggered and g.curtain.modulate.a==1,"capture cuts to black before male pain")
	await g.get_tree().create_timer(.7).timeout
	check(g.mode=="dead","capture reaches red death screen")
	var saved: Vector3=g.checkpoint
	g.return_to_checkpoint()
	check(g.collected==4 and p.rehearsal_taken and p.opened and not p.solved.has(false) and g.player.position==saved,"retry preserves keys, utility inventory, shelf and validated floor checkpoint")
	g.grace=999
	await use(g.layout.EXIT_TARGET,Vector3(1.4,0,12))
	await g.get_tree().create_timer(.8).timeout
	check(g.exit_open and g.mode=="playing","four matching keys open actual exterior exit")
	g.player.rotation.y=PI/2
	g.player.camera.rotation=Vector3.ZERO
	Input.action_press("forward")
	await g.get_tree().create_timer(1.1).timeout
	Input.action_release("forward")
	check(g.mode=="ending" and is_instance_valid(g.ending),"physically leaving the school triggers established ending")
	if not is_instance_valid(g.ending): finished=true; g.get_tree().quit(1); return
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
	check(g.collected==0 and g.keys.size()==4 and p.utility_inventory.is_empty() and not p.opened and g.layout.rehearsal_door.locked and journal.collected.is_empty(),"restart resets final map puzzle and access states")
	finished=true
	print("VERIFY COMPLETE: ",count," checks; failures: ",failed)
	if failed: g.get_tree().quit(1)
	else: g.quit_game()

func verify_stair_routes() -> void:
	g.player.position=Vector3(4,0,12)
	g.progression.hunt_enabled=true
	g.grace=999
	g.enemy.position=Vector3(10,1.5,19)
	g.enemy.show()
	g.ai_state="investigate"
	g.state_time=0
	g.navigate(Vector3(10,5.7,19))
	Engine.time_scale=4
	await g.get_tree().create_timer(22).timeout
	Engine.time_scale=1
	check(g.enemy.position.y>5.3,"Sakiko physically navigates west stairs to upper floor")
	g.enemy.position=Vector3(46,5.7,19)
	g.ai_state="investigate"
	g.state_time=0
	g.navigate(Vector3(46,1.5,19))
	var uses_east:=false
	for point in g.path:
		if point.x>48: uses_east=true
	check(uses_east,"east stair route connects directly to both corridor floors")
	Engine.time_scale=4
	await g.get_tree().create_timer(22).timeout
	Engine.time_scale=1
	if g.enemy.position.y>=2: print("EAST STAIR enemy=",g.enemy.position," state=",g.ai_state," next=",g.path.slice(0,mini(4,g.path.size())))
	check(g.enemy.position.y<2,"Sakiko physically navigates east stairs down")

func verify_final_changes() -> void:
	var p: Node=g.progression.story_puzzles
	var journal: Node=g.progression.evidence
	g.mode="inspection"
	await g.get_tree().physics_frame
	for level in range(2):
		for edge in [[Vector3(46,1.3,10),Vector3(50,1.3,10)], [Vector3(46,1.3,26),Vector3(50,1.3,26)], [Vector3(10,1.3,26),Vector3(6,1.3,26)]]:
			var offset:=Vector3(0,level*4.2,0)
			var query:=PhysicsRayQueryParameters3D.create(edge[0]+offset,edge[1]+offset,1)
			query.exclude=[g.player.get_rid(),g.enemy.get_rid()]
			check(not g.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"outer corridor corner has solid perimeter on floor "+str(level))
	g.mode="playing"
	g.progression.discovered=true
	p.containers.staff_cabinet.open=true
	g.player.position=g.layout.NIGHT
	await g.get_tree().process_frame
	check(not g.enemy.visible and not g.progression.hunt_enabled,"exit and cabinet do not start hunting before first story discovery")
	g.player.position=Vector3(32,4.2,33)
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	check(g.progression.first_discovery and g.enemy.visible and not g.progression.hunt_enabled,"exhibition introduces concealed distant encounter before active hunting")
	g.start_game()
	g.grace=999
	await container("service_drawer",Vector3(26.2,0,7.3))
	await use(p.service_key.global_position,Vector3(26.2,0,7.1))
	check(p.service_taken,"staff chair placement retains reachable service key")
	await container("staff_cabinet",Vector3(30,0,1.9))
	await key(0,Vector3(29.85,0,1.75))
	await container("archive_12",Vector3(14.3,4.2,33.75))
	await key(1,Vector3(13.8,4.2,33.95))
	check(not journal.collected.has("sketch") and not journal.collected.has("exhibit"),"archive opens early without reading flags")
	await container("av_case",Vector3(46.2,0,2.8))
	check(p.submit_combination("1015") and not p.played,"known code opens equipment case without prior playback or reading")
	await g.get_tree().create_timer(.8).timeout
	await use(p.rehearsal_key.global_position,Vector3(46.5,0,2.4))
	check(p.rehearsal_taken,"physical case utility key reachable")
	var door: Dictionary=g.layout.rehearsal_door
	await use(door.origin+Vector3(0,1.3,-.14),Vector3(45,4.2,26.7))
	await g.get_tree().create_timer(.8).timeout
	check(door.open and not p.opened and not journal.collected.has("maintenance"),"U08 access works before shelf movement or report reading")
	await container("bag",Vector3(45.6,4.2,33.3))
	await key(3,Vector3(45.4,4.2,33.4))
