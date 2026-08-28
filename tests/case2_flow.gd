extends Node
## G13: Case 02 end to end — it opens when it should, it is playable, and it
## ends with ITS OWN ending.
##
## Case2Check proves the data is complete. This proves the flow works: that the
## gate actually gates, that ten chapters reach the board once it lifts, that a
## Case 02 chapter runs through the real game scene, and — the one that broke
## silently when the board learned about two cases — that finishing the cellar
## still closes Case 01 while finishing the road home closes Case 02.

var _fails := 0
var _root: Node


func settle(seconds: float) -> void:
	get_tree().paused = false
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	GameState.set_setting("story", "intro_seen", true)
	ChapterProgress.reset()
	RestoreBoard.reset()
	GameState.set_setting("story", "case01_closed", false)
	GameState.set_setting("story", "case02_closed", false)

	await _check_gate()
	await _check_board()
	await _check_chapter_runs()
	_check_endings()
	await _check_map()
	await _check_warm_up_leaves_no_trace()
	await _check_the_door()
	_check_every_chapter_has_a_pin()
	await _check_panel_clears_back()
	await _check_warm_up_survives_a_road_chapter()
	await _check_board_is_built_late()
	await _check_every_way_home_unparks_the_town()
	await _check_ending_cards_dismiss("_show_convoy")
	await _check_ending_cards_dismiss("_show_reunion")

	if _fails > 0:
		push_error("%d VAKA 02 AKIS TESTI BASARISIZ" % _fails)
		print("--- %d VAKA 02 AKIS TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM VAKA 02 AKIS TESTLERI GECTI ---")
	get_tree().quit()


## Two conditions, and BOTH are required: the case is Ellie's closing line made
## into a rule, and half of it is not the rule.
func _check_gate() -> void:
	ck("kapali: vaka 01 acik, kasaba hazir degil",
		not ChapterProgress.case_two_open(), "")
	# The flag alone must not open it: a save that says the ending was seen but
	# has no finished chapters behind it used to show Case 02 over a 0/8 board.
	GameState.set_setting("story", "case01_closed", true)
	ck("bayrak tek basina yetmiyor",
		not ChapterProgress.case_one_finished(), "")
	ck("kapali: bolumler bitmeden vaka 02 acilmaz",
		not ChapterProgress.case_two_open(), "")
	for chapter: Dictionary in Story.list("chapters"):
		ChapterProgress.record(str(chapter.get("variant_id", "")), 2, 2)
	ck("bolumler bitince vaka 01 bitmis sayiliyor",
		ChapterProgress.case_one_finished(), "")
	for project in ["lantern", "swing"]:
		GameState.set_setting("restore", project, true)
	ck("kapali: iki proje yetmez", not ChapterProgress.case_two_open(),
		"%d proje" % RestoreBoard.built_count())
	GameState.set_setting("restore", "greenhouse", true)
	ck("acik: uc proje ve kapali vaka", ChapterProgress.case_two_open(),
		"%d proje" % RestoreBoard.built_count())
	await settle(0.1)


func _check_board() -> void:
	# Its own precondition: the gate check above proves the rule by FINISHING
	# Case 01, and this one is about the board while Case 01 is still open.
	for chapter: Dictionary in Story.list("chapters"):
		GameState.set_setting("progress",
			str(chapter.get("variant_id", "")) + "_done", false)
	var all := ChapterProgress.chapters()
	ck("vaka 01 acikken pano sadece vaka 01", all.size() == 8, str(all.size()))
	ck("aktif vaka ikinci",
		ChapterProgress.active_case_is_two() == false,
		"vaka 01 hala bitmemis")
	for chapter: Dictionary in Story.list("chapters"):
		ChapterProgress.record(str(chapter.get("variant_id", "")), 2, 2)
	ck("vaka 01 bitince pano iki vakayi tasiyor",
		ChapterProgress.chapters().size() == 18,
		str(ChapterProgress.chapters().size()))
	ck("vaka 01 bitince aktif vaka ikinci",
		ChapterProgress.active_case_is_two(), "")
	ck("sonraki bolum vaka 02'nin ilki",
		ChapterProgress.current_variant_id() == "ch09_radio_room",
		ChapterProgress.current_variant_id())
	await settle(0.1)


