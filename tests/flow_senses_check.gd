extends "res://tests/flow_check.gd"
func run(game: Node) -> void:
	g=game
	g.start_game()
	flow=g.progression.story_puzzles
	flow.stage=6
	flow.flags.chase_started=true
	flow.flags.escape_done=true
	flow.apply_state()
	await g.get_tree().create_timer(.2).timeout
	g.player.position=Vector3(24,0,26)
	g.enemy.position=Vector3(34,1.5,26)
	g.enemy.show()
	g.enemy.look_at(g.player.position+Vector3(0,1.3,0))
	g.ai_state="roam"
	g.path.clear()
	g.grace=0
	g.visual_notice=0
	g.progression.encounters_controller.pressure_cooldown=55
	check(g.sees_player(),"medium-range fixture has real unobstructed vision")
	await g.get_tree().create_timer(.4).timeout
	check(g.ai_state!="chase" and g.visual_notice>.2,"roaming vision accumulates instead of instantly pursuing")
	await g.get_tree().create_timer(.75).timeout
	check(g.ai_state=="chase","sustained real sight starts pursuit during director cooldown")
	g.mode="senses_fixture"
	g.enemy.position=Vector3(27.2,1.5,26)
	g.ai_state="roam"
	g.footstep(false)
	check(g.ai_state=="roam","ordinary walking is not heard from over three metres")
	g.footstep(true)
	check(g.ai_state=="investigate","local running produces investigation even during director cooldown")
	g.enemy.position=Vector3(25.7,1.5,26)
	g.ai_state="roam"
	g.footstep(false)
	check(g.ai_state=="investigate","nearby walking remains a local audible stimulus")
	g.enemy.position=Vector3(25.7,5.7,26)
	g.ai_state="roam"
	g.footstep(true)
	check(g.ai_state=="roam","ordinary footstep does not report exact position to another floor")
	print("SENSES RESULT failures=",failures)
	finish()
