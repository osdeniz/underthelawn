extends Node
## G13.6: the harvest level pays, repeats, and touches the case not at all.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	GameState.set_setting("harvest", "runs", 0)
	GameState.set_setting("harvest", "since_chapter", 0)
	ChapterProgress.reset()
	RestoreBoard.reset()

	# --- the variant itself
	var harvest := LevelVariant.of(GameConfig.HARVEST_VARIANT)
	ck("hasat varyanti tanimli", harvest.id == GameConfig.HARVEST_VARIANT, harvest.id)
	ck("hasat tipi", harvest.is_harvest(), harvest.level_type)
	ck("kanit yok", harvest.evidence_count() == 0,
		"%d kanit" % harvest.evidence_count())
	ck("echo yok", harvest.echo_def.is_empty(), "")
	ck("bugday paleti", harvest.palette_id == "WHEAT", harvest.palette_id)
	ck("buyuk grid", harvest.grid_size == "large", harvest.grid_size)
	# A search must not accidentally become one.
	ck("normal bolum hasat degil", not LevelVariant.of("ch01_aldridge").is_harvest(), "")

	# --- the invitation
	ck("basta davet yok", not HarvestLog.is_offered(), "")
	GameState.set_setting("restore", "farm", true)
	# DEV_UNLOCK_ALL makes every machine owned, so the "no tractor" half of the
	# condition can only be checked when it is off.
	if not GameConfig.DEV_UNLOCK_ALL:
		ck("sadece ciftlik yetmez", not HarvestLog.is_offered(), "traktor yok")
	GameState.set_setting("garage", "tractor_unlocked", true)
	ck("traktor + ciftlik ama bolum yok",
		not HarvestLog.is_offered(), "%d bolum" % ChapterProgress.done_count())
	var chapters: Array = Story.list("chapters")
	for i in GameConfig.HARVEST_EVERY:
		ChapterProgress.record(str((chapters[i] as Dictionary).get("variant_id", "")), 2, 2)
	ck("kosullar tamaminca davet var", HarvestLog.is_offered(),
		"%d bolum" % ChapterProgress.done_count())

	# --- playing it
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = GameConfig.HARVEST_VARIANT
	add_child(game)
	for _i in 10:
		await get_tree().process_frame
	# NO crop border. Seven rows of corn and sunflowers on three sides was
	# about seven hundred plants and 8,620 draw calls a frame — the level's
	# whole stutter — and the land around the fields is open now.
	ck("ekin serit yok",
		game.find_children("CropField", "", true, false).is_empty(), "")
	# (The fence is what keeps the mowable ground legible without the crop, but
	# it is built as loose meshes under no named parent, so there is nothing
	# here worth asserting on — a name check would only test my guess at one.)
	# And a harvest grows a CROP. This one used to be grass wearing a wheat
	# palette: plant_profile_id was never set, so every field mowed the same
	# plant in a different colour.
	ck("bugday tarlasi bugday ekiyor",
		GameConfig.active_plant_profile == "WILD_WHEAT",
		GameConfig.active_plant_profile)
	ck("hasatta kanit gomulmedi", game.model.secret_cells.is_empty(),
		"%d gizli" % game.model.secret_cells.size())

	# The completion panel must stop talking about a search: it used to headline
	# "AREA SEARCHED", count cells "searched", and list a "Search bonus".
	game.hud.show_complete(1240, "3:18", [], 0,
		{"base": 210, "bonus": 484, "total": 694}, "")
	await get_tree().process_frame
	ck("hasat panosu arama demiyor",
		game.hud._complete_title.text == tr("HARVEST_DONE_TITLE"),
		game.hud._complete_title.text)
	ck("hasat panosu bicilen hucreyi sayiyor",
		game.hud._complete_stats.text
			== tr("HARVEST_STATS").format({"cells": 1240, "time": "3:18"})
		and tr("HARVEST_STATS") != tr("UI_STATS"),
		game.hud._complete_stats.text)
	get_tree().paused = false
	game.hud._close_pause()

	# Finishing it must not move the case on.
	var before := ChapterProgress.done_count()
	HarvestLog.record()
	ck("hasat vakayi ilerletmez", ChapterProgress.done_count() == before,
		"%d -> %d" % [before, ChapterProgress.done_count()])
	ck("hasat sayaci arttı", HarvestLog.count() == 1, "%d" % HarvestLog.count())
	ck("balya birikti", HarvestLog.bales() == 1, "%d" % HarvestLog.bales())

	# --- repeatable: the invitation comes back, and the crumb rotates.
	ck("bir hasattan sonra davet kapandi", not HarvestLog.is_offered(), "")
	var first_crumb := HarvestLog.crumb_key()
	HarvestLog.record()
	ck("kirinti donuyor", HarvestLog.crumb_key() != first_crumb,
		"%s" % first_crumb)
	for i in range(GameConfig.HARVEST_EVERY, GameConfig.HARVEST_EVERY * 3):
		if i < chapters.size():
			ChapterProgress.record(str((chapters[i] as Dictionary).get("variant_id", "")), 2, 2)
	ck("yeterince bolum sonra davet doner", HarvestLog.is_offered(),
		"%d bolum / %d hasat" % [ChapterProgress.done_count(), HarvestLog.count()])
	# Bales stop piling at the cap.
	for _i in 10:
		HarvestLog.record()
	ck("balya tavani var", HarvestLog.bales() == GameConfig.HARVEST_BALES_MAX,
		"%d" % HarvestLog.bales())

	game.queue_free()
	GameState.set_setting("harvest", "runs", 0)
	GameState.set_setting("harvest", "since_chapter", 0)
	ChapterProgress.reset()
	_check_door_stays_open()

	RestoreBoard.reset()
	# --- three fields, three crops
	ck("uc tarla tanimli", GameConfig.HARVEST_VARIANTS.size() == 3,
		str(GameConfig.HARVEST_VARIANTS.size()))
	var seen: Array[String] = []
	for id: String in GameConfig.HARVEST_VARIANTS:
		var variant := LevelVariant.of(id)
		ck("tarla var: %s" % id, variant != null, "")
		if variant == null:
			continue
		ck("hasat tipi: %s" % id, variant.is_harvest(), "")
		var profile := variant.plant_profile_id
		ck("tarlanin bitkisi tanimli: %s" % id,
			GameConfig.PLANT_PROFILES.has(profile), profile)
		# Each field must grow something the others do not, or three fields is
		# one field painted three ways.
		ck("bitki benzersiz: %s" % id, not seen.has(profile), profile)
		seen.append(profile)
		ck("harita tarlayi taniyor: %s" % id,
			GameConfig.is_harvest_variant(id), "")
	ck("her tarlanin adi var",
		GameConfig.HARVEST_NAMES.size() == GameConfig.HARVEST_VARIANTS.size(),
		str(GameConfig.HARVEST_NAMES.size()))

	if _fails > 0:
		push_error("%d HASAT TESTI BASARISIZ" % _fails)
		print("--- %d HASAT TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM HASAT TESTLERI GECTI ---")
	get_tree().quit()


