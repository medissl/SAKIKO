# Copyright © 2026 medissl. All rights reserved.
# Original material only; see LICENSE.txt and THIRD_PARTY_NOTICES.md.
extends Control
const Reveal = preload("res://scripts/prose_reveal.gd")
var game: Node
var pages: Array = []
var page := 0
var stage := "story"
var reveal: RichTextEffect
var body: RichTextLabel
var scroll: ScrollContainer
var next: Button
var page_number: Label
var layout: MarginContainer
var footer: HBoxContainer
var audio: AudioStreamPlayer
var tone: AudioStreamPlayer
var curtain: ColorRect
var credits: VBoxContainer
var credits_y := 0.0
var silence := 0.0
var elapsed := 0.0
var finished := false
var speed := 1.0
var instant := false
var grain: ColorRect

func _ready() -> void:
	pages = JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/ending.json"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("060606")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	grain = ColorRect.new()
	grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform bool reduced=false; void fragment(){float n=fract(sin(dot(FRAGCOORD.xy+floor(TIME*9.0),vec2(12.9898,78.233)))*43758.5453); COLOR=vec4(vec3(.7,.66,.6),(n*.018)*(reduced?.15:1.0));}"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("reduced",game.settings.reduced)
	grain.material = mat
	add_child(grain)
	layout = MarginContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",22)
	layout.add_child(column)
	page_number = Label.new()
	page_number.add_theme_color_override("font_color",Color("8b4347"))
	page_number.add_theme_font_override("font",game.horror_font)
	page_number.add_theme_font_size_override("font_size",18)
	column.add_child(page_number)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_override("normal_font",game.serif)
	body.add_theme_font_size_override("normal_font_size",23)
	body.add_theme_color_override("default_color",Color("d3cfc3"))
	body.add_theme_constant_override("line_separation",9)
	reveal = Reveal.new()
	body.install_effect(reveal)
	scroll.add_child(body)
	body.gui_input.connect(page_click)
	scroll.gui_input.connect(page_click)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation",20)
	column.add_child(footer)
	var setting := OptionButton.new()
	setting.add_theme_font_override("font",game.horror_font)
	setting.add_theme_font_size_override("font_size",17)
	for label in ["Text: normal","Text: slow","Text: fast","Text: instant"]: setting.add_item(label)
	setting.item_selected.connect(func(index):
		speed = [1.0,.65,1.7,1.0][index]
		instant = index==3
		reveal.speed = speed
		reveal.instant = instant)
	footer.add_child(setting)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(gap)
	next = Button.new()
	next.add_theme_font_override("font",game.horror_font)
	next.add_theme_font_size_override("font_size",23)
	next.text = "Reveal"
	next.custom_minimum_size = Vector2(150,42)
	next.pressed.connect(advance)
	footer.add_child(next)
	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(curtain)
	curtain.modulate.a = 1
	create_tween().tween_property(curtain,"modulate:a",0,1.2)
	audio = AudioStreamPlayer.new()
	audio.bus = "Ambience"
	audio.stream = load("res://assets/audio/ending_morning.wav")
	audio.volume_db = -33
	add_child(audio)
	audio.play()
	tone = AudioStreamPlayer.new()
	tone.bus = "Ambience"
	tone.stream = game.sounds.hum
	tone.volume_db = -50
	add_child(tone)
	tone.finished.connect(func(): if not finished and stage=="story": tone.play())
	tone.play()
	resized.connect(responsive_layout)
	responsive_layout()
	show_page()

func responsive_layout() -> void:
	if not layout: return
	var margin := int(clampf(size.x*.13,28,190))
	for side in ["left","right"]: layout.add_theme_constant_override("margin_"+side,margin)
	layout.add_theme_constant_override("margin_top",48 if size.y>600 else 22)
	layout.add_theme_constant_override("margin_bottom",32)
	body.add_theme_font_size_override("normal_font_size",23 if size.x>=1100 else 20)

func show_page() -> void:
	var text: String = pages[page].body
	reveal.prepare(text)
	reveal.speed = speed
	reveal.instant = instant
	body.text = "[prose]"+text+"[/prose]"
	scroll.scroll_vertical = 0
	page_number.text = "%02d / %02d" % [page+1,pages.size()]
	next.text = "Reveal"
	next.disabled = false
	silence = 0
	next.grab_focus()

func page_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		advance()
		get_viewport().set_input_as_handled()

func page_complete() -> bool:
	return reveal.complete or instant or reveal.clock*speed>=reveal.duration

func advance() -> void:
	if finished or stage!="story": return
	if not page_complete():
		reveal.complete = true
		return
	if page==pages.size()-1:
		if silence<1.2: return
		start_credits()
	else:
		page += 1
		show_page()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if stage=="story" and event.physical_keycode in [KEY_SPACE,KEY_ENTER,KEY_E]:
			advance()
			get_viewport().set_input_as_handled()
		elif stage=="credits" and event.physical_keycode==KEY_ESCAPE:
			finish()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if stage=="credits" and event is InputEventKey and event.physical_keycode==KEY_SPACE:
		get_viewport().set_input_as_handled()

