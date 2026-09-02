extends Node
## G14.13: taking someone in is a decision with two sides.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	ChapterProgress.reset()
	RestoreBoard.reset()
	Settlers.reset()
	TownStats.reset()

	# --- nobody turns up before their chapter
	ck("basta kimse yok", Settlers.pending().is_empty(),
		str(Settlers.pending().get("id", "")))
	var chapters: Array = Story.list("chapters")
	for i in 2:
		ChapterProgress.record(str((chapters[i] as Dictionary).get("variant_id", "")), 2, 2)
	var first := Settlers.pending()
	ck("iki bolum sonra biri geliyor", not first.is_empty(), "")
	ck("teki tek kisi", str(first.get("id", "")) == "wren",
		str(first.get("id", "")))

	# --- accepting costs and gives
	var people_before := TownStats.people()
	var cost_before := TownStats.daily_cost()
	var yield_before := Settlers.food_yield()
	Settlers.accept("wren")
	ck("nufus artti", TownStats.people() == people_before + 1,
		str(TownStats.people()))
	ck("gunluk gider artti", TownStats.daily_cost() > cost_before,
		"%d -> %d" % [cost_before, TownStats.daily_cost()])
	ck("mesleginin faydasi var", Settlers.food_yield() > yield_before,
		"%.2f" % Settlers.food_yield())
	ck("cevaplanan bir daha sorulmuyor",
		str(Settlers.pending().get("id", "")) != "wren",
		str(Settlers.pending().get("id", "")))

	# --- rejecting costs nothing and gives nothing
	for i in range(2, 4):
		ChapterProgress.record(str((chapters[i] as Dictionary).get("variant_id", "")), 2, 2)
	var next := Settlers.pending()
	ck("sirada bir sonraki var", not next.is_empty(), "")
	var scrap_before := Settlers.scrap_yield()
	var cost_now := TownStats.daily_cost()
	Settlers.reject(str(next.get("id", "")))
	ck("reddedilen yemiyor", TownStats.daily_cost() == cost_now,
		str(TownStats.daily_cost()))
	ck("reddedilen fayda vermiyor",
		is_equal_approx(Settlers.scrap_yield(), scrap_before), "")

	# --- the cook actually lowers the bill
	Settlers.accept("noor")
	ck("asci gideri dusuruyor",
		TownStats.daily_cost() < TownStats.people() * GameConfig.FOOD_PER_PERSON,
		"%d / %d" % [TownStats.daily_cost(), TownStats.people()])
	# --- and the carpenter lowers a price everyone reads from one place
	var full: int = int(RestoreBoard.of("swing").get("cost", 0))
	Settlers.accept("tomas")
	ck("marangoz fiyati dusuruyor", RestoreBoard.price("swing") < full,
		"%d -> %d" % [full, RestoreBoard.price("swing")])

	# --- food can be bought when the larder runs dry
	GameState.set_setting("economy", "scrap", GameConfig.FOOD_SACK_COST + 10)
	var food_before := TownStats.food()
	GameState.spend_scrap(GameConfig.FOOD_SACK_COST)
	TownStats.add_food(GameConfig.FOOD_SACK)
	ck("gida satin alinabiliyor",
		TownStats.food() == food_before + GameConfig.FOOD_SACK,
		str(TownStats.food()))

	ChapterProgress.reset()
	RestoreBoard.reset()
	Settlers.reset()
	TownStats.reset()
	if _fails > 0:
		push_error("%d YERLESIMCI TESTI BASARISIZ" % _fails)
		print("--- %d YERLESIMCI TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM YERLESIMCI TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
