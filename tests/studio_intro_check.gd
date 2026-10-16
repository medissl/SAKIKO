extends RefCounted
var failures := 0
func check(ok: bool, description: String) -> void:
	print("STUDIO PASS " if ok else "STUDIO FAIL ",description)
	if not ok: failures += 1

func run(g: Node) -> void:
	check(not ProjectSettings.get_setting("application/boot_splash/show_image",true),"default Godot logo is disabled at launch")
	check(g.mode=="menu" and not is_instance_valid(g.studio_intro),"startup naturally completes into the menu")
	check(g.menu_selection.has_focus(),"PLAY receives focus after startup")
	check(not AudioServer.is_bus_mute(0) or g.settings.master<=0,"menu audio restores the volume setting")
	var s = load("res://scripts/studio_intro.gd").new()
	g.mode="studio_intro"
	g.menu.process_mode=Node.PROCESS_MODE_DISABLED
	AudioServer.set_bus_mute(0,true)
	g.add_child(s)
	s.setup(g)
	g.studio_intro=s
	s.set_process(false)
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=false
	s.age=1.9
	s.consume(click)
	check(is_equal_approx(s.age,1.9),"early clicks cannot skip")
	s.age=2.1
	click.pressed=true
	s.consume(click)
	check(is_equal_approx(s.age,2.1),"a held click cannot skip")
	click.pressed=false
	s.consume(click)
	check(is_equal_approx(s.age,3.6),"released click after two seconds begins fade")
	s.age=2.2
	var touch := InputEventScreenTouch.new()
	touch.pressed=false
	s.consume(touch)
	check(is_equal_approx(s.age,3.6),"released touch also skips after two seconds")
	s.age=3.875
	s.update_visuals()
	check(absf(s.overlay.modulate.a-.5)<.001,"fade midpoint is 275ms")
	s.age=.1
	g.input_focused=false
	s._process(.4)
	check(is_equal_approx(s.age,.1),"unfocused application pauses the splash clock")
	g.input_focused=true
	var reduced: bool=g.settings.reduced
	g.settings.reduced=true
	s.age=0
	s.update_visuals()
	check(s.portrait.modulate.a==1 and s.portrait.scale==Vector2.ONE and s.letters[0].modulate.a==1 and s.subtitle.modulate.a==1,"reduced motion removes entrance motion")
	g.settings.reduced=false
	s.age=1.6
	s.update_visuals()
	check(s.letters.size()==7 and s.portrait.size==Vector2(86,86),"portrait and seven separately animated letters")
	check(s.letters[0].get_theme_font("font").resource_path.ends_with("SakikoThorn.ttf"),"original local typeface; no Fredoka dependency")
	check(g.mode=="studio_intro" and g.menu.process_mode==Node.PROCESS_MODE_DISABLED and AudioServer.is_bus_mute(0),"menu input and audio blocked throughout splash")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png("C:/Users/media/OneDrive/Documents/sakiko/tests/artifacts/studio_intro.png")
	Input.action_press("interact")
	Input.action_press("ui_accept")
	s.age=4.14
	s._process(.02)
	check(not s.active and not Input.is_action_pressed("interact") and not Input.is_action_pressed("ui_accept"),"completion clears held gameplay and menu actions")
	g.studio_intro=null
	g.settings.reduced=reduced
	g.menu.process_mode=Node.PROCESS_MODE_INHERIT
	g.show_main_menu()
	AudioServer.set_bus_mute(0,g.settings.master<=0)
	await g.get_tree().process_frame
	check(not is_instance_valid(g.studio_intro),"returning to menu never replays the splash")
	print("STUDIO RESULT ",failures," failures")
	g.get_tree().quit(0 if failures==0 else 1)
