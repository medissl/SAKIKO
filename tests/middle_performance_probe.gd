extends RefCounted
func run(g: Node) -> void:
	g.start_game()
	g.mode="performance_probe"
	g.player.position=Vector3(13.1,4.2,10.8)
	g.player.look_at(Vector3(14.03,4.2,10.8))
	g.player.pitch=atan2(5.2-g.player.camera.global_position.y,.93)
	g.player.camera.rotation.x=g.player.pitch
	g.hud.hide();g.prompt.hide();g.message.hide()
	await g.get_tree().create_timer(2).timeout
	var frames:=PackedFloat64Array()
	var previous:=Time.get_ticks_usec()
	for frame in range(180):
		await g.get_tree().process_frame
		var now:=Time.get_ticks_usec()
		frames.append(float(now-previous)/1000)
		previous=now
	frames.sort()
	var label: String="candidate"
	var args:=OS.get_cmdline_user_args()
	if "--perf-label" in args: label=args[args.find("--perf-label")+1]
	var record: Dictionary={"label":label,"samples":frames.size(),"median_ms":frames[90],"p95_ms":frames[171],"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"window":str(g.get_viewport().get_visible_rect().size),"renderer":RenderingServer.get_current_rendering_method(),"scope":"Fixed station view, same camera, lamp and inactive AI. Observational comparison; not whole-game FPS."}
	print("MIDDLE PERFORMANCE ",JSON.stringify(record))
	var file:=FileAccess.open("res://tests/artifacts/middle-performance-"+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"\t"));file.close()
	g.quit_game()