## The DOOR and the INVITATION are different things (G13). The field used to be
## reachable only while the cadence was calling, so the game's one repeatable
## job disappeared the moment it had been done — a job you can only take when
## the game feels like offering it is not a job.
func _check_door_stays_open() -> void:
	RestoreBoard.reset()
	ChapterProgress.reset()
	GameState.set_setting("harvest", "since_chapter", 0)
	GameState.set_setting("garage", "tractor_unlocked", false)
	ck("tarla yokken kapi kapali", not HarvestLog.is_available(), "")

	GameState.set_setting("restore", "farm", true)
	ck("traktorsuz kapi kapali", not HarvestLog.is_available(), "")
	GameState.set_setting("garage", "tractor_unlocked", true)
	ck("ciftlik ve traktorle kapi acik", HarvestLog.is_available(), "")
	ck("kapi acik ama daveti yok", not HarvestLog.is_offered(), "")

	for chapter: Dictionary in Story.list("chapters"):
		ChapterProgress.record(str(chapter.get("variant_id", "")), 2, 2)
	ck("ritim dolunca davet var", HarvestLog.is_offered(), "")

	HarvestLog.record()
	ck("hasattan sonra davet cekiliyor", not HarvestLog.is_offered(), "")
	# The one that matters.
	ck("hasattan sonra kapi ACIK kaliyor", HarvestLog.is_available(), "")


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
