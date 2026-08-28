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
	# CASE 01's eight, asked of Case 01's own list. count() is the whole board
	# and the board carries two cases now, so asserting a total here made this
	# test depend on whether Case 02 happened to be open — which is state a
	# previous test in the same suite can leave behind (G13).
	ck("vaka 01 sekiz bolum", Story.list("chapters").size() == 8,
		str(Story.list("chapters").size()))
	# ARCHITECTURE: chapters must never carry a scene path. G9 builds all eight
	# from one game scene plus variant data, and this is the assertion that stops
	# "one .tscn per chapter" creeping back in.
	for chapter: Dictionary in Story.list("chapters"):
		ck("bolum sahne yolu tasimiyor: %s" % chapter.get("variant_id", "?"),
			not chapter.has("scene") and not chapter.has("path"), str(chapter))
		ck("bolum variant_id tasiyor", str(chapter.get("variant_id", "")) != "",
			str(chapter))
	# G9 opened all eight: every chapter must be playable AND have a variant.
	var playable := 0
	for chapter: Dictionary in Story.list("chapters"):
		if bool(chapter.get("playable", false)):
			playable += 1
		var vid := str(chapter.get("variant_id", ""))
		ck("varyant verisi var: %s" % vid, LevelVariant.ids().has(vid), vid)
	ck("vaka 01 bolumleri oynanabilir", playable == 8, str(playable))
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
	await _until(func() -> bool: return reported.size() == 1)
	ck("bitince search_finished yayinlandi", reported.size() == 1, str(reported))
	game.queue_free()
	await get_tree().process_frame
	# The game scene pauses the whole tree when the window loses focus, on
	# purpose — a phone call must not leave the mower driving (Game._notification)
	# — and resuming deliberately does NOT unpause. A test run does not own the
	# window, so that pause lands whenever the machine feels like it and OUTLIVES
	# the scene that set it: every await after this point then waits forever, and
	# the dialogue check below failed for it. Nothing here tests pausing, so the
	# tree goes back to running (G16).
	get_tree().paused = false

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
		# Everyone who can be TAPPED must have something to say. Ellie is gated
		# on the case being closed (G11), so hers is checked at full progress.
		var gate := _requires_done(id)
		ck("kasaba diyalogu var: %s" % id,
			Dialogue.town_lines(id, gate).size() > 0, str(gate))

	# Town chatter reacts to progress. Phases are 0 / 4 / 8 since G11, so the
	# comparison has to straddle a real phase boundary, not chapter 1.
	var changed := 0
	for id: String in speakers:
		if _requires_done(id) > 0:
			continue
		if Dialogue.town_lines(id, 4) != Dialogue.town_lines(id, 0):
			changed += 1
		if Dialogue.town_lines(id, 8) != Dialogue.town_lines(id, 4):
			changed += 1
	ck("kasaba her evrede degisiyor", changed >= 8, str(changed))

	# The box must survive an empty conversation instead of trapping the player.
	var box := DialogueBox.new()
	add_child(box)
	await get_tree().process_frame
	var closed := []
	box.finished.connect(func() -> void: closed.append(true))
	box.play([])
	await _until(func() -> bool: return closed.size() == 1)
	ck("bos konusma kutuyu kapatiyor", closed.size() == 1, str(closed))


## Waits for `condition` to hold, giving up after `limit` seconds — at which
## point the assertion that follows reports the real failure.
##
## Both waits above sit on a timer inside the code under test: the completion
## report fires 1.5 s after the last cell, and an empty dialogue box closes over
## a 0.25 s fade. They used to be a fixed sleep with a fraction of a second of
## margin, which held on an idle machine and dropped on a loaded one — the test
## then failed for a reason that had nothing to do with the game. Waiting on the
## condition passes as fast as the code allows and only spends the ceiling when
## something is genuinely broken (G16).
func _until(condition: Callable, limit := 8.0) -> void:
	var waited := 0.0
	while waited < limit:
		if bool(condition.call()):
			return
		await get_tree().create_timer(0.1).timeout
		waited += 0.1


## How much of the case must be closed before this person is in town at all.
func _requires_done(person_id: String) -> int:
	for person: Dictionary in Story.list("town.people"):
		if str(person.get("id", "")) == person_id:
			return int(person.get("requires_done", 0))
	return 0


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
