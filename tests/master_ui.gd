extends RefCounted
var g: Node
var failures:=0
var checks:=0

func check(ok: bool, description: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",description)
	if not ok: failures+=1

func settle() -> void:
	for frame in range(4): await g.get_tree().process_frame
	await g.get_tree().create_timer(.12).timeout

func button(label: String) -> Button:
	for node in g.menu.find_children("*","Button",true,false):
		if node.text==label: return node
	return null

func fits() -> bool:
	var bounds:=g.get_viewport().get_visible_rect()
	for node in g.menu.find_children("*","Button",true,false):
		if node.is_visible_in_tree() and not bounds.encloses(node.get_global_rect()): return false
	return true

func escape() -> void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_ESCAPE;event.keycode=KEY_ESCAPE;event.pressed=true
	Input.parse_input_event(event)
	await settle()
	event=InputEventKey.new();event.physical_keycode=KEY_ESCAPE;event.keycode=KEY_ESCAPE;event.pressed=false
	Input.parse_input_event(event)

func run(game: Node) -> void:
	g=game
	var saved: Dictionary=g.settings.duplicate(true)
	g.settings.fullscreen=false;g.apply_settings()
	var journal: Node=g.progression.evidence
	var p: Node=g.progression.story_puzzles
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		g.get_window().size=size
		await settle()
		g.show_main_menu();await settle()
		check(fits(),"main menu fits "+str(size))
		await g.snapshot("master_menu_"+str(size.y))
		g.options_return="menu";g.show_options();await settle()
		check(fits(),"options fit "+str(size))
		var quality: OptionButton=g.menu.find_children("*","OptionButton",true,false)[0]
		for level in [0,1,2]:
			quality.select(level);quality.item_selected.emit(level)
			check(g.get_viewport().msaa_3d==level,"anti-aliasing option applies "+str(level))
		var sliders: Array=g.menu.find_children("*","HSlider",true,false)
		sliders[3].value=0
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ghost")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("CreatureDry")),"creature slider mutes both spatial and dry creature buses")
		sliders[3].value=saved.voice
		await g.snapshot("master_options_"+str(size.y))
		button("BACK").pressed.emit();await settle()
		check(g.nav_buttons.size()==4,"submenu returns menu selection")
		g.show_credits();await settle();check(fits(),"creator fit "+str(size));await g.snapshot("master_creator_"+str(size.y))
		g.start_game();await g.get_tree().create_timer(.9).timeout
		for id in ["program","display"]:
			journal.inspect(id);await settle()
			check(button("TRANSCRIPTION")==null and g.menu.find_children("*","RichTextLabel",true,false).is_empty(),"paper inspection has no duplicate transcript or added clue")
			if id=="display": button("FLIP").pressed.emit()
			await settle()
			check(fits(),"inspection controls fit "+id+" "+str(size))
			await g.snapshot("master_inspection_"+id+"_"+str(size.y))
			check(journal.reverse==(id=="display"),"front/reverse state "+id)
			await escape();check(g.mode=="playing","Escape closes inspection")
		journal.show_journal();await settle();check(fits(),"journal fits "+str(size));await g.snapshot("master_journal_"+str(size.y))
		await escape();check(g.mode=="playing","journal Escape returns controls")
		p.combination();await settle()
		check(g.get_viewport().gui_get_focus_owner() is LineEdit,"code field has keyboard focus")
		var wheels: Array=g.menu.find_children("*","SpinBox",true,false)
		for i in range(4): wheels[i].value=[1,0,0,1][i]
		button("RELEASE LATCH").pressed.emit();await settle()
		check(g.mode=="puzzle" and not p.containers.av_case.open,"wrong actual wheels keep physical case shut")
		await g.snapshot("master_code_"+str(size.y))
		await escape();check(g.mode=="playing" and not p.containers.av_case.open,"focused code Escape cancels without unlock")
		p.combination();await settle();wheels=g.menu.find_children("*","SpinBox",true,false)
		for i in range(4): wheels[i].value=[1,0,1,5][i]
		button("RELEASE LATCH").pressed.emit();await settle()
		await g.get_tree().create_timer(.75).timeout
		check(g.mode=="playing" and p.containers.av_case.open,"actual widgets release latch with 1015")
		Input.action_press("sprint");g.show_pause();Input.action_release("sprint");await settle()
		check(not Input.is_action_pressed("sprint") and fits(),"pause releases held sprint; fits "+str(size))
		await g.snapshot("master_pause_"+str(size.y));g.resume_game()
	g.get_window().size=Vector2i(1280,720);await settle()
	g.play_intro();await g.get_tree().create_timer(3).timeout
	await g.snapshot("master_intro")
	g.start_game();await g.get_tree().create_timer(.9).timeout
	g.mode="inspection";g.hud.hide();g.prompt.hide();g.message.hide()
	for shot in [["G01",Vector3(15.46,0,5.9),Vector3(8.7,1.4,3.2)],["archive",Vector3(14,4.2,29.6),Vector3(12.5,5.4,32.8)],["corridor",Vector3(28,0,10),Vector3(38,1.5,10)]]:
		await g.audit_view(shot[1],shot[2])
		for on in [false,true]:
			g.player.lamp.visible=on;await settle();await g.snapshot("master_final_"+shot[0]+("_on" if on else "_off"))
	g.player.lamp.show()
	for shot in [["padlocks",Vector3(1.2,0,12),Vector3(.13,1.25,12)],["stair_landing",Vector3(4.6,.5,19.6),Vector3(4.6,2,23)]]:
		await g.audit_view(shot[1],shot[2]);await g.snapshot("master_final_"+shot[0])
	await g.audit_view(Vector3(30,4.2,26),Vector3(42,5.7,26))
	g.enemy.show();g.enemy.position=Vector3(42,5.7,26);g.enemy.look_at(g.player.camera.global_position)
	await settle();await g.snapshot("master_final_encounter_far")
	g.enemy.position=Vector3(33,5.7,26);await settle();await g.snapshot("master_final_encounter_near")
	g.settings=saved;g.save_settings()
	print("MASTER UI COMPLETE: ",checks," checks; failures: ",failures)
	g.get_tree().quit(1 if failures else 0)
