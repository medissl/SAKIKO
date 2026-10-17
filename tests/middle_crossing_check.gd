extends "res://tests/flow_check.gd"
var saved: Dictionary
func restore_open() -> void:
	g.checkpoint_state=saved.duplicate(true)
	g.return_to_checkpoint()
	g.progression.encounters_controller.later_presence=true
	await g.get_tree().physics_frame
func enemy_to(point: Vector3) -> bool:
	g.ai_state="middle_approach"
	g.state_time=0
	g.lost_sight=0
	g.navigate(point)
	var elapsed:=0.0
	while g.enemy.position.distance_to(point)>.65 and elapsed<18:
		await g.get_tree().physics_frame
		elapsed+=g.get_physics_process_delta_time()
	var ok: bool=g.enemy.position.distance_to(point)<=.65
	check(ok,"physical creature clearance to "+str(point)+" reached "+str(g.enemy.position))
	return ok
func run(game: Node) -> void:
	g=game
	g.start_game()
	flow=g.progression.story_puzzles
	var file:=FileAccess.open("res://tests/artifacts/middle-open.save",FileAccess.READ)
	saved=file.get_var();file.close()
	Engine.time_scale=3
	await restore_open()
	check(flow.stage==7 and flow.flags.shutter_open,"crossing fixture uses legitimately completed hand task")
	g.player.position=Vector3(27,0,5.5)
	for room in ["U01","U02","U03"]:
		var doors: Array=g.layout.room_doors[room]
		for door in doors: g.toggle_door(door,true)
		await g.get_tree().create_timer(1.3).timeout
		g.enemy.position=Vector3(doors[0].origin.x,5.7,10)
		for point in [Vector3(doors[0].origin.x,5.7,6.9),Vector3(doors[1].origin.x,5.7,6.9),Vector3(doors[1].origin.x,5.7,10)]:
			if not await enemy_to(point): return finish()
	# Actual visual chase, real sprint and connected classroom exits. No damage switch.
	await restore_open()
	for room in ["U02","U03"]:
		for door in g.layout.room_doors[room]: g.toggle_door(door,true)
	await g.get_tree().create_timer(1.3).timeout
	# A previously opened far-side landing is a legitimate escape alternative.
	g.player.position=Vector3(46.8,4.2,19)
	if not await use(flow.landing_bolt.global_position,"landing_bolt"): return finish()
	await g.get_tree().create_timer(1.3).timeout
	g.player.position=Vector3(17.5,4.2,9.5)
	g.enemy.position=Vector3(12,5.7,10)
	g.enemy.look_at(g.player.position+Vector3(0,1.4,0))
	g.enemy.velocity=Vector3.ZERO
	g.path.clear()
	g.visual_notice=0
	g.ai_state="roam"
	g.grace=0
	var wait:=0.0
	while g.ai_state!="chase" and g.mode=="playing" and wait<2:
		await g.get_tree().physics_frame
		wait+=g.get_physics_process_delta_time()
	check(g.ai_state=="chase" and g.mode=="playing","crossing escape starts from genuine visual pursuit")
	aim(g.enemy.position)
	await capture_image("middle_genuine_pursuit")
	if not await walk_to(Vector3(18.4,4.2,6.7),true): return finish()
	var entry: Dictionary=g.layout.room_doors.U02[0]
	if not await use(entry.node.to_global(Vector3(entry.slide_direction*1.55,1.3,entry.track_side*.27)),"door"): return finish()
	check(not entry.open,"closing the entry door behind the player buys physical time")
	for point in [Vector3(22.5,4.2,6.9),Vector3(22.5,4.2,10),Vector3(46,4.2,10),Vector3(46.8,4.2,19),Vector3(49.2,0,17.8),Vector3(42.3,0,5)]:
		if not await walk_to(point,true): return finish()
	await g.get_tree().create_timer(12).timeout
	print("MIDDLE ESCAPE mode=",g.mode," state=",g.ai_state," player=",g.player.position," enemy=",g.enemy.position," last_seen=",g.last_seen)
	check(g.mode=="playing" and g.ai_state not in ["chase","investigate","search"],"genuine loss-of-sight escape through U02 and the east landing")
	await capture_image("middle_genuine_escape")
	# Open-corridor failure, retaining ordinary damage and movement.
	await restore_open()
	g.player.position=Vector3(30,4.2,10)
	g.enemy.position=Vector3(23,5.7,10)
	g.enemy.look_at(g.player.position+Vector3(0,1.4,0))
	g.enemy.velocity=Vector3.ZERO
	g.ai_state="roam"
	g.path.clear()
	g.grace=0
	g.visual_notice=0
	wait=0
	while g.mode=="playing" and wait<12:
		await g.get_tree().physics_frame
		wait+=g.get_physics_process_delta_time()
	print("MIDDLE CROSSING CONTACT seconds=",wait)
	check(g.mode=="capture","openly standing in her corridor path causes genuine capture")
	await g.get_tree().create_timer(1.8).timeout
	await capture_image("middle_genuine_capture")
	await g.get_tree().create_timer(2.3).timeout
	check(g.mode=="dead","crossing capture reaches normal retry UI")
	# Old saves preserve key ownership or move pre-key players to middle entry.
	var old: Dictionary=saved.duplicate(true)
	old.version=4;old.flow.stage=7;old.flow.flags.key=true;old.doors.pop_back()
	var migrated: Dictionary=g.migrate_middle_save(old)
	check(migrated.version==5 and migrated.flow.stage==8 and migrated.flow.flags.shutter_open and migrated.flow.flags.east_landing_unbolted,"v4 key owner migrates directly to final return")
	old.flow.stage=6;old.flow.flags.key=false;old.flow.flags.escape_done=true
	migrated=g.migrate_middle_save(old)
	check(migrated.id=="CP5" and migrated.position==g.SAFE_CHECKPOINTS.CP5 and not migrated.flow.flags.shutter_open,"v4 pre-key escape migrates to safe middle entry")
	print("MIDDLE CROSSING RESULT failures=",failures)
	finish()
