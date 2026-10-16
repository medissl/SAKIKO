extends Control
## Quiet, occlusion-tested corner cues. Actions stay in the aimed prompt.
const RADIUS := 2.0
const MAX_CUES := 3
var game: Node
var cues: Array[Dictionary] = []
var proximity_time:=0.0
var proximity_period:=.10
var nearby: Array[Dictionary]=[]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = game.progression.story_puzzles.available_targets()
	for key in game.keys:
		if is_instance_valid(key) and key.visible and not key.get_meta("collected",false):
			result.append({"type":"key","node":key,"point":key.global_position})
	var small: Array[Dictionary] = []
	for item in result:
		if item.type in ["key","utility","service_key","rehearsal_key","evidence","fragment"]: small.append(item)
	return small

func same_target(a: Dictionary,b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or a.type!=b.type: return false
	match a.type:
		"key": return a.node==b.node
		"door": return a.door.node==b.door.node
		"evidence": return a.id==b.id
		"utility": return a.id==b.id
		"piece","mount","fragment","portrait_slot": return a.index==b.index
	return true

func half_size(kind: String) -> Vector3:
	match kind:
		"evidence": return Vector3(.26,.19,.025)
		"piece","mount": return Vector3(.33,.32,.10)
		"festival_desk": return Vector3(.25,.16,.24)
		"recording": return Vector3(.36,.18,.24)
		"av_power": return Vector3(.23,.28,.07)
		"exit": return Vector3(.25,.40,.10)
		"key": return Vector3(.15,.09,.10)
	return Vector3(.20,.22,.12)

func screen_bounds(point: Vector3,extent: Vector3) -> Rect2:
	var camera: Camera3D = game.player.camera
	var rect := Rect2(camera.unproject_position(point),Vector2.ZERO)
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]:
				var corner := point+extent*Vector3(x,y,z)
				if camera.is_position_behind(corner): return Rect2()
				rect = rect.expand(camera.unproject_position(corner))
	var center := rect.get_center()
	# Keep cues small at arm's length and legible for tiny keys.
	var dimensions := rect.size.clamp(Vector2(20,18),Vector2(150,130))
	return Rect2(center-dimensions*.5,dimensions).grow(4)

func _process(_delta: float) -> void:
	proximity_time-=_delta
	cues.clear()
	visible = game!=null and game.player!=null and game.mode=="playing"
	if visible:
		var camera: Camera3D = game.player.camera
		var aimed: Dictionary = game.interactable()
		# The prompt already resolved distance, occlusion and aim this frame.
		# Only its target can receive brackets; avoid a second scene-wide scan.
		nearby.clear()
		if not aimed.is_empty() and aimed.type in ["key","utility","service_key","rehearsal_key","evidence","fragment"]:
			nearby.append(aimed)
		for item in nearby:
			if not same_target(item,aimed): continue
			var point: Vector3 = item.point
			if camera.is_position_behind(point) or camera.global_position.distance_squared_to(point)>RADIUS*RADIUS: continue
			var rect := screen_bounds(point,half_size(item.type))
			if not rect.has_area() or not Rect2(Vector2.ZERO,size).encloses(rect): continue
			var distance := camera.global_position.distance_to(point)
			cues.append({"rect":rect,"distance":distance,"aimed":same_target(item,aimed),"target":item})
		cues.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.distance<b.distance)
		if cues.size()>MAX_CUES: cues.resize(MAX_CUES)
	else:
		nearby.clear()
		proximity_time=0
	queue_redraw()

func _draw() -> void:
	for cue in cues:
		var rect: Rect2 = cue.rect
		var alpha := .58*(1-smoothstep(1.5,RADIUS,float(cue.distance)))
		var color := Color(.72,.69,.60,alpha)
		if cue.aimed: color = Color(.86,.81,.69,maxf(.75,alpha))
		var length := minf(8,minf(rect.size.x,rect.size.y)*.24)
		for direction in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var corner: Vector2 = rect.get_center()+rect.size*.5*direction
			for axis in [Vector2(-direction.x,0),Vector2(0,-direction.y)]:
				draw_line(corner,corner+axis*length,Color(0,0,0,alpha*.7),3,true)
				draw_line(corner,corner+axis*length,color,1.3,true)
