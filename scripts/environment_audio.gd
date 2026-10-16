extends Node
## One nearest-window source, updated at 4 Hz; no per-window playing loops.
var game: Node
var wind: AudioStreamPlayer3D
var fixture: AudioStreamPlayer3D
var interval:=0.0
func build(g: Node) -> void:
	game=g
	wind=AudioStreamPlayer3D.new()
	wind.stream=load("res://assets/audio/window_air.wav")
	wind.bus="Ambience";wind.max_distance=10;wind.unit_size=2
	game.world.add_child(wind)
	wind.finished.connect(wind.play);wind.play()
	fixture=AudioStreamPlayer3D.new()
	fixture.stream=game.sounds.hum
	fixture.position=Vector3(12,2.9,4)
	fixture.bus="Classroom";fixture.max_distance=8;fixture.unit_size=2
	fixture.volume_db=-40
	game.world.add_child(fixture)
	fixture.finished.connect(func():
		if game.mode=="intro": fixture.play())
func _process(delta: float) -> void:
	if not game or not game.player: return
	interval-=delta
	if interval>0: return
	interval=.25
	wind.stream_paused=game.mode!="playing"
	if game.mode=="intro" and not fixture.playing: fixture.play()
	elif game.mode!="intro": fixture.stop()
	if game.mode!="playing": return
	var closest:=INF
	for window in game.layout.windows:
		var point: Vector3=window.global_position
		if absf(point.y-game.player.camera.global_position.y)>2.2: continue
		var distance:=point.distance_squared_to(game.player.camera.global_position)
		if distance<closest: closest=distance;wind.position=point
	wind.volume_db=-4 if game.clear_line(game.player.camera.global_position,wind.position) else -12
