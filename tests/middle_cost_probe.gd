extends RefCounted
func run(g: Node) -> void:
	g.start_game();g.mode="performance_probe"
	g.player.position=Vector3(13.1,4.2,10.8)
	g.player.look_at(Vector3(14.03,4.2,10.8))
	g.player.pitch=atan2(5.2-g.player.camera.global_position.y,.93)
	g.player.camera.rotation.x=g.player.pitch
	g.hud.hide();g.prompt.hide();g.message.hide()
	var records: Array=[]
	for visible in [true,false,true]:
		for node in g.get_tree().get_nodes_in_group("middle_hardware"): node.visible=visible
		await g.get_tree().create_timer(1.5).timeout
		var frames:=PackedFloat64Array()
		var previous:=Time.get_ticks_usec()
		for frame in range(120):
			await g.get_tree().process_frame
			var now:=Time.get_ticks_usec()
			frames.append(float(now-previous)/1000);previous=now
		frames.sort()
		records.append({"middle_visible":visible,"median_ms":frames[60],"p95_ms":frames[114],"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)})
	var record: Dictionary={"scope":"Same process, camera, lighting and school; middle hardware visible/hidden/visible. Render cost only, not a simulation or historical whole-game baseline.","samples_per_phase":120,"window":str(g.get_viewport().get_visible_rect().size),"renderer":RenderingServer.get_current_rendering_method(),"phases":records}
	print("MIDDLE COST ",JSON.stringify(record))
	var file:=FileAccess.open("res://tests/artifacts/middle-render-cost.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"\t"));file.close()
	g.quit_game()
