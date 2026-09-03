extends Node
## G16.4: large text scales the reading surfaces and nothing else; the success
## haptic is the platform pattern, not two equal pulses.
var _fails := 0
func _ready() -> void:
	GameState.set_setting("display", "large_text", false)
	ck("normal: 52 -> 52", GameConfig.fs(52) == 52, str(GameConfig.fs(52)))
	GameState.set_setting("display", "large_text", true)
	ck("buyuk: 52 -> 65", GameConfig.fs(52) == 65, str(GameConfig.fs(52)))
	ck("buyuk: 62 -> 78", GameConfig.fs(62) == 78, str(GameConfig.fs(62)))
	# A dialogue box built now carries the scale.
	var box := DialogueBox.new()
	add_child(box)
	await get_tree().process_frame
	var size := box._text_label.get_theme_font_size("font_size")
	ck("diyalog metni buyuk", size == 65, str(size))
	box.queue_free()
	GameState.set_setting("display", "large_text", false)
	ck("basari haptigi: hafif sonra orta", Haptics.LIGHT_MS < Haptics.SUCCESS_PULSE_MS
		and is_equal_approx(Haptics.SUCCESS_GAP_S, 0.10), "%d/%d/%.2f" % [Haptics.LIGHT_MS, Haptics.SUCCESS_PULSE_MS, Haptics.SUCCESS_GAP_S])
	if _fails > 0:
		push_error("%d ERISILEBILIRLIK TESTI BASARISIZ" % _fails)
		print("--- %d ERISILEBILIRLIK TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM ERISILEBILIRLIK TESTLERI GECTI ---")
	get_tree().quit()
func ck(label: String, passed: bool, detail: String) -> void:
	if passed: return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