func start_credits() -> void:
	if stage!="story": return
	stage = "transition"
	var fade := create_tween()
	fade.tween_property(curtain,"modulate:a",1,.7)
	fade.tween_callback(build_credits)
	fade.tween_property(curtain,"modulate:a",0,1.0)

func credit_label(text: String,heading: bool) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",game.horror_font if heading else game.serif)
	label.add_theme_font_size_override("font_size",24 if heading else 29)
	label.add_theme_color_override("font_color",Color("8a3940") if heading else Color("d4d0c5"))
	credits.add_child(label)

func credit_space(amount: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = amount
	credits.add_child(gap)

func build_credits() -> void:
	layout.hide()
	stage = "credits"
	game.mode = "credits"
	credits = VBoxContainer.new()
	credits.add_theme_constant_override("separation",12)
	credits.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(credits)
	for category in ["A GAME BY","GAME DIRECTION","GAME DESIGN","PROGRAMMING","LEVEL DESIGN","ENVIRONMENT ART","CHARACTER DESIGN","CREATURE DESIGN","ANIMATION","LIGHTING","UI DESIGN","STORY AND WRITING","PUZZLE DESIGN","SOUND DESIGN","MUSIC DIRECTION","QUALITY ASSURANCE","THE PERSON WHO PUT THAT THING IN THE HALLWAY"]:
		credit_label(category,true)
		credit_label("medissl",false)
		credit_space(46)
	credit_label("THIRD-PARTY ACKNOWLEDGMENTS",true)
	credit_space(24)
	for pair in [["CHARACTER SOURCE MODELS","Innerscene / MakeHuman, CC0"],["SCHOOL DESK AND CHAIR","Ethan Place / Poly Haven, CC0"],["PBR SURFACES","Poly Haven contributors, CC0"],["RECORDED GHOST VOICE","AuraVoice / Nocturnal_Vanguard, CC0"],["MALE PAIN VOCAL","HaelDB, CC0"],["MALE BREATHING","Nox_Sound, CC0"],["MENU MUSIC","brandon75689, CC0"],["UNUSED RIGGED SOURCE MODELS","Quaternius, CC0"],["ENGINE","Godot Engine contributors, MIT"]]:
		credit_label(pair[0],true)
		credit_label(pair[1],false)
		credit_space(34)
	credit_label("SOURCE AND LICENSE NOTICES",true)
	credit_label("Copyright © 2026 medissl. All rights reserved.",true)
	credit_label("Original material: LICENSE.txt",true)
	credit_label("Third parties: THIRD_PARTY_NOTICES.md",true)
	credit_label("Godot Engine: https://godotengine.org/license/",true)
	credit_space(100)
	credit_label("THANK YOU FOR PLAYING",true)
	credit_label("SAKIKO",false)
	credit_space(100)
	credits_y = size.y+50
	credits.position.y = credits_y
	var footer_bg := ColorRect.new()
	footer_bg.color = Color.BLACK
	footer_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer_bg.offset_top = -54
	footer_bg.offset_bottom = 0
	footer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer_bg)
	var controls := HBoxContainer.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.position.y -= 48
	controls.position.x = 32
	add_child(controls)
	var hint := Label.new()
	hint.add_theme_font_override("font",game.horror_font)
	hint.add_theme_font_size_override("font_size",17)
	hint.text = "Hold SPACE / SHIFT to accelerate"
	controls.add_child(hint)
	var skip := Button.new()
	skip.add_theme_font_override("font",game.horror_font)
	skip.add_theme_font_size_override("font_size",18)
	skip.text = "Skip credits  /  ESC"
	skip.pressed.connect(finish)
	controls.add_child(skip)
	skip.grab_focus()
	move_child(curtain,get_child_count()-1)
	audio.stop()
	tone.stop()
	audio.stream = load("res://assets/audio/menu_theme.ogg")
	audio.volume_db = -32
	audio.play()

func finish() -> void:
	if finished: return
	finished = true
	stage = "returning"
	var fade := create_tween()
	fade.tween_property(curtain,"modulate:a",1,.8)
	fade.parallel().tween_property(audio,"volume_db",-65,.8)
	fade.tween_callback(func():
		audio.stop()
		tone.stop()
		game.ending = null
		game.show_main_menu()
		queue_free())

func _process(delta: float) -> void:
	elapsed += delta
	if stage=="story":
		reveal.clock += delta
		var is_last := page==pages.size()-1
		var near_end: bool = is_last and reveal.clock*speed>reveal.duration-1.5
		if page_complete():
			next.text = "Continue" if is_last else "Next"
			if is_last:
				audio.stop()
				tone.stop()
				silence += delta
			next.disabled = is_last and silence<1.2
		var quiet := is_last and (near_end or page_complete())
		audio.volume_db = move_toward(audio.volume_db,-70 if quiet else -48,delta*2)
		tone.volume_db = move_toward(tone.volume_db,-70 if quiet else -39-page*5,delta*8)
	elif stage=="credits":
		var fast := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SHIFT)
		credits_y -= delta*42*(5 if fast else 1)
		credits.position.y = credits_y
		if credits_y+credits.size.y< -40: finish()
