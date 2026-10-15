extends Node
var game: Node
var entries := {}
var collected: Array[String] = []
var current := ""
var reverse := false
var journal_open := false

func build(g: Node) -> void:
	game = g
	entries = JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/evidence.json"))

func photo(index: int) -> AtlasTexture:
	var image: Texture2D = load("res://assets/story/festival_photos.png")
	var atlas := AtlasTexture.new()
	atlas.atlas = image
	var width := image.get_width()/3.0
	atlas.region = Rect2(index*width+2,0,width-4,image.get_height())
	return atlas

func inspect(id: String) -> void:
	if not entries.has(id): return
	if not collected.has(id): collected.append(id)
	current = id
	reverse = false
	journal_open = false
	show_entry()

func show_entry() -> void:
	game.mode = "document"
	var data: Dictionary = entries[current]
	var stack: VBoxContainer = game.panel_stack(data.title,"JOURNAL  |  %d items" % collected.size())
	stack.custom_minimum_size.x = 760
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760,390)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",18)
	scroll.add_child(content)
	if (data.has("photo") or current=="class_photo") and not reverse:
		var picture := TextureRect.new()
		picture.texture = load("res://assets/story/class_photo.png") if current=="class_photo" else photo(data.photo)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(700,300)
		content.add_child(picture)
	var paper := RichTextLabel.new()
	paper.bbcode_enabled = true
	paper.fit_content = true
	paper.scroll_active = false
	paper.custom_minimum_size.x = 700
	paper.add_theme_font_override("normal_font",game.serif)
	paper.add_theme_font_size_override("normal_font_size",22)
	paper.add_theme_color_override("default_color",Color("d3d0c1"))
	paper.add_theme_constant_override("line_separation",7)
	paper.text = str(data.get("reverse","") if reverse else data.body)
	content.add_child(paper)
	if data.has("reverse"):
		game.button("TURN OVER" if not reverse else "FRONT / TRANSCRIPTION",func(): reverse=not reverse; show_entry(),stack)
	game.button("JOURNAL",show_journal,stack)
	game.button("RETURN",game.resume_game,stack).grab_focus()

func show_journal() -> void:
	game.mode = "document"
	journal_open = true
	var stack: VBoxContainer = game.panel_stack("EVIDENCE","Collected notes and photographs")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680,390)
	stack.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id in collected:
		var evidence_id: String = id
		game.button(entries[id].title,func(): current=evidence_id; reverse=false; journal_open=false; show_entry(),list)
	if collected.is_empty(): game.text_label("No evidence collected yet.",20,list)
	game.button("RETURN",game.resume_game,stack).grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal") and game.mode in ["playing","document"]:
		if game.mode=="document": game.resume_game()
		else: show_journal()
		get_viewport().set_input_as_handled()
	elif game.mode=="document" and event.is_action_pressed("pause"):
		game.resume_game()
		get_viewport().set_input_as_handled()
