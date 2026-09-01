extends Node
## The settings row and the bar button must drive the SAME setting.
var _fails := 0
func _ready() -> void:
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	var screen := SettingsScreen.new()
	add_child(screen)
	for _i in 20:
		await get_tree().process_frame
	var rows := screen.find_children("*", "Button", true, false)
	var light: Button = null
	for any: Variant in rows:
		var b := any as Button
		for child in b.find_children("*", "Label", true, false):
			if (child as Label).text == tr("SETTINGS_LIGHT"):
				light = b
	ck("ayarlarda isik satiri var", light != null, "")
	if light != null:
		var before := SkyTime.mode()
		light.pressed.emit()
		for _i in 6:
			await get_tree().process_frame
		ck("satir modu degistiriyor", SkyTime.mode() != before,
			"%s -> %s" % [before, SkyTime.mode()])
	for k: String in GameConfig.SKY_MODES:
		ck("deger metni var: %s" % k,
			tr("SKY_VALUE_" + k.to_upper()) != "SKY_VALUE_" + k.to_upper(), k)
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	if _fails > 0:
		push_error("%d AYAR TESTI BASARISIZ" % _fails)
		print("--- %d AYAR TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM AYAR TESTLERI GECTI ---")
	get_tree().quit()
func ck(label: String, passed: bool, detail: String) -> void:
	if passed: return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
