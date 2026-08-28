extends Node
## G13.4: the scent moments fire at the configured percentages, name a region
## rather than the cell, and can be switched off.

var _fails := 0


func _ready() -> void:
	GameConfig.hint_moments = true
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame

	# Mow the lawn a cell at a time and watch when hints arrive.
	var model = game.model
	var total := GameConfig.GRID_COLS * GameConfig.GRID_ROWS
	var mown := 0
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			if not model.is_mowable(col, row) or model.is_cut(col, row):
				continue
			model.mow(col, row, 0)
			mown += 1
			game._check_scent(model.completion_ratio())
	ck("iki ipucu da verildi",
		game._scent_done.size() == GameConfig.SCENT_AT.size(),
		"%d ipucu" % game._scent_done.size())
	ck("ekranda telsiz satiri var",
		not game.hud.find_children("ScentToast", "", true, false).is_empty(), "")
	# Every line the region picker can return must actually be translated.
	for key: String in ["SCENT_OAK", "SCENT_FENCE", "SCENT_BACK", "SCENT_NEAR"]:
		ck("ipucu metni tanimli: %s" % key, tr(key) != key, "ceviri yok")

	# Off means off.
	GameConfig.hint_moments = false
	game._scent_done.clear()
	game._check_scent(0.95)
	ck("kapaliyken ipucu yok", game._scent_done.is_empty(),
		"%d ipucu" % game._scent_done.size())
	GameConfig.hint_moments = true

	game.queue_free()
	if _fails > 0:
		push_error("%d IPUCU TESTI BASARISIZ" % _fails)
		print("--- %d IPUCU TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM IPUCU TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
