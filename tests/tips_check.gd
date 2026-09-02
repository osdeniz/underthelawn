extends Node
## G14.23: the first-pickup cards, the sheet that is gone, and the voice hook.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	GameState.set_setting("tips", "money", false)
	GameState.set_setting("tips", "food", false)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 12:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	await get_tree().process_frame

	# --- the money card, once
	game._on_scrap_found(3, 3, 12)
	await get_tree().process_frame
	var tips: Array = game.hud.find_children("ResourceTip", "", true, false)
	ck("ilk parada kart cikiyor", tips.size() == 1, "%d" % tips.size())
	# And it does NOT pause the game — the mistake the first-run sheet made.
	ck("kart oyunu duraklatmiyor", not get_tree().paused, "")
	_close_tip(game.hud)
	await get_tree().process_frame
	game._on_scrap_found(4, 4, 9)
	await get_tree().process_frame
	ck("ikinci parada kart yok",
		game.hud.find_children("ResourceTip", "", true, false).is_empty(), "")

	# --- and the food card is its own card
	game._on_food_found(5, 5, 4)
	await get_tree().process_frame
	ck("ilk gidada kart cikiyor",
		game.hud.find_children("ResourceTip", "", true, false).size() == 1, "")
	_close_tip(game.hud)

	# --- the blocking sheet is gone for good
	ck("yonlendirme sayfasi kaldirildi",
		not game.hud.has_method("show_orientation")
		or game.hud.find_children("OrientationDim", "", true, false).is_empty(),
		"")

	# --- the voice hook exists and is silent until files arrive
	ck("ses araniyor ama yok",
		not AudioDirector.has_voice("DLG_BRIEF_CH01_1"), "")
	AudioDirector.play_voice("DLG_BRIEF_CH01_1")
	AudioDirector.stop_voice()
	ck("eksik ses cokmeye yol acmiyor", true, "")

	game.queue_free()
	GameState.set_setting("tips", "money", false)
	GameState.set_setting("tips", "food", false)
	if _fails > 0:
		push_error("%d IPUCU TESTI BASARISIZ" % _fails)
		print("--- %d IPUCU TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM IPUCU TESTLERI GECTI ---")
	get_tree().quit()


func _close_tip(hud: Node) -> void:
	for any: Variant in hud.find_children("ResourceTip", "", true, false):
		for button: Variant in (any as Node).find_children("*", "Button", true, false):
			(button as Button).pressed.emit()
			return


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
