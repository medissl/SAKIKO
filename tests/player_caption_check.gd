extends RefCounted
var failures:=0
func check(ok: bool,description: String) -> void:
	print("CAPTION PASS " if ok else "CAPTION FAIL ",description)
	if not ok: failures+=1

func run(g: Node) -> void:
	g.start_game();g.input_focused=true
	var v: Node=g.player_voice
	v.wake_delay=-1
	v.flush()
	v.quiet_until=0
	v.last_comment=-100
	v.request("P01")
	v._process(.01)
	check(v.active=="P01" and v.subtitle_panel.visible and v.caption_until>v.clock and not v.speaker.playing,"practical thought displays silently at the bottom")
	if DisplayServer.get_name()!="headless":
		await g.get_tree().create_timer(.2).timeout
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png("C:/Users/media/OneDrive/Documents/sakiko/tests/artifacts/player_caption.png")
	check(v.subtitle_panel.offset_bottom<g.prompt.offset_top,"caption stays above the interaction prompt")
	v.request("P01")
	check(v.pending.is_empty(),"thought never repeats after another request")
	v.request("P07");v.request("P11")
	check(v.pending.is_empty(),"interpretive scare reactions are excluded")
	g.ai_state="chase";v._process(.01)
	check(v.active.is_empty() and not v.subtitle_panel.visible and v.pending.is_empty(),"danger immediately clears captions")
	g.ai_state="roam"
	v.request("P02");v.last_comment=-100;v._process(.1)
	check(v.active.is_empty(),"quiet breathing room after a threat")
	v.clock=v.quiet_until+.1;v._process(.01)
	check(v.active=="P02" and not v.speaker.playing,"practical caption resumes only after the quiet interval")
	g.progression.evidence.inspect("program");v._process(.01)
	check(not v.subtitle_panel.visible and v.caption_until==0,"inspection never carries a duplicate bottom thought")
	g.progression.evidence.close()
	v.flush();v.pending.clear();g.settings.subtitles=false
	v.request("P04")
	check(v.pending.is_empty(),"subtitles setting suppresses optional thoughts")
	g.settings.subtitles=true
	v.attempted.clear();v.hinted.clear();v.last_progress=v.clock-151;v.last_comment=-100;v.quiet_until=0
	g.progression.discovered=true
	v.hint()
	check(v.pending.size()==1 and v.pending[0].id=="H01","stuck hint requires a relevant unfinished step")
	v.hint()
	check(v.pending.size()==1,"one contextual hint per phase")
	g.show_main_menu();v._process(.01)
	check(not v.subtitle_panel.visible and not v.speaker.playing,"returning to menu clears player text and keeps VA silent")
	print("CAPTION RESULT ",failures," failures")
	if failures: g.get_tree().quit(1)
	else: await g.quit_game()
