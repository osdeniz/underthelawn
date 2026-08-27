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

	# Let the countdown run out — while keeping the tree running.
	#
	# The countdown lives in Game._process, and the game pauses the WHOLE tree
	# whenever the window loses focus, on purpose (Game._notification: a phone
	# call must not leave the mower driving). A test run does not own the
	# window, so that pause used to land mid-countdown and stop the very thing
	# under test — the sheet never opened and the four assertions after it fell
	# with it. Unpausing each tick keeps the countdown alive; the moment the
	# sheet appears we stop, because the sheet pauses the tree itself and that
	# is the next assertion (G16).
	var sheet: Array = []
	var waited := 0.0
	while waited < GameConfig.FIRST_RUN_MODAL_AFTER + 6.0:
		sheet = game.hud.find_children("OrientationDim", "", true, false)
		if not sheet.is_empty():
			break
		get_tree().paused = false
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	# One frame for show_orientation's own pause to land before it is asserted.
	await get_tree().process_frame
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
		get_tree().paused = false
		await get_tree().process_frame
	again._begin_search()
	ck("ikinci oyunda ilk-oyun degil", not again._first_run, "")
	ck("ikinci oyunda geri sayim yok", again._orientation_due <= 0.0,
		"%.1f" % again._orientation_due)
	# Same guard: the sheet must stay away because this is not a first run, not
	# because a stray pause stopped the clock that would have shown it.
	var second := 0.0
	while second < GameConfig.FIRST_RUN_MODAL_AFTER + 0.4:
		get_tree().paused = false
		await get_tree().create_timer(0.1).timeout
		second += 0.1
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
