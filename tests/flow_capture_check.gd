extends RefCounted
var failures:=0
var probe: AudioEffectCapture
var mixed:=PackedVector2Array()
var pumping:=false
func check(ok: bool,text: String) -> void:
	print("CAPTURE PASS " if ok else "CAPTURE FAIL ",text)
	if not ok: failures+=1
func snap(g: Node,name: String) -> void:
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png("res://tests/artifacts/flow_capture_"+name+".png")
func collect_audio(g: Node) -> void:
	while pumping:
		await g.get_tree().process_frame
		if probe.can_get_buffer(probe.get_frames_available()): mixed.append_array(probe.get_buffer(probe.get_frames_available()))
func save_audio() -> void:
	var bytes:=PackedByteArray()
	bytes.resize(mixed.size()*4)
	var peak:=0.0
	for i in range(mixed.size()):
		peak=maxf(peak,maxf(absf(mixed[i].x),absf(mixed[i].y)))
		bytes.encode_s16(i*4,int(clampf(mixed[i].x,-1,1)*32767))
		bytes.encode_s16(i*4+2,int(clampf(mixed[i].y,-1,1)*32767))
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.stereo=true
	stream.mix_rate=int(AudioServer.get_mix_rate())
	stream.data=bytes
	stream.save_to_wav("res://tests/artifacts/flow_capture_actual_mix.wav")
	print("CAPTURE ACTUAL MIX peak=",peak," frames=",mixed.size())
	check(peak<.92 and peak>.10,"actual mixed capture is present with unclipped output")
func run(g: Node) -> void:
	g.start_game()
	await g.get_tree().create_timer(1).timeout
	probe=AudioEffectCapture.new()
	probe.buffer_length=.5
	AudioServer.add_bus_effect(0,probe)
	pumping=true
	collect_audio(g)
	g.capture()
	var blink_peak:=0.0
	var blink_shot:=false
	while g.capture_time<.9:
		await g.get_tree().process_frame
		var closure: float=g.scare_head.face_material.get_shader_parameter("blink")
		blink_peak=maxf(blink_peak,closure)
		if closure>.85 and not blink_shot:
			blink_shot=true
			await snap(g,"blink")
	check(blink_peak>.85 and g.scare_head.blink_time<0,"capture eyelids actually close and reopen before lunge")
	check(g.mode=="capture" and g.capture_time<1.2,"stare phase blocks gameplay before shriek")
	await snap(g,"stare")
	await g.get_tree().create_timer(.9).timeout
	check(g.capture_ghost.stream==g.sounds.capture_shriek and is_equal_approx(g.capture_ghost.pitch_scale,1.0),"natural pitch feminine vocal, no male grunt")
	await snap(g,"jaw")
	await g.get_tree().create_timer(.8).timeout
	await snap(g,"engulf")
	await g.get_tree().create_timer(.65).timeout
	check(g.curtain.modulate.a==1 and g.mode=="capture","blackout precedes menu with vocal tail")
	await g.get_tree().create_timer(.8).timeout
	check(g.mode=="dead" and g.capture_time>=3.9 and not g.capture_ghost.playing,"complete 3.9-second capture ends cleanly")
	pumping=false
	await g.get_tree().process_frame
	save_audio()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	for event in g.audio_trace: check(event.get("clip","")!="player_pain","capture mix has no player pain")
	g.settings.reduced=true
	g.get_tree().root.size=Vector2i(960,720)
	g.start_game()
	await g.get_tree().create_timer(.8).timeout
	g.capture()
	await g.get_tree().create_timer(2.6).timeout
	await snap(g,"four_three_reduced")
	check(absf(g.scare_camera.rotation.z)<.001,"reduced motion removes capture jolt")
	await g.get_tree().create_timer(1.5).timeout
	print("CAPTURE RESULT failures=",failures)
	g.quit_game()
