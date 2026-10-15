extends CharacterBody3D
var game: Node
var camera: Camera3D
var lamp: SpotLight3D
var pitch := 0.0
var step_clock := 0.0
var walking := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = .28
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = .85
	add_child(cs)
	camera = Camera3D.new()
	camera.position.y = 1.58
	camera.near = .06
	camera.fov = 76
	add_child(camera)
	lamp = SpotLight3D.new()
	lamp.position = Vector3(.17,-.13,-.12)
	lamp.light_color = Color("d0d6bf")
	lamp.light_energy = 3.4
	lamp.spot_range = 27
	lamp.spot_angle = 31
	lamp.spot_attenuation = 1.6
	lamp.shadow_enabled = true
	camera.add_child(lamp)

func _unhandled_input(event: InputEvent) -> void:
	if game.mode != "playing": return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x*game.settings.sensitivity*.001
		pitch = clampf(pitch-event.relative.y*game.settings.sensitivity*.001,-1.45,1.45)
		camera.rotation.x = pitch
	if event.is_action_pressed("flashlight"):
		lamp.visible = not lamp.visible
		game.sound("press",-18)
	if event.is_action_pressed("interact"): game.interact()

func _physics_process(delta: float) -> void:
	if game.mode != "playing": return
	var input := Input.get_vector("left","right","forward","back")
	var dir := transform.basis*Vector3(input.x,0,input.y)
	var speed := 5.4 if Input.is_action_pressed("sprint") else 3.2
	velocity.x = move_toward(velocity.x,dir.x*speed,delta*22)
	velocity.z = move_toward(velocity.z,dir.z*speed,delta*22)
	velocity.y -= 20*delta
	move_and_slide()
	walking = input.length() > .1
	if walking and is_on_floor():
		step_clock -= delta
		if step_clock <= 0:
			step_clock = .34 if speed > 4 else .51
			game.sound("step",-19,randf_range(.88,1.08))
