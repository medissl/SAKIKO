extends RichTextEffect
var bbcode := "prose"
var clock := 0.0
var complete := false
var instant := false
var speed := 1.0
var word_times: Array[float] = []
var duration := 0.0

func prepare(text: String) -> void:
	word_times.clear()
	var word := -1
	var space := true
	for i in range(text.length()):
		var whitespace := text[i] in [" ","\n","\t"]
		if not whitespace and space: word += 1
		word_times.append(maxf(0,word)*.13)
		space = whitespace
	duration = maxf(0,word)*.13+.35
	clock = 0
	complete = false

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	if not complete and not instant:
		var index := mini(char_fx.relative_index,word_times.size()-1)
		if index>=0: char_fx.color.a *= smoothstep(word_times[index],word_times[index]+.28,clock*speed)
	return true
