extends Node
## G15: the first-run orientation happens exactly once, and never again.
##
## The "once" is the whole point: a player who has already searched a lawn must
## not be interrupted, and one who quits mid-search must not see it twice.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", false)
	ck("temiz kayit ilk oyun sayilir", GameState.is_first_run(), "")

	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	for _i in 6:
		await get_tree().process_frame
	game._begin_search()
	ck("ilk oyun isaretlendi", game._first_run, "")
	ck("geri sayim basladi", game._orientation_due > 0.0,
		"%.1f" % game._orientation_due)

	# The Marshal must speak far earlier than usual on a first run.
	ck("ilk oyunda telsiz erken",
		float(GameConfig.FIRST_RUN_SCENT_AT[0]) < float(GameConfig.SCENT_AT[0]),
		"%.2f vs %.2f" % [GameConfig.FIRST_RUN_SCENT_AT[0], GameConfig.SCENT_AT[0]])

	# Let the countdown run out.
	await get_tree().create_timer(GameConfig.FIRST_RUN_MODAL_AFTER + 0.6).timeout
	var sheet: Array = game.hud.find_children("OrientationDim", "", true, false)
	ck("yonlendirme acildi", sheet.size() == 1, "%d" % sheet.size())
	ck("oyun duraklatildi", get_tree().paused, "")
	ck("kayitta isaretlendi", not GameState.is_first_run(), "")

	# Closing it marks the buried finds and lets play resume.
	_press_close(game.hud)
	await get_tree().process_frame
	ck("kapaninca duraklama kalkti", not get_tree().paused, "")

	game.queue_free()
	await get_tree().process_frame

	# Second search: nothing at all.
	var again: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(again)
	for _i in 6:
		await get_tree().process_frame
	again._begin_search()
	ck("ikinci oyunda ilk-oyun degil", not again._first_run, "")
	ck("ikinci oyunda geri sayim yok", again._orientation_due <= 0.0,
		"%.1f" % again._orientation_due)
	await get_tree().create_timer(GameConfig.FIRST_RUN_MODAL_AFTER + 0.4).timeout
	ck("ikinci oyunda modal yok",
		again.hud.find_children("OrientationDim", "", true, false).is_empty(), "")
	again.queue_free()

	get_tree().paused = false
	# Left SET on purpose: these suites share a settings file, and clearing it
	# here made every later suite stop behind the orientation sheet.
	GameState.set_setting("meta", "orientation_done", true)
	if _fails > 0:
		push_error("%d ILK OYUN TESTI BASARISIZ" % _fails)
		print("--- %d ILK OYUN TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM ILK OYUN TESTLERI GECTI ---")
	get_tree().quit()


func _press_close(hud: Node) -> void:
	for dim in hud.find_children("OrientationDim", "", true, false):
		for button in dim.find_children("*", "Button", true, false):
			(button as Button).pressed.emit()
			return


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
