extends "res://tests/bugfix_audio_lighting.gd"
func run(game: Node) -> void:
	g=game
	g.input_focused=true
	g.show_main_menu();await wait(.1)
	for item in g.nav_buttons:
		item.mouse_entered.emit();await wait(.03)
		check(g.menu_indicator.get_parent()==item and g.menu_indicator.position.x<0 and g.menu_indicator.size.y>g.menu_indicator.size.x,"left vertical marker follows "+item.text)
	g.nav_buttons[1].pressed.emit();await wait(.05);g.options_back();await wait(.05)
	check(g.menu_selection.text=="OPTIONS" and g.menu_selection.has_focus(),"submenu restores selection and focus")
	g.start_game();await wait(.2)
	g.player_voice.request("P01");await wait(.1)
	check(not g.player_voice.pending.is_empty() and not g.player_voice.speaker.playing,"practical player thought queued without VA")
	g.expansion.set_day(true);await wait(.1)
	check(not g.expansion.lesson_audio[0].playing and g.expansion.lesson_audio[1].stream.resource_path.ends_with("classroom_murmur.wav") and not g.expansion.lesson_caption(3).is_empty(),"no teacher speech; natural filtered murmur and lesson text retained")
	g.expansion.set_day(false)
	check(g.layout.placement.rejected.is_empty(),"active room placement contract has no rejected assemblies")
	check(g.exit_panels[0].mesh!=null and g.hardware.locks[0].strap.mesh!=null,"movable entrance panels and lock straps retain their geometry")
	await aim(Vector3(14,0,10),Vector3(42,1.58,10))
	Input.action_press("forward");Input.action_press("sprint")
	await wait(6.5)
	check(g.player.exhausted and g.player.stamina<2 and g.player.pant.playing and g.player.footstep_count>5,"held sprint reaches exhaustion with nonstacked pant and grounded footsteps")
	Input.action_release("forward");Input.action_release("sprint")
	g.show_pause();await wait(.1)
	check(not g.player.pant.playing and g.player_steps.is_empty(),"pause cancels pant and footstep tails")
	g.resume_game()
	var p: Node=g.progression.story_puzzles
	check(p.recording.stream.resource_path.ends_with("festival_nonverbal.wav") and absf(p.recording.stream.get_length()-24)<.01,"tape uses bounded nonverbal transport/hiss/knocks")
	check(g.audio_production.tape_captions.size()==6 and g.progression.evidence.entries.recording.body.contains("Month"),"timed transcript and permanent combination clue retained")
	await integrated_segment()
	finish_suite()
