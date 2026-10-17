extends "res://tests/flow_check.gd"
func run(game: Node) -> void:
	g=game
	g.start_game()
	flow=g.progression.story_puzzles
	var saved:=FileAccess.open("res://tests/artifacts/flow-cp3.save",FileAccess.READ)
	g.checkpoint_state=saved.get_var()
	g.return_to_checkpoint()
	check(g.checkpoint_id=="CP4" and flow.flags.get("tape_done",false),"fixture restores organically reached safe AV checkpoint")
	# Replay fixture to exercise reading controls independently of the long route.
	flow.stage=4
	flow.flags.tape_done=false
	flow.apply_state()
	AudioServer.set_bus_mute(0,true)
	flow.play_tape()
	await g.get_tree().create_timer(.2).timeout
	flow.close_tape()
	check(g.mode=="playing" and flow.stage==4 and not flow.flags.tape_done,"early close keeps tape incomplete and replayable")
	flow.play_tape()
	flow.step_transcript(1)
	flow.step_transcript(-1)
	check(flow.captions.text.contains("front-door key"),"manual review works without audio")
	for block in range(4): flow.step_transcript(1)
	check(g.mode=="playback_review" and g.checkpoint_id=="CP4" and not g.progression.hunt_enabled,"manual completion leaves safe review and saves completed playback")
	flow.close_tape()
	check(not flow.recording.playing,"closing review stops remaining tape audio")
	g.progression.hunt_enabled=true
	g.ai_state="chase"
	g.progression.evidence.inspect("letter")
	check(g.mode=="playing" and not g.progression.evidence.collected.has("letter"),"active chase cannot be erased by inspecting final letter")
	g.progression.evidence.show_journal()
	check(g.mode=="playing","active chase cannot be erased with journal")
	g.return_to_checkpoint()
	check(not flow.recording.playing and g.player.stamina==100 and not g.progression.encounters_controller.chase_started,"CP4 resets playback and re-arms first pursuit")
	print("MODAL RESULT failures=",failures)
	finish()
