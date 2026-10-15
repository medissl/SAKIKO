extends Node
## Adds the east building to the original school and dresses both wings consistently.
const Tuning = preload("res://scripts/config.gd")
var game: Node
var figures: Node3D
var day_lights: Array[OmniLight3D] = []
var night_energy: Array[float] = []
var time := 0.0

func build(g: Node) -> void:
	game = g
	for z in [-5.0,5.0]:
		g.box(Vector3(54,-.15,z),Vector3(56,.3,4),"floor")
		g.box(Vector3(54,3.5,z),Vector3(56,.2,4),"ceiling")
		g.box(Vector3(54,1.7,z-signf(z)*2),Vector3(52,3.4,.18),"wall")
		for x in range(30,81,8):
			g.box(Vector3(x,3.22,z),Vector3(1.8,.08,.22),"metal",false)
			g.box(Vector3(x,3.16,z),Vector3(1.5,.04,.13),"light" if x<60 else "dark",false)
			if x<60: g.lamp(Vector3(x,2.9,z),.13,Color("a9b8a0"))
			g.box(Vector3(x,.10,z-signf(z)*1.88),Vector3(7.9,.18,.09),"wood",false)
		g.label3("← 玄関  ENTRANCE     |     図書室 LIBRARY →",Vector3(25,2.7,z),-PI/2,.0055)
		g.label3("旧校舎  /  OLD WING",Vector3(62,2.7,z),-PI/2,.005)
	g.box(Vector3(81,-.15,0),Vector3(4,.3,14),"floor")
	g.box(Vector3(81,3.5,0),Vector3(4,.2,14),"ceiling")
	g.box(Vector3(83,1.7,0),Vector3(.2,3.4,14),"wall")
	g.lamp(Vector3(81,2.6,0),.20,Color("5a809b"))
	for side in [-1,1]:
		for ri in range(3,6):
			var x: float = Tuning.ROOM_CENTRES[ri]
			var z: float = side*12.0
			g.box(Vector3(x,-.15,z),Vector3(14,.3,10),"floor")
			g.box(Vector3(x,3.5,z),Vector3(14,.2,10),"ceiling")
			g.box(Vector3(x,1.7,side*17),Vector3(14,3.4,.2),"wall")
			for dx in [-7,7]:
				if ri==5 and side>0 and dx==7:
					g.box(Vector3(x+dx,1.7,8.5),Vector3(.2,3.4,3),"wall")
					g.box(Vector3(x+dx,1.7,15.5),Vector3(.2,3.4,3),"wall")
				else: g.box(Vector3(x+dx,1.7,z),Vector3(.2,3.4,10),"wall")
			for seg in [[-6.5,1.0],[0.0,6.0],[6.5,1.0]]:
				g.box(Vector3(x+seg[0],1.7,side*7),Vector3(seg[1],3.4,.18),"wall")
			for dx in [-4.5,4.5]:
				g.make_door(Vector3(x+dx,0,side*7),side)
				g.box(Vector3(x+dx,3.06,side*7),Vector3(3.3,.68,.2),"wood")
				var title: String = Tuning.NORTH_NAMES[ri] if side<0 else Tuning.SOUTH_NAMES[ri]
				g.label3(title,Vector3(x+dx,2.92,side*6.84),0.0 if side<0 else PI,.005)
			if not (ri==4 and side>0):
				for dx in [-3.8,3.8]: g.make_exterior_window(x,side,dx,ri)
			if ri==3 and side<0: library(x,z)
			elif ri==3: toilets(x,z)
			elif ri==4 and side>0: storage(x,z)
			else:
				for dx in [-3.9,0.0,3.9]:
					for dz in [-1.4,1.3]: g.desk(Vector3(x+dx,0,z+dz))
				g.box(Vector3(x-6.8,2.0,z),Vector3(.08,1.4,4.3),"chalk",false)
				g.label3("放課後\n\n静かにしてください",Vector3(x-6.7,2.0,z),PI/2,.005)
				if ri==4:
					for dx in [-5,0,5]:
						g.box(Vector3(x+dx,1.1,z+3.7),Vector3(1.4,1.9,.18),"wood",false)
						g.box(Vector3(x+dx,1.4,z+3.58),Vector3(1.1,1.1,.03),"paper",false)
			g.room_key_points.append([Vector3(x,1,z)])
	# Landmarks and clutter hug walls; no prop blocks the main corridor lane.
	g.box(Vector3(81,-.15,12),Vector3(4,.3,10),"floor")
	g.box(Vector3(81,3.5,12),Vector3(4,.2,10),"ceiling")
	g.box(Vector3(83,1.7,12),Vector3(.2,3.4,10),"wall")
	g.box(Vector3(81,1.7,17),Vector3(4,3.4,.2),"wall")
	g.box(Vector3(81,1.7,7),Vector3(4,3.4,.2),"wall")
	for x in [-12.0,8.0,32.0,52.0,76.0]:
		for side in [-1,1]:
			var z: float = side*6.65
			g.box(Vector3(x,.32,z),Vector3(2.4,.12,.52),"wood",false)
			for dx in [-1.0,1.0]: g.box(Vector3(x+dx,.15,z),Vector3(.09,.3,.45),"metal",false)
			g.box(Vector3(x+1.9,.42,z),Vector3(.45,.84,.45),"metal",false)
			g.box(Vector3(x,2.0,z),Vector3(2.6,1.1,.04),"wood",false)
			for i in range(5):
				var p = g.box(Vector3(x-.95+i*.45,2.0+sin(i*3.7)*.12,z-side*.04),Vector3(.35,.66,.01),"paper",false)
				p.rotation.z = sin(x+i)*.08
			g.label3("避難経路  ← ENTRANCE",Vector3(x,2.02,z-side*.07),0.0 if side<0 else PI,.0035,Color("7a8075"))
	# Sparse dirt, chipped skirting, hanging papers and leaks break repetition.
	var dirt = StandardMaterial3D.new()
	dirt.albedo_color = Color(.035,.05,.042,.32)
	dirt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(80):
		var x: float = -21+fmod(i*13.739,99)
		var z: float = (-1 if i%2 else 1)*6.82
		var patch = g.box(Vector3(x,.85+fmod(i*.31,1.6),z),Vector3(.16+fmod(i*.37,.8),.7+fmod(i*.79,.8),.012),"dark",false)
		patch.material_override = dirt
		patch.rotation.z = sin(i*4.0)*.06
	make_figures()
	for l in g.lights: night_energy.append(l.light_energy)

