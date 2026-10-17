extends "res://tests/flow_check.gd"
var cp3: Dictionary
func restore_cp3() -> void:
	g.checkpoint_state=cp3.duplicate(true)
	g.return_to_checkpoint()
	await g.get_tree().physics_frame
func place(point: Vector3) -> void:
	g.player.position=point
	g.player.velocity=Vector3.ZERO
	await g.get_tree().physics_frame
func run(game: Node) -> void:
	g=game
	g.start_game()
	flow=g.progression.story_puzzles
	var saved:=FileAccess.open("res://tests/artifacts/flow-cp3.save",FileAccess.READ)
	cp3=saved.get_var()
	check(cp3.version==5 and cp3.id=="CP4","targeted scenarios start from normally reached CP4")
	await restore_cp3()
	check(not g.flashlight_exposure(),"flashlight attraction disabled; lighting cannot broadcast position")
	# An actual floor slab and room wall obstruct detection even at short range.
	await place(Vector3(39.65,0,5))
	g.enemy.position=Vector3(40.35,1.5,5)
	g.enemy.show()
	g.enemy.look_at(g.player.position+Vector3(0,1.4,0))
	g.progression.hunt_enabled=true
	g.grace=0
	g.ai_state="chase"
	g.last_seen=Vector3(39.65,1.5,5)
	check(not g.sees_player(),"partition blocks sight at contact distance")
	await g.get_tree().create_timer(.25).timeout
	check(g.mode=="playing","close radius cannot capture through room partition")
	await restore_cp3()
	await place(Vector3(45,0,10))
	g.enemy.position=Vector3(46,1.5,14)
	g.enemy.show()
	g.enemy.look_at(g.player.position+Vector3(0,1.4,0))
	g.progression.hunt_enabled=true
	g.grace=0
	g.ai_state="chase"
	await g.get_tree().create_timer(.15).timeout
	var seen: Vector3=g.last_seen
	await place(Vector3(42,0,5))
	await g.get_tree().create_timer(.25).timeout
	check(g.last_seen.distance_to(seen)<.01,"hidden player movement does not update last-seen coordinates")
	# Closed AV door: wait for its real operation, no snapping through it.
	await restore_cp3()
	await place(Vector3(15.5,0,2.7))
	var av: Dictionary=g.layout.room_doors.G05[0]
	if av.has("tween") and av.tween: av.tween.kill()
	av.open=false
	av.busy=false
	for i in range(2): av.panels[i].position.x=-.5 if i==0 else .5
	g.enemy.position=Vector3(45,1.5,9.5)
	g.enemy.show()
	g.enemy.velocity=Vector3.ZERO
	g.progression.hunt_enabled=true
	g.ai_state="investigate"
	g.state_time=0
	g.lost_sight=0
	g.navigate(Vector3(45,1.5,5))
	await g.get_tree().create_timer(.5).timeout
	check(av.busy and g.enemy.position.z>8,"enemy operates actual closed door before crossing")
	await g.get_tree().create_timer(1.6).timeout
	check(av.open and not av.busy and g.enemy.position.z<9.0,"door takes 1.2 seconds and then permits real travel")
	# First pursuit is escapable (route test) but not an immunity sequence.
	await restore_cp3()
	if not await walk_to(Vector3(45,0,10)): return finish()
	var encounter: RefCounted=g.progression.encounters_controller
	check(encounter.chase_started,"failure scenario crosses actual AV threshold")
	var elapsed:=0.0
	while g.mode=="playing" and elapsed<20:
		await g.get_tree().physics_frame
		elapsed+=g.get_physics_process_delta_time()
	var reaction: float=g.clock-encounter.pursuit_clock
	print("FAIRNESS CONTACT seconds=",reaction," mode=",g.mode," enemy=",g.enemy.position)
	check(g.mode=="capture" and reaction>=4,"standing in the chase route can fail after at least four seconds")
	await g.get_tree().create_timer(4.0).timeout
	check(g.mode=="dead","fairness failure completes capture")
	# Real interior bolt, outside knocking, and withdrawal.
	await restore_cp3()
	flow.flags.chase_started=true
	encounter.chase_started=true
	g.progression.hunt_enabled=true
	var staff: Dictionary=g.layout.room_doors.G03[0]
	if staff.has("tween") and staff.tween: staff.tween.kill()
	staff.open=false
	staff.busy=false
	for i in range(2): staff.panels[i].position.x=-.5 if i==0 else .5
	await place(Vector3(28.5,0,6.5))
	g.enemy.position=Vector3(31,1.5,10)
	g.enemy.show()
	g.enemy.velocity=Vector3.ZERO
	g.ai_state="search"
	g.state_time=0
	g.lost_sight=0
	if not await use(flow.bolt.global_position,"bolt"): return finish()
	check(flow.flags.get("bolted",false) and not flow.can_open(staff),"inside bolt physically excludes creature navigation")
	await g.get_tree().create_timer(9).timeout
	check(flow.bolt_knock and flow.flags.get("escape_done",false) and flow.stage==6,"staff refuge has actual outside knocks and finite withdrawal")
	var knocks:=false
	for event in g.audio_trace:
		if event.get("clip","")=="staff_knocks": knocks=true
	check(knocks,"staff knocks use separate material-contact sequence")
	# Reset a partially released entrance lock; no callback may unlock the next run.
	g.hardware.release(0)
	await g.get_tree().create_timer(.1).timeout
	g.hardware.reset()
	await g.get_tree().create_timer(.7).timeout
	check(g.hardware.released==[false] and not g.hardware.busy,"lock reset cancels old release tween")
	print("FAIRNESS RESULT failures=",failures)
	finish()
