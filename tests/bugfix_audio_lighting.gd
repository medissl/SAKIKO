extends "res://tests/corrections_integration.gd"
## Focused defects, followed by one fixture-started tape/escape/capture segment.

func wait(seconds:=.15) -> void:
	await g.get_tree().create_timer(seconds).timeout

func shift(location: int,pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=KEY_SHIFT
	event.keycode=KEY_SHIFT
	event.location=location
	event.pressed=pressed
	Input.parse_input_event(event)
	await wait(.08)

func run(game: Node) -> void:
	g=game
	if "--bugfix-caption-only" in OS.get_cmdline_user_args():
		g.input_focused=true;g.start_game();await wait()
		g.player.position=Vector3(38,4.2,26.5);g.player.rotation.y=-PI/2
		var v: Node=g.player_voice
		v.wake_delay=-1;v.request("P07");await wait(.1)
		g.progression.encounters_controller.portrait_closed()
		check(v.has_event("P07") and not v.speaker.playing,"caption-only reveal line counts as active without rejected speech")
		v.clock=v.caption_until+.1;await wait(.05)
		check(not v.has_event("P07"),"caption expiry clears active event rather than blocking encounter forever")
		check(g.progression.encounters_controller.reveal_time>=0 and not g.progression.hunt_enabled,"portrait watching can stage after silent caption expires")
		v.last_comment=-100;v.request("P06");await wait(.05)
		g.progression.evidence.inspect("sketch");await wait(.05)
		check(v.caption_until==0 and v.pending.is_empty() and not v.subtitle_panel.visible,"inspection preempts caption-only queue")
		finish_suite();return
	if "--bugfix-motion-only" in OS.get_cmdline_user_args():
		g.input_focused=true;g.start_game();await wait()
		var door: Dictionary=g.layout.room_doors.G01[0]
		g.toggle_door(door);await wait(.08)
		check(door.motion_audio.playing,"slide audio starts with moving panel")
		var live: WeakRef=weakref(door.motion_audio)
		g.toggle_door(door);await wait(.03)
		check(live.get_ref()==door.motion_audio,"busy interaction does not duplicate slide sound")
		g.show_pause();await wait(.1)
		check(live.get_ref()==null and g.moving_sounds.is_empty(),"pause releases moving audio rather than leaving stopped orphan nodes")
		g.resume_game();await wait(.8)
		check(not door.busy and door.open,"paused sound cancellation preserves completed physical panel state")
		g.player.position=Vector3(28,0,10);g.player.rotation.y=-PI/2
		Input.action_press("forward");await wait(.2);g.show_pause();await wait(.1)
		check(g.player_steps.is_empty() and not g.player.is_running,"pause cancels footstep tails and sprint")
		Input.action_release("forward")
		finish_suite();return
	if "--bugfix-danger-only" in OS.get_cmdline_user_args():
		g.input_focused=true
		await integrated_segment()
		finish_suite()
		return
	g.show_main_menu()
	await wait()
	var items: Array=g.nav_buttons.duplicate()
	for item in items:
		item.mouse_entered.emit()
		await wait(.03)
		check(g.menu_selection==item and g.menu_indicator.get_parent()==item and item.has_focus(),"mouse indicator follows "+item.text)
		item.grab_focus()
		await wait(.02)
		check(g.menu_indicator.size.x>0 and g.menu_indicator.size.x<=item.size.x,"indicator uses laid-out text bounds "+item.text)
	items[0].grab_focus()
	for index in [1,2,3]:
		var key_event:=InputEventAction.new();key_event.action="ui_down";key_event.pressed=true
		Input.parse_input_event(key_event);await wait(.06)
		key_event=InputEventAction.new();key_event.action="ui_down";key_event.pressed=false;Input.parse_input_event(key_event)
		check(g.menu_selection==items[index],"keyboard moves same indicator to "+items[index].text)
	items[1].pressed.emit();await wait();g.options_back();await wait()
	check(g.menu_selection.text=="OPTIONS" and g.menu_selection.has_focus(),"Options return restores opener focus")
	g.nav_buttons[2].pressed.emit();await wait();g.show_main_menu();await wait()
	check(g.menu_selection.text=="CREATOR" and g.menu_selection.has_focus(),"Creator return restores opener focus")
	g.menu_selection.disabled=true;await wait()
	check(not g.menu_selection.disabled,"disabled button loses indicator")
	g.menu_selection.hide();await wait()
	check(g.menu_selection.is_visible_in_tree(),"hidden button loses indicator")
	g.menu_selection.get_parent().scale=Vector2(1.35,1.35);await wait()
	check(g.menu_indicator.get_parent()==g.menu_selection and g.menu_indicator.size.x<=g.menu_selection.size.x,"indicator remains in button-local bounds under UI scaling")
	g.input_focused=true;g.start_game();await wait()
	g.player_voice.wake_delay=-1
	g.player.position=Vector3(28,0,10);g.player.rotation.y=-PI/2
	Input.action_press("sprint");var stamina_before: float=g.player.stamina;await wait(.5)
	check(not g.player.is_running and g.player.stamina>=stamina_before,"stationary Shift does not sprint or drain stamina")
	Input.action_press("forward");await wait(.5)
	check(g.player.is_running and g.player.velocity.length()>3.5 and g.player.stamina<stamina_before,"held Shift with grounded movement sprints and drains")
	Input.action_release("sprint");await wait(.12)
	check(not g.player.is_running and Vector2(g.player.velocity.x,g.player.velocity.z).length()<2.4,"releasing Shift returns to walking")
	await shift(KEY_LOCATION_LEFT,true);await shift(KEY_LOCATION_RIGHT,true);await shift(KEY_LOCATION_LEFT,false)
	check(g.player.is_running,"right Shift remains active after left Shift release")
	await shift(KEY_LOCATION_RIGHT,false)
	check(not g.player.is_running,"both Shift releases cancel sprint")
	Input.action_press("sprint");await wait(.1)
	g.progression.evidence.inspect("sketch");await wait(.05)
	check(not g.player.is_running and g.player.velocity.x==0 and g.player_steps.is_empty(),"inspection immediately cancels locomotion and footsteps")
	Input.action_release("sprint");g.progression.evidence.close();await wait()
	check(not g.player.is_running,"inspection resume samples released Shift")
	Input.action_press("sprint");await wait(.1);g.show_pause();await wait(.03)
	check(not g.player.is_running,"pause immediately cancels sprint")
	Input.action_release("sprint");g.resume_game();await wait()
	check(not g.player.is_running,"pause resume does not latch old sprint")
	Input.action_press("sprint");await wait(.1)
	g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);await wait(.03)
	check(g.mode=="paused" and not g.player.is_running and not Input.is_action_pressed("sprint"),"focus loss clears held actions and cancels sprint")
	g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);g.resume_game();await wait()
	check(not g.player.is_running,"focus return does not resume stale sprint")
	Input.action_release("forward");g.player.position=Vector3(10,0,10);g.player.rotation.y=-PI/2;g.player.reset()
	Input.action_press("forward");Input.action_press("sprint");await wait(6.3)
	check(g.player.exhausted and not g.player.is_running and g.player.pant.playing,"held sprint exhausts and retains usable panting")
	await wait(3.1)
	check(g.player.is_running and not g.player.exhausted,"held Shift can resume only after recovery threshold")
	Input.action_release("sprint");Input.action_release("forward");await wait(.1)
	for shot in [[Vector3(2,-.13,12),"tile"],[Vector3(4.6,.5,19.6),"stair"],[Vector3(28,0,10),"wood"]]:
		g.player.position=shot[0];await wait(.08)
		check(g.contact_surface()==shot[1],"contact ray resolves actual "+shot[1]+" support")
	for d in g.doors:
		check(d.node.find_children("*","Label3D",true,false).is_empty(),"no permanent lock label on "+d.node.name)
	var door: Dictionary=g.layout.room_doors.U05[0]
	await aim(Vector3(45,4.2,9.2),door.node.to_global(Vector3(0,1.3,-.27)));await wait(.05)
	check(g.prompt.text=="E — Open","reachable locked door has generic screen prompt")
	g.interact();var trace_count: int=g.audio_trace.size();g.interact();await wait(.05)
	check(g.message.text.contains("Locked. Requires") and g.audio_trace.size()==trace_count,"locked feedback is interaction-only and debounced")
	await wait(2.2)
	check(g.message.modulate.a==0,"locked feedback clears after two seconds")
	g.expansion.set_day(true);await wait(.1)
	check(not g.expansion.lesson_audio[0].playing and not g.expansion.lesson_caption(3).is_empty(),"rejected teacher audio disabled while timed translated caption survives")
	g.expansion.set_day(false)
	g.player_voice.reset();g.player_voice.wake_delay=-1;g.player_voice.request("P06");await wait(.1)
	check(not g.player_voice.speaker.playing and g.player_voice.subtitle_panel.visible,"rejected player voice replaced by sparse caption")
	g.player_voice.flush()
	check(AudioServer.get_bus_index("PlayerSFX")>=0 and AudioServer.get_bus_index("WorldSFX")>=0 and AudioServer.get_bus_effect(0,0) is AudioEffectHardLimiter,"separate SFX routing with final safety limiter")
	await integrated_segment()
	finish_suite()