## A Case 02 chapter has to build and run in the real game scene — its plant
## profile, its landmark and its grid all come from data the scene has never
## seen before.
func _check_chapter_runs() -> void:
	for vid in ["ch13_roadside_camp", "ch18_long_road_home"]:
		var game: Node = load("res://scenes/Main.tscn").instantiate()
		game.set("variant_id", vid)
		game.set("autostart_search", false)
		add_child(game)
		await settle(0.6)
		var variant: LevelVariant = game.get("variant")
		ck("bolum kuruldu: %s" % vid, variant != null and variant.id == vid, vid)
		var model = game.get("model")
		ck("izgara veriden geldi: %s" % vid,
			model != null and GameConfig.CELL_COUNT
				== GameConfig.GRID_COLS * GameConfig.GRID_ROWS,
			"%dx%d" % [GameConfig.GRID_COLS, GameConfig.GRID_ROWS])
		var tufts := game.get_node_or_null("Lawn/TuftField")
		ck("bitki alani var: %s" % vid, tufts != null and tufts.get_child_count() > 0,
			str(tufts.get_child_count() if tufts != null else -1))
		if variant != null and variant.landmark_id != "":
			var built := game.get_node_or_null(
				"Neighborhood/Landmark_" + variant.landmark_id)
			ck("landmark kuruldu: %s" % variant.landmark_id, built != null,
				variant.landmark_id)
		game.queue_free()
		await settle(0.4)


## The one that broke quietly. The board carries both cases now, so "last
## chapter" has to mean last of ITS case: the cellar still ends Case 01, and the
## road home ends Case 02.
func _check_endings() -> void:
	var root := RootFlow.new()
	ck("bodrum vaka 01'in sonu",
		root._is_last_chapter("ch08_cellar"), "")
	ck("donus yolu vaka 02'nin sonu",
		root._is_last_chapter("ch18_long_road_home"), "")
	ck("ara bolum son degil",
		not root._is_last_chapter("ch14_listening_post"), "")
	ck("bodrum vaka 01'e ait", not root._in_case_two("ch08_cellar"), "")
	ck("donus yolu vaka 02'ye ait",
		root._in_case_two("ch18_long_road_home"), "")
	root.free()


## The world map has to be able to START a Case 02 chapter, show its NAME, and
## not put its stops on top of each other. All three were broken at once, and
## none of them raised anything.
func _check_map() -> void:
	var map := TownMap.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map)
	await settle(1.2)
	map.show_layer(0, false)
	await settle(0.8)

	# The panel must name the place, not print the variant id at the player.
	ck("harita bolum adini biliyor",
		map._place_name("ch12_river_crossing") == "CH_12_NAME",
		map._place_name("ch12_river_crossing"))

	# Every Case 02 chapter must be reachable. The order came from the eight
	# TOWN places, so no east-road stop was ever "next" and the whole case was
	# locked out of the map.
	var order := map._case_order("ch12_river_crossing")
	ck("harita sirasi vaka 02'yi taniyor", order.has("ch18_long_road_home"),
		str(order.size()))
	ck("ilk durak siradaki",
		map._next_place(order) == "ch09_radio_room", map._next_place(order))

	# Stops must not overlap, or a tap lands on the wrong chapter.
	var world := map.get_node_or_null("WorldLayer") as Control
	var road := world.get_node_or_null("EastRoad") as Control
	ck("dogu yolu katmani tiklamayi gecirir",
		road != null and road.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		str(road.mouse_filter) if road != null else "-")
	var stops: Array[Rect2] = []
	for child in road.get_children():
		var b := child as Button
		if b != null:
			stops.append(Rect2(b.position, b.custom_minimum_size))
	ck("alti durak var", stops.size() == 6, str(stops.size()))
	var clashes := 0
	for i in stops.size():
		for j in range(i + 1, stops.size()):
			if stops[i].intersection(stops[j]).get_area() > 0.0:
				clashes += 1
	ck("duraklar ust uste binmiyor", clashes == 0, "%d cakisma" % clashes)
	map.queue_free()
	await settle(0.3)


