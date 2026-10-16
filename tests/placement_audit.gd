extends RefCounted
func run(g: Node) -> void:
	g.start_game()
	await g.get_tree().create_timer(.85).timeout
	g.mode="inspection"
	g.hud.hide();g.prompt.hide();g.message.hide();g.film.hide();g.player.lamp.hide()
	var env: Environment=g.world.get_child(0).environment
	var old_energy:=env.ambient_light_energy
	var old_fog:=env.fog_enabled
	env.ambient_light_energy=.8
	env.fog_enabled=false
	for light in g.layout.inspection_lights: light.show()
	if "--representative-rooms" in OS.get_cmdline_user_args():
		for shot in [["G01",Vector3(15.46,0,5.9),Vector3(8.7,1.4,3.2)],["G02",Vector3(21.6,0,6.8),Vector3(19.4,1.2,3)],["U06",Vector3(14,4.2,29.6),Vector3(12.5,5.4,32.8)]]:
			await g.audit_view(shot[1],shot[2]);await g.snapshot("master_"+shot[0]+"_neutral")
		for light in g.layout.inspection_lights: light.hide()
		env.ambient_light_energy=old_energy;env.fog_enabled=old_fog;g.film.show()
		for shot in [["G01",Vector3(15.46,0,5.9),Vector3(8.7,1.4,3.2)],["U06",Vector3(14,4.2,29.6),Vector3(12.5,5.4,32.8)]]:
			await g.audit_view(shot[1],shot[2])
			for on in [false,true]:
				g.player.lamp.visible=on;await g.get_tree().create_timer(.1).timeout
				await g.snapshot("master_"+shot[0]+("_night_on" if on else "_night_off"))
		g.expansion.set_day(true);g.player.lamp.hide()
		await g.audit_view(Vector3(15.46,0,5.9),Vector3(8.7,1.4,3.2));await g.snapshot("master_G01_day")
		g.expansion.set_day(false);g.quit_game();return
	if "--placement-recheck" in OS.get_cmdline_user_args():
		for shot in [["infirmary_sink",Vector3(22,0,5.8),Vector3(23.43,.9,5.3)],["curtain_rail",Vector3(20.8,0,4),Vector3(19.25,2.5,2)],["staff_hooks",Vector3(26,0,6.8),Vector3(24.25,1.6,6.7)],["av_cables",Vector3(43.8,0,3),Vector3(41,.9,1.3)],["utility_sink",Vector3(10.9,0,33.7),Vector3(9,.9,35.43)],["utility_rack",Vector3(13.9,0,33.7),Vector3(11.8,1,35.7)],["art_sink",Vector3(36,0,33.7),Vector3(37.7,.9,35.43)],["science_counter",Vector3(29.6,4.2,5.9),Vector3(31.3,5.1,3.6)],["media_cables",Vector3(43.8,4.2,3),Vector3(42.1,5.1,1.3)],["locker_contents",Vector3(4.1,0,12),Vector3(3.6,1,15.6)]]:
			if "--placement-last" in OS.get_cmdline_user_args() and not shot[0] in ["staff_hooks","curtain_rail","utility_rack"]: continue
			await g.audit_view(shot[1],shot[2]);await g.snapshot("recheck_"+shot[0])
		for light in g.layout.inspection_lights: light.hide()
		env.ambient_light_energy=old_energy;env.fog_enabled=old_fog
		g.film.show();g.player.lamp.show()
		await g.audit_view(Vector3(28,0,10),Vector3(38,1.5,10));await g.snapshot("recheck_night_restored")
		g.quit_game();return
	for data in g.layout.ROOM_DATA:
		var only_rooms:=PackedStringArray()
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--rooms="): only_rooms=argument.trim_prefix("--rooms=").split(",")
		if not only_rooms.is_empty() and not data[0] in only_rooms: continue
		var area: Rect2=data[2]
		var y: float=data[4]*4.2
		var north: bool=area.position.y<8
		var corner:=Vector3(area.end.x-.85,y,area.end.y-1 if north else area.position.y+1.3)
		var look:=Vector3(area.position.x+area.size.x*.40,y+1,area.position.y+area.size.y*.45)
		var entries: Dictionary={"G05":[Vector3(45,y,6.4),Vector3(43.5,y+1.2,3)],"U04":[Vector3(37,y,6.4),Vector3(36,y+1.2,3.3)],"U05":[Vector3(45,y,6.4),Vector3(42.6,y+1.2,2)],"U07":[Vector3(29.2,y,29.5),Vector3(32,y+1.5,34)],"U08":[Vector3(45,y,29.4),Vector3(44.3,y+1.1,34)]}
		if entries.has(data[0]): corner=entries[data[0]][0];look=entries[data[0]][1]
		for height in [1.58,2.85]:
			g.player.position=corner
			g.player.camera.position.y=height
			g.player.rotation=Vector3.ZERO
			g.player.camera.look_at(look)
			await g.get_tree().create_timer(.12).timeout
			await g.snapshot("placement_"+str(data[0])+("_eye" if height<2 else "_overview"))
	for shot in [["lobby",Vector3(1.3,0,12),Vector3(6,1,14)],["west_stairs",Vector3(4.6,.5,19.6),Vector3(4.6,2,23)],["east_stairs",Vector3(51.4,.5,19.6),Vector3(51.4,2,23)],["corridor_ground",Vector3(12,0,10),Vector3(42,1.6,10)],["corridor_upper",Vector3(46,4.2,26),Vector3(12,5.8,26)]]:
		await g.audit_view(shot[1],shot[2])
		await g.snapshot("placement_"+shot[0])
	for light in g.layout.inspection_lights: light.hide()
	env.ambient_light_energy=old_energy;env.fog_enabled=old_fog
	g.quit_game()