func integrated_segment() -> void:
	# One integrated danger segment, starting at a declared archive-complete fixture.
	g.start_game();g.player_voice.wake_delay=-1
	var p: Node=g.progression.story_puzzles
	p.utility_inventory={"upper":true,"festival":true,"media":true,"tape":true}
	for i in [0,1]:g.keys[i].set_meta("collected",true);g.keys[i].hide();p.solved[i]=true
	g.collected=2
	for d in g.doors:
		if str(d.room).begins_with("STAIR"): g.toggle_door(d)
	await wait(.8)
	await door_use(g.layout.room_doors.U05[0],Vector3(45,4.2,9.3))
	await use(target("recording").point,Vector3(41.65,4.2,2.7));await use(target("recording").point,Vector3(41.65,4.2,2.7))
	check(p.recording.playing and g.player_voice.pending.is_empty(),"integrated tape preempts comments and plays actual recording")
	await wait(p.recording.stream.get_length()+.3)
	for attempt in range(20):
		if p.tape_done: break
		await wait(.1)
	print("TAPE FINISH done=",p.tape_done," playing=",p.recording.playing," mode=",g.mode," position=",p.recording.get_playback_position()," length=",p.recording.stream.get_length())
	check(p.tape_done and not g.progression.hunt_enabled,"tape completion waits for inspection to close")
	g.progression.evidence.close();await wait(3.4)
	check(g.progression.hunt_enabled and g.grace<=0,"tape aftermath enables real danger")
	if not g.progression.hunt_enabled: return
	var walker=preload("res://tests/layout_shell.gd").new();walker.game=g
	var escaped:=true
	Input.action_press("sprint")
	for point in [Vector3(44.8,4.2,4.5),Vector3(45,4.2,9.5),Vector3(46,4.2,17.8)]:
		if not await walker.walk_to(point):escaped=false;break
	var route: PackedVector3Array=g.layout.stair_routes[1].duplicate();route.reverse()
	if escaped:
		for point in route:
			if not await walker.walk_to(point):escaped=false;break
	Input.action_release("sprint")
	check(escaped and g.mode=="playing" and not g.sees_player(),"actual lethal pursuit escaped through corridor corners and east stairs")
	g.progression.encounters_controller.pressure_cooldown=60
	g.enemy.position=g.player.position+Vector3(.5,1.4,0);g.grace=0;await wait(.2)
	check(g.mode=="capture","cooldown never disables capture on valid close contact")
	await wait(1.9)
	check(g.mode=="dead","capture reaches death")
	g.return_to_checkpoint();await wait(.05)
	check(g.collected==2 and p.tape_done and g.grace>7 and not g.progression.cry.playing and g.player_voice.pending.is_empty(),"retry preserves solved phase, clears stale audio and gives brief reorientation")

func finish_suite() -> void:
	finished=true
	print("BUGFIX VERIFY COMPLETE: ",count," checks; failures: ",failed)
	if failed:g.get_tree().quit(1)
	else:g.quit_game()