## A variant is GLOBAL state. Anything that applies one temporarily has to put
## the world back, or the next thing to grow grass grows the wrong grass — which
## is exactly what turned the hub's diorama blue on first launch.
func _check_warm_up_leaves_no_trace() -> void:
	var before := LevelVariant.snapshot()
	LevelVariant.of("ch12_river_crossing").apply()
	ck("uygula gercekten degistiriyor",
		GameConfig.active_plant_profile == "REED",
		GameConfig.active_plant_profile)
	LevelVariant.restore(before)
	ck("geri alma paleti kurtariyor",
		GameConfig.active_grass_palette == str(before["palette"]),
		GameConfig.active_grass_palette)
	ck("geri alma bitkiyi kurtariyor",
		GameConfig.active_plant_profile == str(before["plant"]),
		GameConfig.active_plant_profile)
	ck("geri alma izgarayi kurtariyor",
		GameConfig.GRID_COLS == int(before["cols"])
			and GameConfig.GRID_ROWS == int(before["rows"]),
		"%dx%d" % [GameConfig.GRID_COLS, GameConfig.GRID_ROWS])


## THE DOOR. Closing Case 01 has to leave the player somewhere they can SEE
## Case 02, whether or not the town is ready yet — the ending card used to
## announce "CASE 02 UNLOCKED" and then the case appeared nowhere at all,
## because it also waits on three restorations and nothing said so.
func _check_the_door() -> void:
	# Locked: the hub still shows the case, as a counter rather than a wall.
	GameState.set_setting("story", "case01_closed", true)
	RestoreBoard.reset()
	var hub := HubScreen.new()
	add_child(hub)
	await settle(1.0)
	var locked := hub.find_children("CaseTwoTile", "", true, false)
	ck("kilitliyken vaka 02 karti var", locked.size() == 1, str(locked.size()))
	if locked.size() == 1:
		var text := str((locked[0] as Button).text)
		ck("kilitli kart sayaci gosteriyor", text.contains("0/3"), text)
		ck("kilitli kart acildi demiyor",
			not text.contains(tr("CASE_02_UNLOCKED")), text)
	hub.queue_free()
	await settle(0.4)

	# Open: the same card, now a way in.
	for project in ["lantern", "swing", "greenhouse"]:
		GameState.set_setting("restore", project, true)
	var hub2 := HubScreen.new()
	add_child(hub2)
	await settle(1.0)
	var open := hub2.find_children("CaseTwoTile", "", true, false)
	ck("acikken vaka 02 karti var", open.size() == 1, str(open.size()))
	hub2.queue_free()
	await settle(0.4)

	# And the map takes an east-road chapter to the map it is actually ON.
	var map := TownMap.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map)
	await settle(1.2)
	map.focus_place("ch02_neighbor")
	await settle(0.8)
	ck("vaka 01 yeri kasaba katmaninda", map._layer == 1, str(map._layer))
	map.focus_place("ch12_river_crossing")
	await settle(0.8)
	ck("dogu yolu duragi dunya katmaninda", map._layer == 0, str(map._layer))
	var panels := 0
	for child in map.get_children():
		if child is PanelContainer:
			panels += 1
	ck("durak paneli acildi", panels >= 1, str(panels))
	map.queue_free()
	await settle(0.3)


## Every Case 02 chapter has to be somewhere the player can tap. Four of them
## were nowhere: Act 1 was specified as pins on the TOWN sheet and never given
## any, and B18 was left off the east road — so the road's stops reported
## "finish the earlier places" about places that did not exist on any map, and
## the case could not be started at all (G13).
func _check_every_chapter_has_a_pin() -> void:
	for chapter: Dictionary in Story.list("case_02.chapters"):
		var vid := str(chapter.get("variant_id", ""))
		var on_town: bool = GameConfig.MAP_PLACES.has(vid)
		var on_road := false
		for pin: Dictionary in Story.list("east_road.pins"):
			if str(pin.get("chapter", "")) == vid:
				on_road = true
		ck("haritada yeri var: %s" % vid, on_town or on_road, vid)
		ck("tek bir haritada: %s" % vid, not (on_town and on_road), vid)


## The place panel and the hub's BACK button are both anchored to the bottom
## edge, and the panel used to run right through the button — the start button
## and the word BACK drew on top of each other.
func _check_panel_clears_back() -> void:
	var map := TownMap.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.size = Vector2(1170, 2532)
	add_child(map)
	await settle(1.2)
	map.focus_place("ch09_radio_room")
	await settle(1.0)
	var panel: Control = null
	for child in map.get_children():
		if child is PanelContainer:
			panel = child
	ck("yer paneli acildi", panel != null, "")
	if panel != null:
		# The button's band is the bottom 160..60 px of the screen.
		var back_top := map.size.y - 160.0
		var panel_bottom := panel.position.y + panel.size.y
		ck("panel geri dugmesine girmiyor", panel_bottom <= back_top,
			"panel %.0f > dugme %.0f" % [panel_bottom, back_top])
	map.queue_free()
	await settle(0.3)


