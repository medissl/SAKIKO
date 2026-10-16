extends RefCounted
# External QA driver. This file is excluded from the consumer export.
var failures:=0
var g: Node
var output: String

func check(ok: bool,description: String) -> void:
	print("EXPORT PASS " if ok else "EXPORT FAIL ",description)
	if not ok: failures+=1

func run(game: Node) -> void:
	g=game
	var args:=OS.get_cmdline_user_args()
	output=args[args.find("--qa-output")+1]
	check(not OS.has_feature("editor"),"running Windows export template")
	check(ProjectSettings.get_setting("application/config/name")=="Sakiko","embedded project settings load")
	for retired in ["festival_recording.wav","festival_date_recording.wav","festival_students.wav","teacher_lesson.wav","production/ja_P01.wav","production/P01.wav"]:
		check(not ResourceLoader.exists("res://assets/audio/"+retired),"retired speech excluded: "+retired)
	check(not FileAccess.file_exists("res://tests/corrections_integration.gd") and not FileAccess.file_exists("res://SAKIKO_FINAL_POLISH_MASTER.md"),"consumer pack excludes tests and implementation prompts")
	print("EXPORT ROOT ",ProjectSettings.globalize_path("res://")," test_source=",FileAccess.file_exists("res://tests/corrections_integration.gd")," master_prompt=",FileAccess.file_exists("res://SAKIKO_FINAL_POLISH_MASTER.md"))
	var legal:=FileAccess.open(output.path_join("GODOT_WINDOWS_EXPORT_NOTICES.txt"),FileAccess.WRITE)
	legal.store_string("Godot "+Engine.get_version_info().string+"\nNotices reported by the actual Windows release export template.\n\n"+Engine.get_license_text()+"\n\n")
	for component in Engine.get_copyright_info():
		legal.store_string(str(component.name)+"\n")
		for part in component.parts:
			legal.store_string("Files: "+", ".join(part.files)+"\n"+"\n".join(part.copyright)+"\nLicense: "+str(part.license)+"\n\n")
	for name in Engine.get_license_info(): legal.store_string(str(name)+"\n"+str(Engine.get_license_info()[name])+"\n\n")
	legal.close()
	await g.get_tree().create_timer(2).timeout
	check(g.mode=="menu" and g.nav_buttons.size()==4,"actual exported menu initializes")
	check(g.font.has_char(0x6559) and g.font.has_char(0x5ba4),"bundled font has the actual classroom sign kanji")
	if "--qa-manifest" in args:
		var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--qa-manifest")+1]))
		var matching:=true
		for path in expected:
			if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=expected[path]: matching=false;print("EXPORT LEGAL MISMATCH ",path)
		check(matching,"embedded legal/provenance hashes match "+str(expected.size())+" source files")
	if failures: g.get_tree().quit(1);return
	if "--qa-tape" in args:
		g.start_game()
		var p: Node=g.progression.story_puzzles
		p.utility_inventory.tape=true;p.inserted=true
		var subtitles: bool=g.settings.subtitles
		g.settings.subtitles=false
		p.interact({"type":"recording"})
		await g.get_tree().create_timer(1.2).timeout
		check(p.recording.playing and not p.captions.visible and g.progression.evidence.current=="recording","tape paper is not duplicated by bottom captions")
		g.progression.evidence.close()
		await g.get_tree().create_timer(.2).timeout
		check(p.captions.visible and p.captions.text.contains("F-12"),"essential tape captions remain available outside paper with optional subtitles off")
		p.recording.stop();g.settings.subtitles=subtitles
	if "--qa-full" in args:
		var suite_path: String=get_script().resource_path.get_base_dir().path_join("corrections_integration.gd")
		await load(suite_path).new().run(g)
		return
	if "--qa-profile" in args:
		if "--aa-2x" in args: g.settings.msaa=1;g.apply_settings()
		var profile_path: String=get_script().resource_path.get_base_dir().path_join("performance_route.gd")
		await load(profile_path).new().run(g)
		return
	if "--qa-visual" in args:
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png(output.path_join("export_menu.png"))
		g.show_options();await g.get_tree().create_timer(.2).timeout
		var quality: OptionButton=g.menu.find_children("*","OptionButton",true,false)[0]
		quality.select(1);quality.item_selected.emit(1)
		check(g.get_viewport().msaa_3d==1,"exported anti-aliasing control applies")
		quality.select(2);quality.item_selected.emit(2)
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png(output.path_join("export_options.png"))
		g.options_back()
		g.start_game();await g.get_tree().create_timer(1).timeout
		check(g.mode=="playing" and g.layout.placement.rejected.is_empty(),"exported furnished school starts without placement rejection")
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png(output.path_join("export_gameplay.png"))
		g.progression.evidence.inspect("program");await g.get_tree().create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png(output.path_join("export_inspection.png"))
		g.progression.evidence.close()
		g.mode="inspection"
		await g.audit_view(Vector3(45,4.2,29.4),Vector3(43.6,5.2,34.6))
		check(g.world.find_children("*","CharacterBody3D",true,false).is_empty(),"no decorative Sakiko clone in the school scenery")
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png(output.path_join("export_storage_review.png"))
		var env: Environment=g.world.get_child(0).environment
		var old_energy: float=env.ambient_light_energy
		var old_fog: bool=env.fog_enabled
		env.ambient_light_energy=.8;env.fog_enabled=false;g.player.lamp.hide();g.film.hide()
		for light in g.layout.inspection_lights: light.show()
		await g.get_tree().create_timer(.15).timeout
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png(output.path_join("master_U08_final_neutral.png"))
		g.player.camera.position.y=2.85
		await g.audit_view(Vector3(45,4.2,29.4),Vector3(43.6,5.2,34.6))
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png(output.path_join("master_U08_final_overview.png"))
		for light in g.layout.inspection_lights: light.hide()
		env.ambient_light_energy=old_energy;env.fog_enabled=old_fog;g.film.show()
		g.mode="playing";g.capture();await g.get_tree().create_timer(.6).timeout
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png(output.path_join("export_capture.png"))
		await g.get_tree().create_timer(1.5).timeout
		check(g.mode=="dead","export capture reaches death")
		g.return_to_checkpoint();await g.get_tree().create_timer(.2).timeout
		check(g.mode=="playing" and not g.player.pant.playing,"export retry restores input and clears pant")
	print("EXPORT SMOKE COMPLETE failures=",failures)
	g.get_tree().quit(1 if failures else 0)
