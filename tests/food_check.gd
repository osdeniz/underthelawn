extends Node
## G14.12: food is a real resource, and population is a real number.
##
## Both used to be the constants 42 and 11 on the hub's top bar — state the
## player could watch never move. This asserts the two things that made them
## fake: that something produces them, and that something spends them.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	ChapterProgress.reset()
	RestoreBoard.reset()
	TownStats.reset()

	# --- population is derived, and moves when the town does
	var start_people := TownStats.people()
	ck("nufus tabani dogru", start_people == GameConfig.TOWN_BASE_PEOPLE,
		str(start_people))
	GameState.set_setting("restore", "swing", true)
	ck("onarim biri geri getiriyor",
		TownStats.people() == start_people + 1, str(TownStats.people()))
	for chapter_any: Variant in Story.list("chapters"):
		ChapterProgress.record(
			str((chapter_any as Dictionary).get("variant_id", "")), 2, 2)
	ck("ellie eve donunce nufus artiyor",
		TownStats.people() == start_people + 2, str(TownStats.people()))
	ChapterProgress.reset()
	RestoreBoard.reset()

	# --- food starts full, and the town eats
	TownStats.reset()
	ck("kiler dolu basliyor", TownStats.food() == GameConfig.FOOD_START,
		str(TownStats.food()))
	TownStats.eat()
	ck("kasaba yiyor",
		TownStats.food() == GameConfig.FOOD_START - GameConfig.FOOD_PER_CHAPTER,
		str(TownStats.food()))
	# It cannot go below zero, and it warns before it gets there.
	for _i in 40:
		TownStats.eat()
	ck("sifirin altina inmiyor", TownStats.food() == 0, str(TownStats.food()))
	ck("kritik uyari veriyor",
		TownStats.warning_key() == "FOOD_CRITICAL_LINE", TownStats.warning_key())
	TownStats.add_food(GameConfig.FOOD_LOW)
	ck("az uyarisi veriyor",
		TownStats.warning_key() == "FOOD_LOW_LINE", TownStats.warning_key())
	TownStats.reset()
	ck("dolu kilerde uyari yok", TownStats.warning_key() == "", "")

	# --- and a yard actually hands some over
	var model := LawnModel.new(4242)
	var field := ScrapField.new()
	add_child(field)
	field.setup(model, 10, 4242)
	ck("bahce gida sakliyor", field.food_remaining() > 0,
		"%d sandik" % field.food_remaining())
	var taken := 0
	for cell: Vector2i in _food_cells(field, model):
		taken += field.take_food(cell.x, cell.y)
	ck("gida toplanabiliyor", taken > 0, "%d" % taken)
	ck("ayni hucre iki kez odemiyor", field.food_remaining() == 0,
		"%d" % field.food_remaining())
	field.queue_free()

	TownStats.reset()
	if _fails > 0:
		push_error("%d GIDA TESTI BASARISIZ" % _fails)
		print("--- %d GIDA TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM GIDA TESTLERI GECTI ---")
	get_tree().quit()


## Every cell in the yard, so the sweep cannot miss a crate.
func _food_cells(field: ScrapField, _model: LawnModel) -> Array:
	var out: Array = []
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			out.append(Vector2i(col, row))
	return out


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