func library(x: float,z: float) -> void:
	for dx in [-5.7,5.7]:
		game.box(Vector3(x+dx,1,z),Vector3(1.1,2,5.3),"wood")
		for level in range(4):
			game.box(Vector3(x+dx,level*.46+.25,z),Vector3(1.15,.06,5.4),"metal",false)
			for i in range(14):
				game.box(Vector3(x+dx,level*.46+.48,z-2.4+i*.36),Vector3(.75,.36,.15+fmod(i*.13,.13)),"paper" if i%3 else "red",false)
	for dx in [-2.0,2.0]: game.desk(Vector3(x+dx,0,z))
	game.label3("図書室 / LIBRARY\nFestival records",Vector3(x,2.7,z-4.65),0,.0055)

func toilets(x: float,z: float) -> void:
	for dx in [-4.5,0.0,4.5]:
		game.box(Vector3(x+dx,.6,z+2.6),Vector3(1.0,1.1,1.3),"paper")
		game.box(Vector3(x+dx,1.1,z+3.4),Vector3(1,.9,.35),"paper",false)
		game.box(Vector3(x+dx,.65,z-1.6),Vector3(1.2,.2,.75),"paper")
		game.box(Vector3(x+dx,1.8,z-1.8),Vector3(1.1,.9,.04),"glass",false)
	for dx in [-2.2,2.2]: game.box(Vector3(x+dx,1.15,z+2.4),Vector3(.06,2.3,3.3),"metal")

func storage(x: float,z: float) -> void:
	for dx in [-5.8,5.8]:
		game.box(Vector3(x+dx,1,z+1.5),Vector3(1.1,2,4.3),"metal")
		for h in [.4,1.0,1.6]:
			game.box(Vector3(x+dx,h,z+1.5),Vector3(1.15,.05,4.4),"wood",false)
			for dz in [0,1,2,3]: game.box(Vector3(x+dx,h+.18,z+dz),Vector3(.65,.32,.65),"paper",false)
	for i in range(3):
		var mop = game.box(Vector3(x-2+i*.4,1.0,z+4.0),Vector3(.035,1.9,.035),"wood",false)
		mop.rotation.z = .08
		game.box(Vector3(x-2+i*.4,.12,z+4.0),Vector3(.30,.12,.12),"paper",false)
	game.label3("用具室 / CLEANING\nOld festival records",Vector3(x,2.3,z+4.5),PI,.005)

func oval(parent: Node3D,pos: Vector3,size: Vector3,mat: Material) -> void:
	var m = MeshInstance3D.new()
	var s = SphereMesh.new()
	s.radial_segments = 16
	s.rings = 10
	m.mesh = s
	m.position = pos
	m.scale = size
	m.material_override = mat
	parent.add_child(m)

func make_figures() -> void:
	figures = Node3D.new()
	game.world.add_child(figures)
	for i in range(6):
		if i==1: continue
		var person = preload("res://scripts/classroom_actor.gd").new()
		person.teacher = i==5
		person.position = Vector3(-19.9+(i%3)*3.9+.83,0,-13.4+(i/3)*2.7)
		person.rotation.y = -PI/2
		if i==5:
			person.position = Vector3(-21.5,0,-12)
			person.rotation.y = PI/2
		figures.add_child(person)
	for x in [-20,-12]:
		var light = OmniLight3D.new()
		light.position = Vector3(x,2.8,-12)
		light.light_energy = 2.5
		light.omni_range = 15
		light.light_color = Color("f5e6c5")
		game.world.add_child(light)
		day_lights.append(light)
	set_day(false)

func set_day(on: bool) -> void:
	figures.visible = on
	for light in day_lights: light.visible = on
	var environment: Environment = game.world.get_child(0).environment
	game.materials.window_view.set_shader_parameter("daytime",on)
	for pane in game.get_tree().get_nodes_in_group("exterior_panes"):
		pane.material_override.set_shader_parameter("daytime",on)
	environment.background_color = Color("080f15")
	environment.fog_enabled = true
	environment.ambient_light_energy = .65 if on else .075
	environment.ambient_light_color = Color("bebaaa") if on else Color("667c86")
	for i in range(game.lights.size()):
		if i<night_energy.size(): game.lights[i].light_energy = night_energy[i]

func _process(delta: float) -> void:
	time += delta
	if figures and figures.visible:
		for i in range(figures.get_child_count()): figures.get_child(i).rotation.z = sin(time*.6+i)*.012
