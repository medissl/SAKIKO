extends Node
## Low priority self-comments are conditioned, expiring events, never a backlog.
var game: Node
var lines: Dictionary
var speaker: AudioStreamPlayer
var subtitle_panel: PanelContainer
var subtitle: Label
var pending: Array[Dictionary]=[]
var played: Dictionary={}
var attempted: Dictionary={}
var hinted: Dictionary={}
var clock:=0.0
var last_comment:=-100.0
var last_progress:=0.0
var wake_delay:=-1.0
var active:=""
var reference_known:=false
var playback_known:=false
var left_final:=false
var caption_until:=0.0
var quiet_until:=0.0
# Practical, sparse captions only. No spoken files or scare commentary.
const CAPTIONS := ["P01","P02","P04","P08","P12","H01","H02","H03","H04"]

func build(g: Node) -> void:
	game=g
	lines=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/player_lines.json"))
	speaker=AudioStreamPlayer.new()
	speaker.bus="Voice"
	speaker.volume_db=-14
	add_child(speaker)
	speaker.finished.connect(func(): active=""; subtitle_panel.hide())
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
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitle_panel.hide()

func reset() -> void:
	flush()
	played.clear()
	attempted.clear()
	hinted.clear()
	last_comment=-100
	last_progress=clock
	quiet_until=clock
	wake_delay=3
	reference_known=false
	playback_known=false
	left_final=false

func flush() -> void:
	caption_until=0
	pending.clear()
	if speaker: speaker.stop()
	active=""
	if subtitle_panel: subtitle_panel.hide()

func progress() -> void:
	last_progress=clock
	# A newly completed task makes queued hints obsolete.
	pending=pending.filter(func(item): return not str(item.id).begins_with("H") and item.id!="P09")

func request(id: String,lifetime:=12.0,priority:=1) -> void:
	if not id in CAPTIONS or not game.settings.subtitles: return
	if attempted.has(id) or not lines.has(id): return
	if id in ["P03","H01"] and (attempted.has("P03") or attempted.has("H01")): return
	attempted[id]=true
	pending.append({"id":id,"expires":clock+lifetime,"priority":priority})
	if pending.size()>2: pending.remove_at(0)

func has_event(id: String) -> bool:
	if active==id: return true
	for item in pending:
		if item.id==id: return true
	return false

func danger_or_dialogue() -> bool:
	var p: Node=game.progression.story_puzzles
	var encounter: RefCounted=game.progression.encounters_controller
	return game.mode!="playing" or game.ai_state=="chase" or game.progression.cry.playing or p.recording.playing or (encounter.reveal_requested and not encounter.reveal_finished) or (encounter.tape_pending and not encounter.chase_started)

func valid(id: String) -> bool:
	var p: Node=game.progression.story_puzzles
	match id:
		"P03","H01": return not p.containers.staff_cabinet.open and not p.utility_inventory.has("upper")
		"P05": return game.progression.evidence.collected.has("display") and not played.has("P07")
		"P08","H03": return not p.played and p.utility_inventory.has("tape")
		"P09": return not p.containers.av_case.open and p.played and game.progression.evidence.collected.has("program")
		"H02": return reference_known and not p.containers.archive_12.open
		"P10": return p.utility_inventory.has("rehearsal_U08") and (game.progression.evidence.collected.has("maintenance") or game.progression.evidence.collected.has("case_reference"))
		"P12","H04": return game.collected==4 and game.player.position.x>8
	return true

func document_closed(id: String,reverse: bool) -> void:
	match id:
		"sketch": request("P06")
		"display":
			reference_known=reference_known or reverse or game.progression.story_puzzles.utility_inventory.has("compartment")
			request("P07",4)
		"original":
			if game.progression.evidence.collected.has("display"): request("P05")
		"maintenance","case_reference":
			if game.progression.story_puzzles.rehearsal_taken: request("P10")
		"letter":
			if game.keys[3].get_meta("collected",false): request("P11")
	progress()

func utility_collected(id: String) -> void:
	progress()
	if id=="upper": request("P04")
	if id in ["tape","media"] and game.progression.story_puzzles.utility_inventory.has("tape") and game.progression.story_puzzles.utility_inventory.has("media") and not playback_known: request("P08")
	if id=="rehearsal_U08" and valid("P10"): request("P10")

func _process(delta: float) -> void:
	if not game or not game.progression: return
	clock+=delta
	if danger_or_dialogue(): quiet_until=clock+8
	if caption_until>0 and clock>=caption_until:
		caption_until=0
		active=""
	if (speaker.playing or caption_until>clock) and danger_or_dialogue(): flush()
	subtitle_panel.visible=(speaker.playing or caption_until>clock) and game.settings.subtitles
	if game.mode!="playing": return
	if wake_delay>=0:
		wake_delay-=delta
		if wake_delay<0: request("P01",8)
	if game.collected==4 and not left_final and game.player.position.y>3.5 and game.player.position.z<28.5:
		left_final=true
		request("P12")
	pending=pending.filter(func(item): return item.expires>clock and valid(item.id))
	if clock-last_progress>150 and not danger_or_dialogue(): hint()
	if danger_or_dialogue() or clock<quiet_until or speaker.playing or caption_until>clock or clock-last_comment<45: return
	if pending.is_empty(): return
	pending.sort_custom(func(a,b): return a.priority>b.priority)
	var event: Dictionary=pending.pop_front()
	active=event.id
	caption_until=clock+clampf(lines[active].text.length()*.055,3,6)
	played[active]=true
	game.persist_voice_flags()
	last_comment=clock
	subtitle.text=lines[active].text
	subtitle_panel.visible=game.settings.subtitles

func hint() -> void:
	var p: Node=game.progression.story_puzzles
	var phase: int=game.progression.encounters_controller.phase
	if hinted.has(phase): return
	var id: String=""
	if game.collected==4 and game.player.position.x>10 and clock-last_comment>90: id="H04"
	elif game.progression.discovered and not p.containers.staff_cabinet.open and not attempted.has("P03"): id="H01"
	elif reference_known and not p.containers.archive_12.open: id="H02"
	elif p.utility_inventory.has("tape") and not p.played and p.utility_inventory.has("media"): id="H03"
	elif p.played and game.progression.evidence.collected.has("program") and not p.containers.av_case.open: id="P09"
	if not id.is_empty(): hinted[phase]=true; request(id,8,0)

func snapshot() -> Dictionary:
	return {"played":played.duplicate(),"attempted":attempted.duplicate(),"hinted":hinted.duplicate(),"reference":reference_known,"playback":playback_known,"left_final":left_final}

func restore(data: Dictionary) -> void:
	flush()
	played=data.get("played",{}).duplicate()
	attempted=data.get("attempted",{}).duplicate()
	hinted=data.get("hinted",{}).duplicate()
	reference_known=data.get("reference",false)
	playback_known=data.get("playback",false)
	left_final=data.get("left_final",false)
	wake_delay=-1
	last_progress=clock
	last_comment=clock
