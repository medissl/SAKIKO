extends Node
## Sparse silent practical captions. Flow owns objective and the one stalled hint.
var game: Node
var subtitle_panel: PanelContainer
var subtitle: Label
var clock:=0.0
var caption_until:=0.0
var quiet_until:=0.0
var played: Dictionary={}
func build(g: Node) -> void:
	game=g
	subtitle_panel=PanelContainer.new()
	subtitle_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle_panel.offset_left=-400
	subtitle_panel.offset_right=400
	subtitle_panel.offset_top=-182
	subtitle_panel.offset_bottom=-138
	subtitle_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var backing:=StyleBoxFlat.new()
	backing.bg_color=Color(.015,.018,.019,.88)
	backing.content_margin_left=18
	backing.content_margin_right=18
	backing.content_margin_top=8
	backing.content_margin_bottom=8
	subtitle_panel.add_theme_stylebox_override("panel",backing)
	game.gui.add_child(subtitle_panel)
	subtitle=game.text_label("",19,subtitle_panel)
	subtitle.add_theme_font_override("font",game.serif)
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitle_panel.hide()
func say(text: String) -> void:
	if danger_or_dialogue() or not game.settings.subtitles: return
	subtitle.text=text
	caption_until=clock+6
func reset() -> void:
	flush()
	played.clear()
func flush() -> void:
	caption_until=0
	if subtitle_panel: subtitle_panel.hide()
func progress() -> void: flush()
func request(_id: String, _lifetime:=12.0, _priority:=1) -> void: pass
func has_event(_id: String) -> bool: return false
func document_closed(_id: String, _reverse: bool) -> void: pass
func danger_or_dialogue() -> bool:
	var e: RefCounted=game.progression.encounters_controller
	return game.mode!="playing" or game.ai_state in ["chase","investigate","search"] or (e.reveal_requested and not e.reveal_finished)
func _process(delta: float) -> void:
	clock+=delta
	if danger_or_dialogue(): flush(); quiet_until=clock+4
	subtitle_panel.visible=caption_until>clock and game.settings.subtitles and not danger_or_dialogue()
func snapshot() -> Dictionary: return {"played":played.duplicate()}
func restore(data: Dictionary) -> void:
	flush()
	played=data.get("played",{}).duplicate()
