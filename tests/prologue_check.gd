extends TestBase
## G15.1: the long walk. The claim that matters most is that the road can
## actually be WALKED — a tutorial that can trap the player is worse than no
## tutorial — so that one is a flood fill, not an eyeball.



func run() -> void:
	suite = "PROLOG"
	_text()
	_cards()
	_not_a_chapter()
	_road_is_walkable()
	_trial_mowers()
	_flow_flags()
	await _road_level()



## Every new key exists in BOTH languages. A missing key renders as the key
## itself, which is how "PRO_02_L1" ends up on a story card in shipped builds.
func _text() -> void:
	var keys: Array[String] = ["PRO_01_L1", "PRO_01_L2", "PRO_02_L1", "PRO_02_L2",
		"PRO_03_L1", "PRO_03_L2", "PRO_04_L1", "PRO_04_L2",
		"PRO_05_L1", "PRO_05_L2", "PRO_06_L1", "PRO_06_L2",
		"PRO_ROAD_TITLE", "PRO_ROAD_TASK", "PRO_ACCEPT",
		"DLG_PRO_ROAD_1A", "DLG_PRO_ROAD_1B", "DLG_PRO_ROAD_2A",
		"DLG_PRO_ROAD_2B", "DLG_PRO_ROAD_3A", "DLG_PRO_ROAD_3B"]
	var was := TranslationServer.get_locale()
	for locale: String in ["en", "tr"]:
		TranslationServer.set_locale(locale)
		var missing: Array[String] = []
		for key: String in keys:
			if TranslationServer.translate(key) == key:
				missing.append(key)
		ck("%s cevirileri tam" % locale, missing.is_empty(),
			"eksik: %s" % ", ".join(missing))
	TranslationServer.set_locale(was)


func _cards() -> void:
	for key: String in ["prologue.cards", "prologue.after", "intro.cards"]:
		var list := Story.list(key)
		ck("%s dolu" % key, not list.is_empty(), "bos")
		for card: Dictionary in list:
			for raw: Variant in card.get("lines", []):
				ck("%s satiri cevrili: %s" % [key, raw],
					TranslationServer.translate(str(raw)) != str(raw), "")
	var lines := Dialogue.conversation("pro_road")
	ck("yol diyalogu var", lines.size() >= 4, "%d satir" % lines.size())


## The prologue must NOT be in the case board's chapter list, or it would count
## towards Case 01 being finished and the board would show a ninth entry.
func _not_a_chapter() -> void:
	for chapter: Dictionary in Story.list("chapters"):
		if str(chapter.get("variant_id", "")) == GameConfig.PROLOGUE_ID:
			ck("prolog vaka listesinde degil", false, "listede")
			return
	ck("prolog vaka listesinde degil", true, "")
	ck("prolog bolum verisi var",
		LevelVariant.ids().has(GameConfig.PROLOGUE_ID), "levels.json'da yok")


## THE assertion. A flood fill from the spawn cell through mowable cells only:
## if it cannot reach the far end, the road is a dead end and the game is
## unfinishable from its first minute.
func _road_is_walkable() -> void:
	var variant := LevelVariant.of(GameConfig.PROLOGUE_ID)
	variant.apply()
	var model := LawnModel.new(variant.decor_seed)
	var start := LawnModel.cell_at(Vector3(GameConfig.mower_start().x, 0.0,
		GameConfig.mower_start().y))

	# FIRST, prove the fill can say no. A wall right across the lane must come
	# back unreachable — otherwise this whole check passes on any road,
	# including one that is bricked up, and proves nothing.
	var walled := _fill(start, func(c: Vector2i) -> bool:
		return model.is_mowable(c.x, c.y) and c.y != 12)
	ck("dolgu 'hayir' diyebiliyor", not bool(walled["far"]),
		"duvarli yoldan gecti - kontrol bos")

	var real := _fill(start, func(c: Vector2i) -> bool:
		return model.is_mowable(c.x, c.y))
	ck("yolun sonuna ulasilabiliyor", bool(real["far"]), "kapali")

	# And it is a road, not a field: long, narrow, and mostly cuttable.
	var mowable := model.mowable_cells
	var cells := GameConfig.GRID_COLS * GameConfig.GRID_ROWS
	ck("yol yeterince uzun", GameConfig.GRID_ROWS >= GameConfig.GRID_COLS * 3,
		"%dx%d" % [GameConfig.GRID_COLS, GameConfig.GRID_ROWS])
	ck("engeller yolu bogmuyor", float(mowable) / float(cells) > 0.6,
		"%d/%d bicilebilir" % [mowable, cells])
	# Every cuttable cell has to be reachable, or the level sits at 97% for
	# ever: an island of grass behind a log can never be finished.
	ck("bicilebilir her hucre erisilebilir", int(real["seen"]) == mowable,
		"%d erisilir / %d bicilebilir" % [int(real["seen"]), mowable])
	print("  [olcum] yol %dx%d, %d bicilebilir hucre, %d erisilir (duvarliyken %d)"
		% [GameConfig.GRID_COLS, GameConfig.GRID_ROWS, mowable,
			int(real["seen"]), int(walled["seen"])])


