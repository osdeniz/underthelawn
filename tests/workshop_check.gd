extends Node
## The workshop is a shop now, not four cards. These are its rules.
##
## Written after a screenshot of the "locked, cannot afford" state turned out
## to show an unlocked machine with plenty of scrap: the save under the test
## already had everything bought, so the picture proved nothing. Rules, not
## pictures, and set the state explicitly first.

var _fails := 0
var _scrap_before := 0


func _ready() -> void:
	_scrap_before = GameState.scrap_total()
	GameState.set_setting("meta", "orientation_done", true)
	Garage.reset()
	GameState.set_setting("economy", "scrap", 10)

	var page := WorkshopPage.new()
	add_child(page)
	for _i in 12:
		await get_tree().process_frame

	# --- the picker offers every machine, exactly once
	var chips := page.find_children("Chip_*", "Button", true, false)
	ck("her makine icin bir cip", chips.size() == GameConfig.MOWER_TYPES.size(),
		"%d cip / %d makine" % [chips.size(), GameConfig.MOWER_TYPES.size()])

	# --- a locked machine you cannot afford
	page._select(3)
	for _i in 6:
		await get_tree().process_frame
	ck("kilitli makine kilitli yaziyor", _has_text(page, tr("WS_LOCKED")), "")
	ck("parasi yetmeyene gerekce yazili",
		_has_text(page, tr("WS_NOT_ENOUGH")), "")
	var buy := _find_button(page, tr("WS_UNLOCK").format(
		{"cost": Garage.unlock_cost(3)}))
	ck("kilitli makinenin ac butonu var", buy != null, "")

	# --- tapping it when broke must NOT open the confirm sheet
	if buy != null:
		page._ask(3, true, buy)
		ck("parasi yetmezken onay acilmaz", not page._confirm.visible, "")

	# --- with money, the same button becomes the primary action and buys
	GameState.set_setting("economy", "scrap", 99999)
	page.refresh()
	for _i in 6:
		await get_tree().process_frame
	ck("parasi yetince gerekce kalkar",
		not _has_text(page, tr("WS_NOT_ENOUGH")), "")
	var cost := Garage.unlock_cost(3)
	var before := GameState.scrap_total()
	page._pending_index = 3
	page._pending_is_unlock = true
	page._on_buy()
	for _i in 6:
		await get_tree().process_frame
	ck("satin alma acar", Garage.is_unlocked(3), "")
	ck("ucret dusuldu", GameState.scrap_total() == before - cost,
		"%d -> %d (bedel %d)" % [before, GameState.scrap_total(), cost])
	ck("acilan makine sende yaziyor", _has_text(page, tr("WS_ACTIVE")), "")

	# --- the hero follows the picker
	page._select(0)
	for _i in 6:
		await get_tree().process_frame
	ck("kahraman panel secilen makineyi gosterir",
		_has_text(page, tr(str(GameConfig.MOWER_TYPES[0]["label"]))), "")

	# --- and it never draws over the hub's own BACK button
	var chips_box: Control = page._chips
	ck("cipler geri butonunun ustunde kalir",
		chips_box.offset_bottom <= -160.0,
		"alt kenar %.0f" % chips_box.offset_bottom)

	page.queue_free()
	Garage.reset()
	GameState.set_setting("economy", "scrap", _scrap_before)
	if _fails > 0:
		push_error("%d ATOLYE TESTI BASARISIZ" % _fails)
		print("--- %d ATOLYE TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM ATOLYE TESTLERI GECTI ---")
	get_tree().quit()


func _has_text(root: Node, needle: String) -> bool:
	for node in root.find_children("*", "Label", true, false):
		if (node as Label).text.find(needle) >= 0:
			return true
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text.find(needle) >= 0:
			return true
	return false


func _find_button(root: Node, needle: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text.find(needle) >= 0:
			return node as Button
	return null


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
