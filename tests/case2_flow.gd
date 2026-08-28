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
	GameState.set_setting("story", "case01_closed", true)
	ck("kapali: vaka 01 kapandi ama kasaba hazir degil",
		not ChapterProgress.case_two_open(), "")
	for project in ["lantern", "swing"]:
		GameState.set_setting("restore", project, true)
	ck("kapali: iki proje yetmez", not ChapterProgress.case_two_open(),
		"%d proje" % RestoreBoard.built_count())
	GameState.set_setting("restore", "greenhouse", true)
	ck("acik: uc proje ve kapali vaka", ChapterProgress.case_two_open(),
		"%d proje" % RestoreBoard.built_count())
	await settle(0.1)


func _check_board() -> void:
	var all := ChapterProgress.chapters()
	ck("pano iki vakayi tasiyor", all.size() == 18, str(all.size()))
	ck("aktif vaka ikinci",
		ChapterProgress.active_case_is_two() == false,
		"vaka 01 hala bitmemis")
	for chapter: Dictionary in Story.list("chapters"):
		ChapterProgress.record(str(chapter.get("variant_id", "")), 2, 2)
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


func ck(what: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [what, detail])