## Flood fill from `start` over cells `open` accepts. Returns how many were
## reached and whether the far end was among them.
func _fill(start: Vector2i, open: Callable) -> Dictionary:
	var seen := {}
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	var far := false
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		if at.y <= 1:
			far = true
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
				Vector2i(0, -1)]:
			var next := at + step
			if seen.has(next) or not LawnModel.in_bounds(next.x, next.y):
				continue
			if not bool(open.call(next)):
				continue
			seen[next] = true
			queue.append(next)
	return {"seen": seen.size(), "far": far}


func _trial_mowers() -> void:
	Garage.trial = false
	var locked := 0
	for type_index in 4:
		if not Garage.is_unlocked(type_index):
			locked += 1
	Garage.trial = true
	var open := 0
	for type_index in 4:
		if Garage.is_unlocked(type_index):
			open += 1
	Garage.trial = false
	ck("deneme dorde de aciyor", open == 4, "%d acik" % open)
	ck("deneme kapaninca geri kilitleniyor", locked > 0,
		"zaten hepsi acikti - test bir sey kanitlamiyor")


func _flow_flags() -> void:
	var flow: Node = load("res://scenes/Root.tscn").instantiate()
	flow.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	GameState.set_setting("story", "prologue_done", false)
	GameState.set_setting("story", "intro_seen", false)
	ck("temiz kayitta prolog bekliyor", not flow._prologue_done(), "atlandi")
	# A save from before this feature is hours into Case 01 and must not be
	# sent back to the road.
	GameState.set_setting("story", "intro_seen", true)
	ck("eski kayit yola geri gonderilmiyor", flow._prologue_done(), "geri gonderildi")
	GameState.set_setting("story", "intro_seen", false)

	# And the ROUTING: finishing the road must take the prologue branch, not
	# the chapter funnel. If it fell through, ch00 would be recorded as a
	# chapter, counted by case_one_finished() and shown on the board.
	add_child(flow)
	GameState.set_setting("story", "prologue_done", false)
	Garage.trial = true
	flow._pending_variant = GameConfig.PROLOGUE_ID
	flow._on_search_finished(0, 0)
	ck("yol bitince prolog isaretleniyor",
		bool(GameState.get_setting("story", "prologue_done", false)), "isaretlenmedi")
	ck("deneme makineleri geri aliniyor", not Garage.trial, "acik kaldi")
	ck("prolog bolum olarak kaydedilmiyor",
		not ChapterProgress.is_done(GameConfig.PROLOGUE_ID), "kaydedildi")
	GameState.set_setting("story", "prologue_done", false)
	flow.queue_free()


## The level itself: the road mode HUD, the waiting dog, no payout.
func _road_level() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	GameState.set_setting("story", "prologue_done", false)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = GameConfig.PROLOGUE_ID
	add_child(game)
	for _i in 12:
		get_tree().paused = false
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 24:
		get_tree().paused = false
		await get_tree().process_frame

	ck("yol modu: kanit ceti yok", not game.hud._evidence_chip.visible, "gorunur")
	ck("yolda hurda yok", game.variant.scrap_budget == 0,
		"%d" % game.variant.scrap_budget)
	var clearing := game.find_children("Landmark_clearing", "", true, false)
	ck("acikliga varilacak yer var", clearing.size() == 1, "%d" % clearing.size())
	# The basket stands on the bare patch inside the fence now, not at the
	# landmark beyond it (G15.2) — so it is looked for anywhere in the yard.
	var baskets := game.find_children("Basket", "", true, false)
	ck("sepet duruyor", baskets.size() == 1, "%d sepet" % baskets.size())
	if baskets.size() == 1:
		var at := (baskets[0] as Node3D).global_position
		ck("sepet cimin icinde", absf(at.z) < GameConfig.HALF_Z, "z=%.1f" % at.z)
		var cell := LawnModel.cell_at(at)
		ck("sepet biciLMEyen zeminde", not game.model.is_mowable(cell.x, cell.y),
			"%s bicilebilir" % cell)
	# THE bug this sprint was for: two default secrets were buried on the road,
	# and the first thing a new player dug up was a radio from a case nine
	# years away. Nothing is buried here, and nothing is counted as evidence.
	ck("yolda gomulu sir yok", game.model.secret_cells.is_empty(),
		"%d sir" % game.model.secret_cells.size())
	ck("yolda kanit sayisi sifir", game._evidence_total() == 0,
		"%d" % game._evidence_total())
	var animals := game._animals as Animals
	var dog: Node3D = null
	if animals != null:
		dog = animals.get_node_or_null("Dog") as Node3D
	ck("kopek yolun sonunda", dog != null, "yok")
	if dog != null:
		var want := GameConfig.prologue_dog_spot()
		var held := dog.position
		for _i in 40:
			get_tree().paused = false
			await get_tree().process_frame
		ck("kopek yerinde bekliyor", dog.position.distance_to(held) < 0.05,
			"%.2f birim kaydi" % dog.position.distance_to(held))
		ck("kopek acikligin onunde", absf(dog.position.z - want.z) < 0.01,
			"%.2f" % dog.position.z)
		# And on the bare patch, where it can be seen, not in the tall grass.
		var dog_cell := LawnModel.cell_at(dog.position)
		ck("kopek cimsiz zeminde", not game.model.is_mowable(dog_cell.x, dog_cell.y),
			"%s cimenin icinde" % dog_cell)
	game.queue_free()
	for _i in 6:
		get_tree().paused = false
		await get_tree().process_frame


