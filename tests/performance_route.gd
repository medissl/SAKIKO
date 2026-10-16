extends RefCounted
## Standalone raster benchmark; fixed camera sweeps, not a navigation test.
var g: Node
var results: Array=[]

func percentile(values: Array, p: float) -> float:
	values.sort()
	return values[mini(values.size()-1,int((values.size()-1)*p))]

func sample(title: String, point: Vector3, look: Vector3, seconds:=4.0) -> void:
	g.mode="playing"
	g.input_focused=true
	g.player.position=point
	g.player.velocity=Vector3.ZERO
	g.player.rotation=Vector3.ZERO
	if title=="chase": g.player.rotation.y=-PI/2
	g.player.camera.look_at(look)
	await g.get_tree().create_timer(.8).timeout
	var frames: Array=[]
	var cpu: Array=[]
	var physics: Array=[]
	var calls: Array=[]
	var objects: Array=[]
	var primitives: Array=[]
	var gpu: Array=[]
	var render_cpu: Array=[]
	var render_timing:=RenderingServer.has_method("viewport_set_measure_render_time")
	if render_timing: RenderingServer.call("viewport_set_measure_render_time",g.get_viewport().get_viewport_rid(),true)
	var started:=Time.get_ticks_usec()
	var last:=started
	while (Time.get_ticks_usec()-started)/1000000.0<seconds:
		await g.get_tree().process_frame
		var now:=Time.get_ticks_usec()
		frames.append((now-last)/1000.0)
		last=now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		if render_timing:
			gpu.append(RenderingServer.call("viewport_get_measured_render_time_gpu",g.get_viewport().get_viewport_rid()))
			render_cpu.append(RenderingServer.call("viewport_get_measured_render_time_cpu",g.get_viewport().get_viewport_rid()))
		g.player.camera.look_at(look)
		g.player.camera.rotate_y((now-started)/1000000.0*.02)
	var row:={"stage":title,"frames":frames.size(),"median_ms":percentile(frames,.5),"p95_ms":percentile(frames,.95),"cpu_process_ms":percentile(cpu,.5),"physics_ms":percentile(physics,.5),"draw_calls":percentile(calls,.5),"render_objects":percentile(objects,.5),"primitives":percentile(primitives,.5)}
	if render_timing:
		row["render_gpu_ms"]=percentile(gpu,.5)
		row["render_cpu_ms"]=percentile(render_cpu,.5)
	results.append(row)
	print("PROFILE ",JSON.stringify(row))