## The launch crash. current_variant_id() returns the first UNFINISHED chapter,
## so a player who has nearly finished the game gets the road home warmed — and
## the road is 9x34 where every other yard is wider than it is short. The
## warm-up used to restore the grid while the throwaway scene was still alive
## and still mowing, so a model built for 306 cells was indexed against a
## 384-cell grid and read off the end of its own array.
func _check_warm_up_survives_a_road_chapter() -> void:
	for chapter: Dictionary in Story.list("chapters") + Story.list("case_02.chapters"):
		var vid := str(chapter.get("variant_id", ""))
		if vid != "ch18_long_road_home":
			ChapterProgress.record(vid, 2, 2)
	ck("isitilacak bolum yol bolumu",
		ChapterProgress.current_variant_id() == "ch18_long_road_home",
		ChapterProgress.current_variant_id())
	var before := LevelVariant.snapshot()
	var root := RootFlow.new()
	add_child(root)
	await root._warm_chapter_shaders(false)
	await settle(0.5)
	ck("isitma izgarayi geri verdi",
		GameConfig.GRID_COLS == int(before["cols"])
			and GameConfig.GRID_ROWS == int(before["rows"]),
		"%dx%d" % [GameConfig.GRID_COLS, GameConfig.GRID_ROWS])
	ck("isitma sahnesi gitti", root.get_node_or_null("Main") == null, "")
	root.queue_free()
	await settle(0.3)

	# And the model refuses to read off its own end even if the grid moves
	# under it, which is the guard that turns this class of mistake into a
	# no-op instead of a crash.
	LevelVariant.of("ch18_long_road_home").apply()
	var model := LawnModel.new(1818)
	var cells := GameConfig.CELL_COUNT
	LevelVariant.of("ch01_aldridge").apply()
	ck("izgara gercekten degisti", GameConfig.CELL_COUNT != cells,
		"%d -> %d" % [cells, GameConfig.CELL_COUNT])
	# Row 19, col 7 is inside the NEW grid and past the end of the OLD model.
	ck("model kendi sinirini koruyor",
		model.mow(7, 19, 0) == LawnModel.MowResult.NONE, "")
	LevelVariant.restore(before)


## The board is the hub's most expensive page — sixteen evidence cards, each
## rendering its object in its own 3D world, measured at ~15 MB — and a player
## who never opens it should not pay for it. Built on first use instead, which
## has to hold for EVERY route in, and must not be forced by refresh(), which
## runs on every return to the hub.
func _check_board_is_built_late() -> void:
	for chapter: Dictionary in Story.list("chapters"):
		ChapterProgress.record(str(chapter.get("variant_id", "")), 2, 2)
	var hub := HubScreen.new()
	add_child(hub)
	await settle(1.2)
	ck("pano hub ile birlikte kurulmuyor",
		_sub_viewports(hub) == 1, "%d subviewport" % _sub_viewports(hub))
	hub.refresh()
	await settle(0.6)
	ck("refresh panoyu kurdurmuyor",
		_sub_viewports(hub) == 1, "%d subviewport" % _sub_viewports(hub))
	hub.open_evidence_board()
	await settle(1.0)
	var built := _sub_viewports(hub)
	ck("pano acilinca kuruluyor", built > 1, "%d subviewport" % built)
	# And it is not rebuilt: a second route in must reuse the same page.
	hub.open_map_at("ch01_aldridge")
	await settle(0.5)
	hub.open_evidence_board()
	await settle(0.5)
	ck("pano yeniden kurulmuyor", _sub_viewports(hub) == built,
		"%d -> %d" % [built, _sub_viewports(hub)])
	# Buried behind the background once, where it drew but could not be seen.
	var page: Node = hub._board_page
	ck("pano sayfasi gorunur katmanda",
		page != null and hub.get_children().find(page) >= hub.get_child_count() - 8,
		"indeks %d / %d" % [hub.get_children().find(page), hub.get_child_count()])
	hub.queue_free()
	await settle(0.3)


