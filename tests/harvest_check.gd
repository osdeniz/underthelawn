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
	ck("ekin tarlasi kuruldu",
		game.find_children("CropField", "", true, false).size() == 1, "")
	# Count PLANTS, not nodes. The field used to be one node per plant and this
	# read the child count; the plants are MultiMesh instances now — eight
	# batches standing in for hundreds of stalks — so counting children counts
	# batches and says the field is empty when it is full.
	var plants: Array = game.find_children("CropField", "", true, false)
	var count := 0
	if plants.size() > 0:
		for node in (plants[0] as Node).find_children("*", "MultiMeshInstance3D", true, false):
			var mm := (node as MultiMeshInstance3D).multimesh
			if mm != null:
				count += mm.instance_count
	ck("tarla devasa", count > 300, "%d bitki" % count)
	# And the batching itself is the point: a plant per node was 8,620 draw
	# calls a frame in this level and it stuttered on device.
	var batches: int = 0
	if plants.size() > 0:
		batches = (plants[0] as Node).find_children(
			"*", "MultiMeshInstance3D", true, false).size()
	ck("tarla toplu ciziliyor", batches > 0 and batches <= 16,
		"%d parti" % batches)
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
