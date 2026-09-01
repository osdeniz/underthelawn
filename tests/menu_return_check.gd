extends Node
## G14.9: there is a way back to the main menu, and it works twice.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	var root: Node = load("res://scenes/Root.tscn").instantiate()
	add_child(root)
	await root.dismiss_main_menu()
	for _i in 20:
		await get_tree().process_frame

	ck("hub acildi", root._hub != null and is_instance_valid(root._hub), "")
	var exits: Array = root._hub.find_children("MainMenuButton", "", true, false)
	ck("hubda ana menu dugmesi var", exits.size() >= 1, "%d" % exits.size())
	if exits.is_empty():
		_finish(root)
		return

	# Out to the menu.
	(exits[0] as Button).pressed.emit()
	for _i in 20:
		await get_tree().process_frame
	ck("ana menu geri geldi", _menu_layer(root) != null, "")
	ck("hub arkada kapandi",
		root._hub.get_parent() != null and not root._hub.get_parent().visible, "")

	# And back in again, the same way a player would.
	var menu := _menu_layer(root)
	var found := false
	for any: Variant in menu.find_children("*", "MainMenu", true, false):
		(any as MainMenu).continue_pressed.emit()
		found = true
	ck("menudeki devam calisiyor", found, "")
	for _i in 24:
		await get_tree().process_frame
	ck("hub tekrar acildi",
		root._hub != null and is_instance_valid(root._hub)
		and root._hub.get_parent().visible, "")
	# The round trip has to be repeatable, not a one-way door with one spare.
	var exits2: Array = root._hub.find_children("MainMenuButton", "", true, false)
	ck("cikis hala orada", exits2.size() >= 1, "%d" % exits2.size())
	# And the same trip from inside a level: the pause sheet's own row, which
	# must not need the town as a stop on the way (G14.9).
	# Straight into the level: _on_chapter_chosen stops at the briefing, which
	# waits for a tap this test has no way to give.
	root._pending_variant = "ch01_aldridge"
	root._start_chapter()
	for _i in 40:
		await get_tree().process_frame
	var game: Node = root._game
	ck("bolum acildi", game != null and is_instance_valid(game), "")
	if game != null and is_instance_valid(game):
		get_tree().paused = false
		game.hud._open_pause()
		await get_tree().process_frame
		game.hud.main_menu_requested.emit()
		for _i in 24:
			await get_tree().process_frame
		ck("duraklattan ana menuye cikildi", _menu_layer(root) != null, "")
		ck("bolum kapandi",
			root._game == null or not is_instance_valid(root._game), "")
	get_tree().paused = false
	_finish(root)


func _menu_layer(root: Node) -> CanvasLayer:
	for child in root.get_children():
		var layer := child as CanvasLayer
		if layer != null and layer.layer == 45:
			return layer
	return null


func _finish(root: Node) -> void:
	root.queue_free()
	if _fails > 0:
		push_error("%d MENU DONUS TESTI BASARISIZ" % _fails)
		print("--- %d MENU DONUS TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM MENU DONUS TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