## The hub's diorama is rendered at 1/32 scale while a chapter is on screen, so
## its framebuffer is not held for a town nobody can see. Every route home has
## to put it back — and one of them did not: returning by way of the case board
## re-showed the hub by hand and skipped set_diorama_active(true), so the town
## came back as a 36x79 image stretched across the screen (G13).
func _check_every_way_home_unparks_the_town() -> void:
	GameState.set_setting("story", "intro_seen", true)
	var root: Node = load("res://scenes/Root.tscn").instantiate()
	add_child(root)
	await settle(2.5)
	var hub = root.get_node_or_null("HubLayer/Hub")
	ck("hub acildi", hub != null, "")
	if hub == null:
		return
	var full: Vector2i = (hub._diorama_view as SubViewport).size
	ck("hubda diyorama tam cozunurlukte", full.x > 500, str(full))

	for route in ["return_to_hub", "return_to_board"]:
		root.set("_pending_variant", "ch01_aldridge")
		root.call("_start_chapter")
		await settle(2.5)
		var parked: Vector2i = (hub._diorama_view as SubViewport).size
		ck("bolumde diyorama park edildi (%s)" % route, parked.x < 100,
			str(parked))
		root.call(route)
		await settle(3.0)
		var back: Vector2i = (hub._diorama_view as SubViewport).size
		ck("%s diyoramayi geri buyutuyor" % route, back == full,
			"%s != %s" % [str(back), str(full)])
	root.queue_free()
	await settle(0.5)


## An ending card has to close when it is tapped, THROUGH THE REAL INPUT PATH.
##
## That last part is the whole test. The convoy card listened on
## _unhandled_input while setting MOUSE_FILTER_STOP, and a Control that stops
## input consumes it at the GUI stage — the stage before _unhandled_input runs.
## So the card listened on a channel its own mouse filter guaranteed would stay
## silent, the ending drew, and "tap to continue" did nothing. Calling
## _unhandled_input directly from a test passes happily; pushing a touch through
## the viewport is what catches it (G13).
func _check_ending_cards_dismiss(method: String) -> void:
	GameState.set_setting("story", "intro_seen", true)
	var root: Node = load("res://scenes/Root.tscn").instantiate()
	add_child(root)
	await settle(2.5)
	# With a chapter on screen, as it is when a case actually ends.
	root.set("_pending_variant", "ch01_aldridge")
	root.call("_start_chapter")
	await settle(2.5)
	root.call(method)
	await settle(1.0)

	var card := _find_card(root)
	ck("%s bir kart acti" % method, card != null, "")
	if card == null:
		root.queue_free()
		return
	# The chapter's own HUD must be gone: it is a full-screen Control and it
	# would take the tap before the card ever saw it.
	ck("%s bolum sahnesini kapatti" % method,
		root.get_node_or_null("Main") == null, "")

	# Tap when the card is READY, not on a stopwatch. Both cards ignore input
	# while a page transition is running — the reunion card fades for 0.4 s and
	# then locks for another 0.5 — so a fixed interval silently drops taps and
	# the test blames the card. Tap on the lock, wait on the result: the same
	# fixed-sleep mistake this suite has now made three times.
	var waited := 0.0
	while waited < 12.0:
		var live := _find_card(root)
		if live == null:
			break
		if float(live.get("_lock")) <= 0.0:
			_push_tap()
		await settle(0.15)
		waited += 0.15
	ck("%s dokununca kapandi" % method, _find_card(root) == null, "")

	var hub := root.get_node_or_null("HubLayer") as CanvasLayer
	waited = 0.0
	while waited < 10.0 and (hub == null or not hub.visible):
		await settle(0.2)
		waited += 0.2
		hub = root.get_node_or_null("HubLayer") as CanvasLayer
	ck("%s sonrasi hub geri geldi" % method,
		hub != null and hub.visible, "")
	root.queue_free()
	await settle(0.5)


func _push_tap() -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = get_viewport().get_visible_rect().size * 0.5
	down.pressed = true
	get_viewport().push_input(down)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = down.position
	up.pressed = false
	get_viewport().push_input(up)


func _find_card(root: Node) -> Node:
	for layer in root.get_children():
		if not (layer is CanvasLayer):
			continue
		for child in layer.get_children():
			if child is ConvoyCard or child is ReunionCard:
				return child
	return null


func _sub_viewports(n: Node) -> int:
	var total := 1 if n is SubViewport else 0
	for child in n.get_children():
		total += _sub_viewports(child)
	return total


func ck(what: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [what, detail])
