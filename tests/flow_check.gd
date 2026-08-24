extends Node
## G8: the hub -> chapter -> return loop, and the architecture rule that a
## chapter is an ID rather than a scene.

var _fails := 0


func _ready() -> void:
	ChapterProgress.reset()
	await _check_data()
	await _check_hub()
	await _check_chapter_round_trip()
	await _check_dialogue()
	_check_next_chain()
	if _fails > 0:
		push_error("%d AKIS TESTI BASARISIZ" % _fails)
		print("--- %d AKIS TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM AKIS TESTLERI GECTI ---")
	get_tree().quit()


func _check_data() -> void:
	ck("8 bolum var", ChapterProgress.count() == 8,
		str(ChapterProgress.count()))
	# ARCHITECTURE: chapters must never carry a scene path. G9 builds all eight
	# from one game scene plus variant data, and this is the assertion that stops
	# "one .tscn per chapter" creeping back in.
	for chapter: Dictionary in ChapterProgress.chapters():
		ck("bolum sahne yolu tasimiyor: %s" % chapter.get("variant_id", "?"),
			not chapter.has("scene") and not chapter.has("path"), str(chapter))
		ck("bolum variant_id tasiyor", str(chapter.get("variant_id", "")) != "",
			str(chapter))
	# G9 opened all eight: every chapter must be playable AND have a variant.
	var playable := 0
	for chapter: Dictionary in ChapterProgress.chapters():
		if bool(chapter.get("playable", false)):
			playable += 1
		var vid := str(chapter.get("variant_id", ""))
		ck("varyant verisi var: %s" % vid, LevelVariant.ids().has(vid), vid)
	ck("8 bolum oynanabilir", playable == 8, str(playable))
	ck("aktif bolum ilk bolum",
		ChapterProgress.current_variant_id() == "ch01_aldridge",
		ChapterProgress.current_variant_id())


func _check_hub() -> void:
	var hub := HubScreen.new()
	add_child(hub)
	await get_tree().process_frame
	ck("hub ekran boyutu var", hub.size.x > 100 and hub.size.y > 100,
		str(hub.size))
	# G10 opened the workshop: the tile must exist and be UNLOCKED now.
	var workshop_open := false
	for tile: Dictionary in Story.list("hub.tiles"):
		if str(tile.get("id", "")) == "workshop":
			workshop_open = not bool(tile.get("locked", false))
	ck("atolye karti acik", workshop_open, "")
	hub.queue_free()
	await get_tree().process_frame


func _check_chapter_round_trip() -> void:
	# The game scene must run standalone AND accept a variant id.
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.set("variant_id", "ch01_aldridge")
	add_child(game)
	await get_tree().process_frame
	ck("oyun sahnesi variant_id aldi",
		str(game.get("variant_id")) == "ch01_aldridge",
		str(game.get("variant_id")))
	ck("tek basina calisirken arama basliyor",
		bool(game.get("_search_started")), "")

	var reported := []
	game.connect("search_finished", func(found: int, total: int) -> void:
		reported.append([found, total]))
	# Finish the lawn outright rather than driving a mower for a minute.
	var model: LawnModel = game.model
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			model.mow(col, row, 0)
	# _on_completed waits 1.5 s before reporting, so the reward shot can land.
	await get_tree().create_timer(2.0).timeout
	ck("bitince search_finished yayinlandi", reported.size() == 1, str(reported))
	game.queue_free()
	await get_tree().process_frame

	# What the hub does with that report.
	ChapterProgress.record("ch01_aldridge", 1, 2)
	ck("bolum tamamlandi olarak kaydedildi",
		ChapterProgress.is_done("ch01_aldridge"), "")
	ck("kanit sayisi kaydedildi",
		ChapterProgress.evidence_found("ch01_aldridge") == 1,
		str(ChapterProgress.evidence_found("ch01_aldridge")))
	ck("tamamlanan sayisi 1", ChapterProgress.done_count() == 1,
		str(ChapterProgress.done_count()))
	# Evidence must never go DOWN on a replay that found less.
	ChapterProgress.record("ch01_aldridge", 0, 2)
	ck("tekrar oynayinca kanit geri gitmiyor",
		ChapterProgress.evidence_found("ch01_aldridge") == 1,
		str(ChapterProgress.evidence_found("ch01_aldridge")))


## G9.2: the NEXT button's data path — every chapter except the last must know
## its successor, and the successor must be a defined variant.
func _check_next_chain() -> void:
	var chapters := ChapterProgress.chapters()
	for i in chapters.size() - 1:
		var next_id := str(chapters[i + 1].get("variant_id", ""))
		ck("sonraki bolum tanimli: %s" % next_id,
			LevelVariant.ids().has(next_id), next_id)
		ck("sonraki bolumun adi var", str(chapters[i + 1].get("name", "")) != "",
			str(chapters[i + 1]))


func _check_dialogue() -> void:
	var brief := Dialogue.conversation("brief_ch01")
	ck("brifing konusmasi var", brief.size() >= 3, str(brief.size()))
	var has_choice := false
	for entry: Dictionary in brief:
		if entry.has("choice"):
			has_choice = true
			var options: Array = entry["choice"].get("options", [])
			ck("secim tam 2 secenek", options.size() == 2, str(options.size()))
			for option: Dictionary in options:
				ck("secenek tepki satiri tasiyor", option.has("reply"),
					str(option))
	ck("brifingde secim dugumu var", has_choice, "")
	ck("brifing onay tusu var", Dialogue.accept_key("brief_ch01") != "", "")

	# Every speaker id must be one of the six characters, since the id is also
	# the portrait file name.
	var speakers := Dialogue.speakers()
	ck("6 karakter", speakers.size() == 6, str(speakers))
	for id in ["marshal", "sarah", "gus", "cole", "ellie", "stranger"]:
		ck("konusmaci tanimli: %s" % id, speakers.has(id), str(speakers))
		# Town chatter must exist for everyone, or a card taps into nothing.
		ck("kasaba diyalogu var: %s" % id,
			Dialogue.town_lines(id, 0).size() > 0, "")

	# Town chatter reacts to progress: at least one person says something new.
	var changed := false
	for id: String in speakers:
		if Dialogue.town_lines(id, 1) != Dialogue.town_lines(id, 0):
			changed = true
	ck("kasaba ilerlemeye tepki veriyor", changed, "")

	# The box must survive an empty conversation instead of trapping the player.
	var box := DialogueBox.new()
	add_child(box)
	await get_tree().process_frame
	var closed := []
	box.finished.connect(func() -> void: closed.append(true))
	box.play([])
	await get_tree().create_timer(0.6).timeout
	ck("bos konusma kutuyu kapatiyor", closed.size() == 1, str(closed))


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
