extends CanvasLayer
## Local, silent developer splash. The menu underneath stays disabled until finished.
signal finished
var age := 0.0
var active := false
var game: Node
var overlay: Control
var row: Control
var portrait: TextureRect
var letters: Array[Label] = []
var subtitle: Label
var portrait_size := 86.0

func setup(owner_game: Node) -> void:
	game = owner_game
	layer = 100
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("090b0d")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(row)
	portrait = TextureRect.new()
	portrait.texture = load("res://assets/branding/medissl.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var circle := Shader.new()
	circle.code = "shader_type canvas_item; void fragment(){float d=length(UV-vec2(.5)); vec4 c=texture(TEXTURE,UV); c.a*=1.0-smoothstep(.491,.5,d); COLOR=c*COLOR;}"
	var material := ShaderMaterial.new()
	material.shader = circle
	portrait.material = material
	row.add_child(portrait)
	for character in "Medissl":
		var letter := Label.new()
		letter.text = character
		letter.add_theme_font_override("font", game.horror_font)
		letter.add_theme_color_override("font_color", Color("f6f5f1"))
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(letter)
		letters.append(letter)
	subtitle = Label.new()
	subtitle.text = "GAMES"
	var subtitle_font := FontVariation.new()
	subtitle_font.base_font = game.horror_font
	subtitle_font.spacing_glyph = 5
	subtitle.add_theme_font_override("font", subtitle_font)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color("b7c1be"))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(subtitle)
	active = true
	update_visuals()

func _process(delta: float) -> void:
	if not active: return
	if game.input_focused: age += delta
	update_visuals()
	if age >= 4.15:
		active = false
		for action in InputMap.get_actions(): Input.action_release(action)
		game.player.cancel_movement()
		finished.emit()
		queue_free()

func consume(event: InputEvent) -> void:
	if not active:
		game.get_viewport().set_input_as_handled()
		return
	# Only a released primary pointer skips; keyboard input cannot activate PLAY.
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if released and age >= 2.0 and game.input_focused: age = maxf(age, 3.6)
	game.get_viewport().set_input_as_handled()

func ease_out(value: float) -> float:
	return 1.0 - pow(1.0-clampf(value,0,1),3)

func update_visuals() -> void:
	var viewport_size := overlay.get_viewport_rect().size
	var small := viewport_size.x < 350
	portrait_size = 68.0 if small else 86.0
	var title_size := 30 if small else 36
	var gap := 16.0 if small else 23.0
	var text_x := portrait_size + gap
	var title_width := 0.0
	for letter in letters:
		letter.add_theme_font_size_override("font_size",title_size)
		title_width += game.horror_font.get_string_size(letter.text,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x
	row.position = (viewport_size - Vector2(text_x+title_width,portrait_size))*.5 - Vector2(0,4)
	portrait.size = Vector2.ONE*portrait_size
	portrait.pivot_offset = portrait.size*.5
	var p := 1.0 if game.settings.reduced else ease_out(age/.65)
	portrait.position = Vector2(0,9*(1-p))
	portrait.scale = Vector2.ONE*lerpf(.82,1,p)
	portrait.modulate.a = p
	var x := text_x
	var title_height: float = game.horror_font.get_height(title_size)
	var top := (portrait_size-title_height-11-13)*.5
	for index in letters.size():
		var letter := letters[index]
		var t := clampf((age-.32-index*.055)/.48,0,1)
		if game.settings.reduced: t = 1
		var offset := lerpf(12,-2,ease_out(t/.65)) if t < .65 else lerpf(-2,0,ease_out((t-.65)/.35))
		letter.position = Vector2(x,top+offset)
		letter.modulate.a = clampf(t/.65,0,1)
		letter.scale = Vector2.ONE*(lerpf(.92,1.015,ease_out(t/.65)) if t<.65 else lerpf(1.015,1,ease_out((t-.65)/.35)))
		x += game.horror_font.get_string_size(letter.text,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x
	var s := 1.0 if game.settings.reduced else ease_out((age-.85)/.6)
	subtitle.position = Vector2(text_x+2,top+title_height+11+4*(1-s))
	subtitle.modulate.a = s
	overlay.modulate.a = 1.0-clampf((age-3.6)/.55,0,1)