func run(game: Node) -> void:
	g=game
	seed(4722026)
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	g.start_game()
	g.player_voice.flush()
	g.player_voice.wake_delay=-1
	await g.get_tree().create_timer(2).timeout
	if "--profile-master" in OS.get_cmdline_user_args():
		for stage in [["classroom",Vector3(15.46,0,2.7),Vector3(9,1.5,4)],["corridor",Vector3(28,0,10),Vector3(38,1.5,10)],["stairs",Vector3(4.6,.5,19.6),Vector3(4.6,1.8,22.6)],["archive",Vector3(14,4.2,29.6),Vector3(12.5,5.4,32.8)]]:
			await sample(stage[0],stage[1],stage[2])
		g.progression.hunt_enabled=true;g.enemy.visible=true;g.enemy.position=Vector3(18,1.5,10)
		g.ai_state="chase";g.grace=0;g.state_time=0
		g.last_seen=Vector3(28,1.4,10)
		g.navigate(g.last_seen)
		Input.action_press("forward")
		await sample("chase",Vector3(28,0,10),Vector3(40,1.5,10),3)
		Input.action_release("forward")
		var label:="baseline" if "--master-baseline" in OS.get_cmdline_user_args() else "final"
		var report:={"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":str(g.get_viewport().get_visible_rect().size),"mode":"standalone, fixed camera sweeps; live collision/scripts; actual walking pursuit in chase sample","msaa":g.get_viewport().msaa_3d,"results":results,"ending_mode":g.mode}
		var file:=FileAccess.open("res://tests/artifacts/master_performance_"+label+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"));file.close()
		g.quit_game();return
	if "--profile-fixtures" in OS.get_cmdline_user_args():
		for stage in [["classroom",Vector3(14.8,0,5.5),Vector3(10.5,1.5,4)],["corridor",Vector3(28,0,10),Vector3(38,1.5,10)],["stairs",Vector3(4.6,.5,19.6),Vector3(4.6,1.8,22.6)],["upper_science",Vector3(26,4.2,6),Vector3(30,5.3,3)]]:
			for disabled in [false,true]:
				for light in g.lights:
					light.visible=not disabled
					light.shadow_enabled=not disabled
				await sample(stage[0]+("_unlit_disabled" if disabled else "_unlit_active"),stage[1],stage[2],4)
		var comparison:=FileAccess.open("res://tests/artifacts/performance_fixtures.json",FileAccess.WRITE)
		comparison.store_string(JSON.stringify(results,"\t"));comparison.close()
		g.quit_game();return
	if "--profile-final-compare" in OS.get_cmdline_user_args():
		var meshes: Array=[]
		for node in g.world.find_children("*","MeshInstance3D",true,false):
			if node.mesh is BoxMesh: meshes.append([node,node.mesh,node.mesh.duplicate()])
		for stage in [["classroom",Vector3(14.8,0,5.5),Vector3(10.5,1.5,4)],["corridor",Vector3(28,0,10),Vector3(38,1.5,10)],["stairs",Vector3(4.6,.5,19.6),Vector3(4.6,1.8,22.6)],["upper_science",Vector3(26,4.2,6),Vector3(30,5.3,3)]]:
			for optimized in [false,true]:
				for row in meshes: row[0].mesh=row[1] if optimized else row[2]
				g.interaction_cache_enabled=optimized
				g.interaction_hints.proximity_period=.1 if optimized else 0.0
				await sample(stage[0]+("_shared" if optimized else "_unique"),stage[1],stage[2],4)
		var comparison:=FileAccess.open("res://tests/artifacts/performance_final_comparison.json",FileAccess.WRITE)
		comparison.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":str(g.get_viewport().get_visible_rect().size),"msaa":g.get_viewport().msaa_3d,"focus_loss_pausing_suppressed":true,"mode":"standalone development; fixed time-based camera sweep, scripts and physics active; same current content both states","results":results},"\t"));comparison.close()
		g.quit_game();return
	if "--profile-msaa" in OS.get_cmdline_user_args():
		g.get_viewport().use_occlusion_culling=false
		for stage in [["classroom",Vector3(14.8,0,5.5),Vector3(10.5,1.5,4)],["corridor",Vector3(28,0,10),Vector3(38,1.5,10)],["stairs",Vector3(4.6,.5,19.6),Vector3(4.6,1.8,22.6)],["upper_science",Vector3(26,4.2,6),Vector3(30,5.3,3)]]:
			for balanced in [false,true]:
				g.get_viewport().msaa_3d=Viewport.MSAA_2X if balanced else Viewport.MSAA_4X
				await sample(stage[0]+("_2x" if balanced else "_4x"),stage[1],stage[2],4)
		var comparison:=FileAccess.open("res://tests/artifacts/performance_msaa.json",FileAccess.WRITE)
		comparison.store_string(JSON.stringify(results,"\t"));comparison.close()
		g.quit_game();return
	if "--profile-moon" in OS.get_cmdline_user_args():
		g.get_viewport().use_occlusion_culling=false
		var original_mode: int=g.layout.exterior.sun.directional_shadow_mode
		for stage in [["classroom",Vector3(14.8,0,5.5),Vector3(10.5,1.5,4)],["corridor",Vector3(28,0,10),Vector3(38,1.5,10)],["stairs",Vector3(4.6,.5,19.6),Vector3(4.6,1.8,22.6)],["upper_science",Vector3(26,4.2,6),Vector3(30,5.3,3)]]:
			for single in [false,true]:
				g.layout.exterior.sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL if single else original_mode
				await sample(stage[0]+("_single_moon" if single else "_original"),stage[1],stage[2],4)
		var comparison:=FileAccess.open("res://tests/artifacts/performance_moon.json",FileAccess.WRITE)
		comparison.store_string(JSON.stringify({"original_shadow_mode":original_mode,"results":results},"\t"));comparison.close()
		g.quit_game();return
	if "--profile-compare" in OS.get_cmdline_user_args():
		for stage in [["classroom",Vector3(14.8,0,5.5),Vector3(10.5,1.5,4)],["corridor",Vector3(28,0,10),Vector3(38,1.5,10)],["stairs",Vector3(4.6,.5,19.6),Vector3(4.6,1.8,22.6)],["upper_science",Vector3(26,4.2,6),Vector3(30,5.3,3)]]:
			for state in [["original",false,false],["occlusion",false,true]]:
				g.static_optimizer.select_batching(state[1])
				g.get_viewport().use_occlusion_culling=state[2]
				await sample(stage[0]+"_"+state[0],stage[1],stage[2],4)
		var compare:=FileAccess.open("res://tests/artifacts/performance_comparison.json",FileAccess.WRITE)
		compare.store_string(JSON.stringify(results,"\t"));compare.close()
		g.quit_game();return
	if "--profile-diagnose" in OS.get_cmdline_user_args():
		await sample("diagnose_normal",Vector3(28,0,10),Vector3(38,1.5,10),6)
		g.layout.exterior.sun.shadow_enabled=false
		await sample("diagnose_no_moon_shadows",Vector3(28,0,10),Vector3(38,1.5,10),6)
		g.layout.exterior.sun.shadow_enabled=true
		for mesh in g.world.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh and mesh.mesh.resource_path.contains("sakiko_hair"):
				mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		await sample("diagnose_no_doll_hair_shadows",Vector3(28,0,10),Vector3(38,1.5,10),6)
		g.quit_game();return
	for stage in [["classroom",Vector3(14.8,0,5.5),Vector3(10.5,1.5,4)],["corridor",Vector3(28,0,10),Vector3(38,1.5,10)],["stairs",Vector3(4.6,.5,19.6),Vector3(4.6,1.8,22.6)],["upper_science",Vector3(26,4.2,6),Vector3(30,5.3,3)]]:
		await sample(stage[0],stage[1],stage[2])
	if "--profile-probes" in OS.get_cmdline_user_args():
		g.film.hide()
		await sample("probe_no_film",Vector3(28,0,10),Vector3(38,1.5,10),3)
		g.film.show()
		g.player.lamp.shadow_enabled=false
		g.player.spill.shadow_enabled=false
		await sample("probe_no_flashlight_shadows",Vector3(28,0,10),Vector3(38,1.5,10),3)
		g.player.lamp.shadow_enabled=true
		g.player.spill.shadow_enabled=true
		g.world.hide()
		await sample("probe_no_world_render",Vector3(28,0,10),Vector3(38,1.5,10),3)
		g.world.show()
	var label:="baseline" if "--profile-baseline" in OS.get_cmdline_user_args() else RenderingServer.get_current_rendering_method()
	var report:={"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"viewport":str(g.get_viewport().get_visible_rect().size),"run_mode":"standalone development build, fixed camera sweeps; scripts/physics active","vsync":"disabled for both comparisons","gpu_frame_ms":"viewport GPU timestamps where supported; see individual samples","nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"results":results}
	var f:=FileAccess.open("res://tests/artifacts/performance_"+label+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"));f.close()
	g.quit_game()
