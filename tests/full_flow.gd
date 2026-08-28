extends Node
## G13.8: the whole run, once, in one process.
##
## Boot -> chapter 1 -> hub -> buy a restoration -> map -> chapter 8 -> finale.
## Its job is not to check any single screen (the other suites do that) but to
## prove the seams still hold with the legacy hub removed: nothing on this path
## may reach for a mode, a layer or a picture that no longer exists.

var _fails := 0


func _ready() -> void:
	ChapterProgress.reset()
	RestoreBoard.reset()
	GameState.set_setting("economy", "scrap", 120000)

	# --- boot: the hub builds, with the diorama as its only backdrop.
	var hub := HubScreen.new()
	add_child(hub)
	await get_tree().process_frame
	ck("hub kuruldu", hub.get_child_count() > 0, "")
	var towns := hub.find_children("*", "TownDiorama", true, false)
	ck("diyorama arkaplani var", towns.size() == 1, "%d" % towns.size())
	hub.set_diorama_active(true)
	await get_tree().process_frame

	# --- chapter 1 through the map, which is the only door now.
	var started: Array = []
	hub.chapter_chosen.connect(func(id: String) -> void: started.append(id))
	var chapters: Array = Story.list("chapters")
	var first := str((chapters[0] as Dictionary).get("variant_id", ""))
	hub.open_map_at(first)
	for _i in 6:
		await get_tree().process_frame
	ck("harita ilk mekana odaklandi",
		hub.find_children("PlacePanel", "", true, false).size() == 1, "")
	_press_start(hub)
	await get_tree().process_frame
	ck("harita bolumu baslatti", started.has(first), str(started))

	# --- play it: the real scene, mown to completion.
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = first
	add_child(game)
	for _i in 6:
		await get_tree().process_frame
	ck("bolum sahnesi kuruldu", game.model != null, "")
	_mow_everything(game)
	ck("bahce bitti", game.model.completion_ratio() > 0.99,
		"%.2f" % game.model.completion_ratio())
	ChapterProgress.record(first, 2, 2)
	game.queue_free()
	await get_tree().process_frame

	# --- back in the hub: buy a restoration, which used to paint a layer.
	for opener: String in ["swing", "lantern", "greenhouse"]:
		RestoreBoard.buy(opener)
	hub._on_tile("restore", false)
	await get_tree().process_frame
	hub._on_project("station", false, null)
	await get_tree().create_timer(6.0).timeout
	ck("karakol yapildi", RestoreBoard.is_built("station"), "")
	var blockers := 0
	for child in hub.get_children():
		var c := child as Control
		if c is Button and c != null and c.size.x >= hub.size.x - 1.0:
			blockers += 1
	ck("satin alma sonrasi ekran serbest", blockers == 0, "%d buton" % blockers)

	# --- finish the case and check the finale state.
	for chapter_any: Variant in chapters:
		ChapterProgress.record(str((chapter_any as Dictionary).get("variant_id", "")), 2, 2)
	hub.refresh()
	await get_tree().process_frame
	ck("vaka tamamlandi",
		ChapterProgress.done_count() == ChapterProgress.count(),
		"%d/%d" % [ChapterProgress.done_count(), ChapterProgress.count()])
	hub._show_board_tab(true)
	await get_tree().process_frame
	hub._show_board_tab(false)
	await get_tree().process_frame
	ck("pano ve harita arasi gecis calisiyor", true, "")

	hub.queue_free()
	ChapterProgress.reset()
	RestoreBoard.reset()
	if _fails > 0:
		push_error("%d AKIS TESTI BASARISIZ" % _fails)
		print("--- %d TAM AKIS TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TAM AKIS TESTI GECTI ---")
	get_tree().quit()


## Finds the map panel's primary button and presses it.
func _press_start(hub: Node) -> void:
	for panel in hub.find_children("PlacePanel", "", true, false):
		for button in panel.find_children("*", "Button", true, false):
			var b := button as Button
			if b != null and not b.disabled and b.text != "×":
				b.pressed.emit()
				return


func _mow_everything(game: Node) -> void:
	var model = game.model
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			if model.is_mowable(col, row) and not model.is_cut(col, row):
				model.mow(col, row, 0)


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
