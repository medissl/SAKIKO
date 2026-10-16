extends Node
## Classroom life and day/night presentation; obsolete map generation is disabled.
var game: Node
var figures: Node3D
var day_lights: Array[OmniLight3D]=[]
var lesson_audio: Array[AudioStreamPlayer3D]=[]
var time:=0.0
var lesson_step:=-1
var classroom_cue:=-1

func build(g: Node) -> void:
	game=g
	figures=Node3D.new()
	figures.name="DaytimeClass_G01"
	game.world.add_child(figures)
	for point in game.layout.seats:
		if point.distance_to(game.layout.SEATED)<.1: continue
		var person=preload("res://scripts/classroom_actor.gd").new()
		person.position=point
		person.rotation.y=-PI/2
		figures.add_child(person)
	var teacher=preload("res://scripts/classroom_actor.gd").new()
	teacher.teacher=true
	teacher.position=Vector3(8.95,0,4)
	teacher.rotation.y=PI/2
	figures.add_child(teacher)
	for x in [10,14]:
		var light:=OmniLight3D.new()
		light.position=Vector3(x,2.7,4)
		light.light_energy=2.8
		light.omni_range=12
		light.light_color=Color("ede6d1")
		game.world.add_child(light)
		day_lights.append(light)
	if AudioServer.get_bus_index("OutsidePlay")<0:
		AudioServer.add_bus()
		var bus: int=AudioServer.bus_count-1
		AudioServer.set_bus_name(bus,"OutsidePlay")
		AudioServer.set_bus_send(bus,"Classroom")
		var filter:=AudioEffectLowPassFilter.new()
		filter.cutoff_hz=1500
		AudioServer.add_bus_effect(bus,filter)
	for spec in [["res://assets/audio/teacher_lesson.wav",Vector3(8.95,1.6,4),-10.0,"TeacherVoice"],["res://assets/audio/classroom_murmur.wav",Vector3(12.5,1.3,6.5),-3.0,"Classroom"],["res://assets/audio/production/children_playing_piermic.mp3",Vector3(12,1.5,-2.0),-7.0,"OutsidePlay"]]:
		var audio:=AudioStreamPlayer3D.new()
		# The silent teacher node preserves cue indexing; retired VA is not shipped.
		if spec[3]!="TeacherVoice": audio.stream=load(spec[0])
		audio.position=spec[1]
		audio.volume_db=spec[2]
		audio.set_meta("day_volume",spec[2])
		audio.bus=spec[3]
		audio.unit_size=5
		audio.max_distance=28
		game.world.add_child(audio)
		lesson_audio.append(audio)
		if spec[3]!="TeacherVoice":
			audio.finished.connect(func():
				if figures.visible: audio.play())
	set_day(false)

func set_day(on: bool) -> void:
	figures.visible=on
	if on: time=0; lesson_step=-1; classroom_cue=-1
	for light in day_lights: light.visible=on
	for audio in lesson_audio:
		if on and (audio!=lesson_audio[0] or game.voice_quality.teacher_enabled): audio.play()
		else: audio.stop()
	game.layout.exterior.set_day(on)
	var env: Environment=game.world.get_child(0).environment
	env.background_mode=Environment.BG_SKY
	env.fog_enabled=true
	env.ambient_light_energy=.55 if on else .016
	env.ambient_light_sky_contribution=0
	env.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	for light in game.lights:
		light.light_energy=light.get_meta("day_energy",.2) if on else light.get_meta("night_energy",.04)
		# Zero-energy lights still belong to the render/light-culling workload.
		# Keep the physical fixture mesh; remove unlit light nodes from rendering.
		light.visible=light.light_energy>.001
		light.shadow_enabled=false
	env.ambient_light_color=Color("b4b6a7") if on else Color("667c86")
	if game.layout.lesson_mesh and not on: game.layout.lesson_mesh.text="15 OCTOBER\n\nLeave your books on the desk."

func _process(delta: float) -> void:
	if not figures or not figures.visible: return
	time+=delta
	for audio in lesson_audio:
		audio.volume_db=lerpf(float(audio.get_meta("day_volume")),-65,smoothstep(125,128,time))
	var step:=mini(4,int(time/25))
	if step!=lesson_step:
		lesson_step=step
		game.layout.lesson_mesh.text=["LITERATURE\n\nWords / actions / feelings", "READING A CHARACTER\n\nA clock. A glance down the street.", "CONTEXT\n\nImpatient? Excited?\nWhat happens before and after?", "CONNECT THE ACTIONS\n\nWaves and runs over / turns away", "SUPPORT YOUR READING\n\nWhich words led you there?"][step]
	var cue:=int(time/17)
	if cue!=classroom_cue:
		classroom_cue=cue
		if cue in [1,3,5]: game.sound("creak",-31,1.15)
	for person in figures.get_children(): person.class_activity(time)

func lesson_caption(t: float) -> String:
	for cue in game.audio_production.get("teacher_captions",[]):
		if t>=float(cue.start) and t<float(cue.end): return cue.text
	return ""
